#!/usr/bin/env bash
###############################################################################
# FogOS Gaming Kernel — Boot Image Creator
#
# Usage:
#   bash scripts/create_bootimg.sh <stock_boot.img> <kernel_image> <output.img>
#
# Replaces only the stock boot kernel, preserves the stock boot header/ramdisk
# contract, and creates a complete partition-sized AVB hash-footer image.
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNPACK_PY="$SCRIPT_DIR/vendor/mkbootimg/unpack_bootimg.py"
MKBOOT_PY="$SCRIPT_DIR/vendor/mkbootimg/mkbootimg.py"

STOCK_IMG="${1:-stock/boot.img}"
KERNEL_IMG="${2:-out/arch/arm64/boot/Image}"
OUTPUT_IMG="${3:-release/FogOS-Gaming-boot.img}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log()  { echo -e "${CYAN}[bootimg] $*${NC}"; }
ok()   { echo -e "${GREEN}[bootimg] ✓ $*${NC}"; }
fail() { echo -e "${RED}[bootimg] ✗ $*${NC}"; exit 1; }

[ -f "$STOCK_IMG" ]  || fail "Stock boot.img not found: $STOCK_IMG"
[ -f "$KERNEL_IMG" ] || fail "Kernel image not found: $KERNEL_IMG"
[ -f "$UNPACK_PY" ]  || fail "Vendored unpack_bootimg.py missing: $UNPACK_PY"
[ -f "$MKBOOT_PY" ]  || fail "Vendored mkbootimg.py missing: $MKBOOT_PY"

log "Stock  : $STOCK_IMG  ($(du -sh "$STOCK_IMG" | cut -f1))"
log "Kernel : $KERNEL_IMG ($(du -sh "$KERNEL_IMG" | cut -f1))"
log "Output : $OUTPUT_IMG"

WORK_DIR="$(mktemp -d /tmp/fogos-boot.XXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

###############################################################################
# Unpack the known-good Evolution X image and repack it with only the kernel
# replaced. The vendored AOSP tools understand this device's GKI-era header.
###############################################################################
log "Unpacking stock boot.img..."
FORMAT_OUT="$WORK_DIR/mkbootimg_args.txt"
python3 "$UNPACK_PY" --boot_img "$STOCK_IMG" --out "$WORK_DIR" \
    --format mkbootimg > "$FORMAT_OUT" \
  || fail "unpack_bootimg failed — stock image is not a valid Android boot image"

mkdir -p "$(dirname "$OUTPUT_IMG")"
log "Repacking stock header and ramdisk with the FogOS kernel..."

python3 - "$FORMAT_OUT" "$KERNEL_IMG" "$OUTPUT_IMG" "$WORK_DIR" "$MKBOOT_PY" <<'PYEOF'
import os
import shlex
import subprocess
import sys

format_out, kernel_img, output_img, work_dir, mkboot_py = sys.argv[1:6]
file_flags = {"--ramdisk", "--vendor_ramdisk", "--dtb", "--second", "--recovery_dtbo"}

with open(format_out, encoding="utf-8") as fh:
    tokens = shlex.split(fh.read().strip())

args = [sys.executable, mkboot_py]
i = 0
while i < len(tokens):
    tok = tokens[i]
    i += 1
    val = tokens[i] if i < len(tokens) else ""

    if tok == "--output":
        i += 1
    elif tok == "--kernel":
        args += ["--kernel", kernel_img]
        i += 1
    elif tok in file_flags:
        abs_val = val if os.path.isabs(val) else os.path.join(work_dir, val)
        if os.path.isfile(abs_val):
            args += [tok, abs_val]
        elif os.path.isfile(val):
            args += [tok, val]
        else:
            print(f"[bootimg] Skipping {tok}: file not found ({abs_val})", file=sys.stderr)
        i += 1
    elif tok.startswith("--"):
        if val and not val.startswith("--"):
            args += [tok, val]
            i += 1

