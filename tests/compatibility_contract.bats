#!/usr/bin/env bats
#
# Contract tests for the active FogOS Android 17 release inputs. These guards
# prevent accidental reintroduction of the configuration and installer defects
# that break Evolution X vendor_dlkm modules or rootless packaging.

load helpers/common

setup() {
  REPO_ROOT="$(fogos_repo_root)"
}

@test "FogOS defconfig preserves the stock module ABI contract" {
  local cfg="${REPO_ROOT}/arch/arm64/configs/vendor/fogos_defconfig"

  grep -Fx 'CONFIG_LOCALVERSION="-moto-KAGE-影"' "$cfg"
  grep -Fx 'CONFIG_MODVERSIONS=y' "$cfg"
  grep -Fx 'CONFIG_LTO=y' "$cfg"
  grep -Fx 'CONFIG_THINLTO=y' "$cfg"
  grep -Fx 'CONFIG_LTO_CLANG=y' "$cfg"
  grep -Fx 'CONFIG_CFI_CLANG=y' "$cfg"
  grep -Fx 'CONFIG_CFI_CLANG_SHADOW=y' "$cfg"
  grep -Fx 'CONFIG_CAMERA_CCI_INTF=m' "$cfg"
  grep -Fx 'CONFIG_SND_SOC_FS1815=m' "$cfg"
  grep -Fx 'CONFIG_FOGOS_PROFILE=y' "$cfg"
}

@test "release defconfig retains every recorded Evolution X vendor_dlkm module mode" {
  local cfg="${REPO_ROOT}/arch/arm64/configs/vendor/fogos_defconfig"
  local baseline="${REPO_ROOT}/tests/data/vendor_module_abi_required_m.txt"
  local symbol

  while IFS= read -r symbol; do
    [[ -z "$symbol" || "$symbol" == \#* ]] && continue
    grep -Fx "${symbol}=m" "$cfg"
  done < "$baseline"
}

@test "minimal gaming fragment does not override vendor module modes or enable KernelSU" {
  local cfg="${REPO_ROOT}/arch/arm64/configs/vendor/fogos_gaming.config"

  grep -Fx 'CONFIG_FOGOS_PROFILE=y' "$cfg"
  grep -Fx '# CONFIG_KSU is not set' "$cfg"
  ! grep -Eq '^CONFIG_(CAMERA_CCI_INTF|SND_SOC_FS1815)=' "$cfg"
  ! grep -Eq '^CONFIG_(KSU|KERNELSU)=' "$cfg"
  [ ! -e "${REPO_ROOT}/arch/arm64/configs/vendor/fogos_gaming_defconfig" ]
  [ ! -e "${REPO_ROOT}/arch/arm64/configs/vendor/fogos_gaming_extreme.config" ]
}

@test "AnyKernel configuration is rootless and active-slot-aware" {
  local installer="${REPO_ROOT}/anykernel3/anykernel.sh"

  grep -Fx 'do.modules=0' "$installer"
  grep -Fx 'do.systemless=0' "$installer"
  grep -Fx 'NO_MAGISK_CHECK=1' "$installer"
  grep -Fx 'dump_boot;' "$installer"
  grep -Fx 'split_boot;' "$installer"
  grep -Fx 'flash_boot;' "$installer"
  ! grep -Eq '^[[:space:]]*(do\.modules|do\.systemless)=1' "$installer"
}

@test "fogos overlay preserves stock thermal safety" {
  local overlay="${REPO_ROOT}/arch/arm64/boot/dts/vendor/qcom/blair-fogos-common-overlay.dtsi"

  ! grep -Eq 'thermal-governor = "user_space"|temperature = <125000>|sdm-skin-therm-usr|chg-skin-therm-usr' "$overlay"
}

@test "PulseControl remains a direct non-root profile client" {
  local app_src="${REPO_ROOT}/fogos-control/app/src/main"

  grep -R -F '/dev/fogos_profile' "$app_src"
  ! grep -RE '(Runtime\.getRuntime|ProcessBuilder|/system/bin/sh|[[:space:]]su[[:space:]])' "$app_src"
}

@test "FogOS profiles use only a bounded kernel latency QoS hint" {
  local profile_src="${REPO_ROOT}/drivers/misc/fogos_profile.c"

  grep -F '#define FOGOS_PERFORMANCE_LATENCY_US 1000' "$profile_src"
  grep -F '#define FOGOS_EXTREME_GAMING_LATENCY_US 500' "$profile_src"
  grep -F 'pm_qos_add_request(&fogos_latency_qos, PM_QOS_CPU_DMA_LATENCY,' "$profile_src"
  grep -F 'pm_qos_remove_request(&fogos_latency_qos);' "$profile_src"
  ! grep -Eq 'scaling_(min|max)_freq|force_clk_on|force_no_nap|trip_point|/sys/class/thermal|sched_boost|sched_util_clamp' "$profile_src"
}

@test "release source contains no root runtime payload or legacy tuning scripts" {
  local packer="${REPO_ROOT}/build_fogos.sh"

  [ ! -e "${REPO_ROOT}/magisk" ]
  [ ! -e "${REPO_ROOT}/anykernel3/fogos_lib.sh" ]
  [ ! -e "${REPO_ROOT}/anykernel3/fogos_gaming_init.sh" ]
  [ ! -e "${REPO_ROOT}/anykernel3/fogos_game_detector.sh" ]
  ! grep -F 'cp -a "${KERNEL_DIR}/magisk"' "$packer"
  ! grep -F 'magisk META-INF' "$packer"
}

@test "boot packer preserves the stock AVB contract and CI invokes the validator" {
  local packer="${REPO_ROOT}/scripts/create_bootimg.sh"
  local validator="${REPO_ROOT}/scripts/validate_bootimg_contract.py"
  local workflow="${REPO_ROOT}/.github/workflows/build.yml"

  [ -x "$validator" ]
  grep -F 'Preserve the entire stock vbmeta block byte-for-byte' "$packer"
  grep -F 'validate_bootimg_contract.py' "$workflow"
}
