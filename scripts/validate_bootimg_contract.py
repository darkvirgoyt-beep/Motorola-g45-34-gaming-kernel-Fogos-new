#!/usr/bin/env python3
"""Fail-closed validator for FogOS boot images repacked from the active Evolution X base."""
import hashlib
import os
import struct
import sys

FOOTER_FMT = ">4sIIQQQ28s"
FOOTER_SIZE = struct.calcsize(FOOTER_FMT)
HEADER_FMT = ">4sIIQQI" + ("Q" * 11) + "II48s80s"
HEADER_SIZE = struct.calcsize(HEADER_FMT)
HASH_DESCRIPTOR_TAG = 2


def die(message: str) -> None:
    raise SystemExit(f"[bootimg-validate] FAIL: {message}")


def footer(image: bytes):
    if len(image) < FOOTER_SIZE:
        die("image is too short for an AVB footer")
    fields = struct.unpack(FOOTER_FMT, image[-FOOTER_SIZE:])
    if fields[0] != b"AVBf":
        die("AVB footer magic is missing")
    _magic, major, minor, original_size, vbmeta_offset, vbmeta_size, reserved = fields
    if vbmeta_offset + vbmeta_size > len(image) - FOOTER_SIZE:
        die("AVB footer references vbmeta outside the image")
    return major, minor, original_size, vbmeta_offset, vbmeta_size, reserved


def find_hash_descriptor(vbmeta: bytes):
    if len(vbmeta) < HEADER_SIZE:
        die("vbmeta is shorter than its required header")
    fields = struct.unpack(HEADER_FMT, vbmeta[:HEADER_SIZE])
    if fields[0] != b"AVB0":
        die("vbmeta magic is missing")
    q_values = fields[6:17]
    auth_size, aux_size = fields[3], fields[4]
    desc_offset, desc_size = q_values[8], q_values[9]
    aux_start = HEADER_SIZE + auth_size
    start = aux_start + desc_offset
    end = start + desc_size
    if aux_start + aux_size > len(vbmeta) or end > len(vbmeta):
        die("vbmeta descriptor bounds are invalid")
    pos = start
    while pos + 16 <= end:
        tag, body_size = struct.unpack(">QQ", vbmeta[pos:pos + 16])
        body_start = pos + 16
        body_end = body_start + body_size
        if body_end > end:
            die("vbmeta descriptor is truncated")
        if tag == HASH_DESCRIPTOR_TAG:
            body = vbmeta[body_start:body_end]
            if len(body) < 116:
                die("AVB hash descriptor is too short")
            image_size = struct.unpack(">Q", body[:8])[0]
            algorithm = body[8:40].split(b"\0", 1)[0]
            part_len, salt_len, digest_len, flags = struct.unpack(">IIII", body[40:56])
            variable_start = 116
            digest_start = variable_start + part_len + salt_len
            if digest_start + digest_len > len(body):
                die("AVB hash descriptor variable data is truncated")
            partition = body[variable_start:variable_start + part_len]
            salt = body[variable_start + part_len:digest_start]
            digest = body[digest_start:digest_start + digest_len]
            return fields, body_start, body_end, image_size, algorithm, partition, salt, digest, flags
        pos = body_end
    die("AVB hash descriptor was not found")


def main(stock_path: str, candidate_path: str) -> None:
    with open(stock_path, "rb") as fh:
        stock = fh.read()
    with open(candidate_path, "rb") as fh:
        candidate = fh.read()

    if len(candidate) != len(stock):
        die(f"candidate is {len(candidate)} bytes, expected exact stock partition size {len(stock)}")

    stock_footer = footer(stock)
    cand_footer = footer(candidate)
    if (stock_footer[0], stock_footer[1], stock_footer[4], stock_footer[5]) != (
        cand_footer[0], cand_footer[1], cand_footer[4], cand_footer[5]
    ):
        die("candidate AVB footer version, vbmeta size, or reserved bytes differ from stock")

    _sfields, sbody_start, sbody_end, _simage_size, salg, spartition, ssalt, _sdigest, sflags = find_hash_descriptor(
        stock[stock_footer[3]:stock_footer[3] + stock_footer[4]]
    )
    cfields, cbody_start, cbody_end, cimage_size, calg, cpartition, csalt, cdigest, cflags = find_hash_descriptor(
        candidate[cand_footer[3]:cand_footer[3] + cand_footer[4]]
    )

    if cfields[0] != b"AVB0" or cfields[17] != 0:
        die("candidate AVB header is not the stock verification-enabled form")
    if (calg, cpartition, csalt, cflags) != (salg, spartition, ssalt, sflags):
        die("candidate AVB hash descriptor changed the stock algorithm, partition name, salt, or flags")
    if cimage_size != cand_footer[2] or cand_footer[3] != cand_footer[2]:
        die("candidate AVB footer does not point to the complete boot-data region")
    if calg != b"sha256" or len(cdigest) != 32:
        die("candidate AVB digest is not SHA-256")
    if hashlib.sha256(csalt + candidate[:cimage_size]).digest() != cdigest:
        die("candidate AVB digest does not verify the boot data")

    stock_vbmeta = bytearray(stock[stock_footer[3]:stock_footer[3] + stock_footer[4]])
    cand_vbmeta = bytearray(candidate[cand_footer[3]:cand_footer[3] + cand_footer[4]])
    # The only allowed vbmeta differences are the boot-data image size and
    # digest inside the existing stock hash descriptor.
    for buf, start, end, body_start, body_end in (
        (stock_vbmeta, sbody_start, sbody_end, sbody_start, sbody_end),
        (cand_vbmeta, cbody_start, cbody_end, cbody_start, cbody_end),
    ):
        body = buf[body_start:body_end]
        part_len, salt_len, digest_len, _flags = struct.unpack(">IIII", body[40:56])
        body[:8] = b"\0" * 8
        digest_start = 116 + part_len + salt_len
        body[digest_start:digest_start + digest_len] = b"\0" * digest_len
        buf[body_start:body_end] = body
    if stock_vbmeta != cand_vbmeta:
        die("candidate changed AVB metadata beyond the allowed hash fields")

    print("[bootimg-validate] PASS")
    print(f"[bootimg-validate] partition_size={len(stock)}")
    print(f"[bootimg-validate] boot_data_size={cimage_size}")
    print(f"[bootimg-validate] avb_partition={cpartition.decode('ascii', 'replace')}")
    print(f"[bootimg-validate] sha256={hashlib.sha256(candidate).hexdigest()}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: validate_bootimg_contract.py <stock_boot.img> <candidate_boot.img>")
    main(sys.argv[1], sys.argv[2])