args += ["--output", output_img]
print("[bootimg] Running:", " ".join(shlex.quote(a) for a in args))
sys.exit(subprocess.call(args))
PYEOF

[ -f "$OUTPUT_IMG" ] || fail "Output file was not created"

###############################################################################
# Motorola bootloader preflash contract
#
# The accepted Evolution X boot image is a complete 96 MiB partition image:
#   boot data + stock AVB vbmeta descriptor block + zero padding + AVB footer.
#
# A prior FogOS packer discarded that descriptor block and wrote a tiny,
# verification-disabled AVB footer. Motorola's bootloader rejects that altered
# structure during preflash validation before it writes the target slot.
#
# Preserve the entire stock vbmeta block byte-for-byte, replacing only the
# SHA-256 hash descriptor's image length and digest for the new boot data.
# This retains stock descriptor metadata, AVB version, flags, release string,
# padding shape, and the exact partition image size expected by fastboot.
###############################################################################
log "Rebuilding the stock-compatible AVB hash footer and partition-size image..."
python3 - "$STOCK_IMG" "$OUTPUT_IMG" <<'AVBEOF'
import hashlib
import os
import struct
import sys

stock_path, output_path = sys.argv[1:3]
FOOTER_FMT = ">4sIIQQQ28s"
FOOTER_SIZE = struct.calcsize(FOOTER_FMT)
HEADER_FMT = ">4sIIQQI" + ("Q" * 11) + "II48s80s"
HEADER_SIZE = struct.calcsize(HEADER_FMT)
HASH_DESCRIPTOR_TAG = 2


def replace_stock_hash_descriptor(stock_vbmeta: bytes, boot_data: bytes) -> tuple[bytes, str, int]:
    if len(stock_vbmeta) < HEADER_SIZE:
        raise ValueError("stock vbmeta is shorter than the AVB header")
    fields = struct.unpack(HEADER_FMT, stock_vbmeta[:HEADER_SIZE])
    if fields[0] != b"AVB0":
        raise ValueError("stock vbmeta does not begin with AVB0")
    algorithm = fields[5]
    q_values = fields[6:17]
    flags = fields[17]
    auth_size, aux_size = fields[3], fields[4]
    desc_offset, desc_size = q_values[8], q_values[9]
    if algorithm != 0 or auth_size != 0:
        raise ValueError("stock vbmeta is signed; this packer refuses to alter signed metadata")
    if flags != 0:
        raise ValueError("stock vbmeta flags are non-zero; this packer refuses to alter its contract")
    aux_start = HEADER_SIZE + auth_size
    desc_start = aux_start + desc_offset
    desc_end = desc_start + desc_size
    if aux_start + aux_size > len(stock_vbmeta) or desc_end > len(stock_vbmeta):
        raise ValueError("stock AVB descriptor bounds are invalid")

    result = bytearray(stock_vbmeta)
    pos = desc_start
    while pos + 16 <= desc_end:
        tag, body_size = struct.unpack(">QQ", result[pos:pos + 16])
        body_start = pos + 16
        body_end = body_start + body_size
        if body_end > desc_end:
            raise ValueError("stock AVB descriptor is truncated")
        if tag == HASH_DESCRIPTOR_TAG:
            body = bytes(result[body_start:body_end])
            if len(body) < 116:
                raise ValueError("stock AVB hash descriptor is too short")
            hash_algorithm = body[8:40].split(b"\0", 1)[0]
            part_len, salt_len, digest_len, hash_flags = struct.unpack(">IIII", body[40:56])
            variable = body[116:]
            need = part_len + salt_len + digest_len
            if len(variable) < need:
                raise ValueError("stock AVB hash descriptor variable data is truncated")
            partition = variable[:part_len]
            salt = variable[part_len:part_len + salt_len]
            if hash_algorithm != b"sha256" or digest_len != 32 or not partition:
                raise ValueError("stock AVB hash descriptor is not the expected SHA-256 boot descriptor")
            if hash_flags != 0:
                raise ValueError("stock AVB hash descriptor flags are non-zero")

            digest = hashlib.sha256(salt + boot_data).digest()
            new_body = bytearray(body)
            new_body[:8] = struct.pack(">Q", len(boot_data))
            digest_start = 116 + part_len + salt_len
            new_body[digest_start:digest_start + digest_len] = digest
            if len(new_body) != len(body):
                raise ValueError("replacement hash descriptor changed its size")
            result[body_start:body_end] = new_body
            return bytes(result), partition.decode("ascii", "replace"), len(salt)
        pos = body_end
    raise ValueError("stock AVB hash descriptor was not found")


with open(stock_path, "rb") as fh:
    stock = fh.read()
if len(stock) < FOOTER_SIZE:
    raise SystemExit("[bootimg] Stock image is too small to contain an AVB footer")

magic, major, minor, _stock_orig_size, stock_vbmeta_offset, stock_vbmeta_size, reserved = struct.unpack(
    FOOTER_FMT, stock[-FOOTER_SIZE:]
)
if magic != b"AVBf":
    raise SystemExit("[bootimg] Stock image has no AVB footer; refusing to emit a different image contract")
if stock_vbmeta_offset + stock_vbmeta_size > len(stock) - FOOTER_SIZE:
    raise SystemExit("[bootimg] Stock AVB footer points outside the image")

with open(output_path, "rb") as fh:
    boot_data = fh.read()
if len(boot_data) >= FOOTER_SIZE and boot_data[-FOOTER_SIZE:-FOOTER_SIZE + 4] == b"AVBf":
    raise SystemExit("[bootimg] Repacked boot data unexpectedly already contains an AVB footer")

stock_vbmeta = stock[stock_vbmeta_offset:stock_vbmeta_offset + stock_vbmeta_size]
new_vbmeta, partition_name, salt_len = replace_stock_hash_descriptor(stock_vbmeta, boot_data)
original_size = len(boot_data)
partition_size = len(stock)
required = original_size + len(new_vbmeta) + FOOTER_SIZE
if required > partition_size:
    raise SystemExit(
        f"[bootimg] Repacked boot data plus AVB needs {required} bytes, "
        f"but the stock boot partition image is only {partition_size} bytes"
    )
padding_size = partition_size - required
new_footer = struct.pack(
    FOOTER_FMT,
    b"AVBf", major, minor,
    original_size,
    original_size,
    len(new_vbmeta),
    reserved,
)
with open(output_path, "wb") as fh:
    fh.write(boot_data)
    fh.write(new_vbmeta)
    fh.write(b"\0" * padding_size)
    fh.write(new_footer)

final_size = os.path.getsize(output_path)
if final_size != partition_size:
    raise SystemExit("[bootimg] Internal error: final image does not equal the stock partition size")
print(f"[bootimg] Stock partition size : {partition_size} bytes")
print(f"[bootimg] New boot data size    : {original_size} bytes")
print(f"[bootimg] Preserved AVB vbmeta  : {len(new_vbmeta)} bytes")
print(f"[bootimg] AVB descriptor        : partition={partition_name} sha256 salt={salt_len} bytes")
print(f"[bootimg] Zero padding           : {padding_size} bytes")
print(f"[bootimg] Final image size       : {final_size} bytes")
AVBEOF

OUT_BYTES=$(wc -c < "$OUTPUT_IMG")
STOCK_BYTES=$(wc -c < "$STOCK_IMG")
[ "$OUT_BYTES" -eq "$STOCK_BYTES" ] || fail "Final boot image is not exactly the stock partition image size"

ok "Motorola-compatible boot image created successfully"
ok "  Stock partition image size : $STOCK_BYTES bytes"
ok "  Final image size           : $OUT_BYTES bytes"
ok "  AVB descriptor             : stock metadata preserved; SHA-256 digest refreshed"
printf '\n'
echo -e "${CYAN}Do not flash until the release checksum is published and the bootloader contract is verified.${NC}"
