# FogOS Extreme Gaming Kernel — Replit Workspace

**Developer:** Prince · VirgoYT707  
**Device:** Motorola G45 / G34 (SM6375 — Holi Platform)  
**Base:** Linux 5.4.302 · Android 16  
**Version:** v3 (in progress)

## Overview

This is the kernel source for the **VirgoYT Gaming Kernel (FogOS)** — a hand-tuned Android kernel for BGMI/PUBG gaming on Moto G45/G34. The kernel is cross-compiled in GitHub Actions and produces a flashable `boot.img`.

## How builds work

Builds run automatically in **GitHub Actions** — not on Replit. Replit is used for source editing and triggering builds via git push.

### Trigger a build

1. Make your source changes here in Replit.
2. Push to GitHub → GitHub Actions picks it up automatically and builds.
3. The Action produces:
   - `FogOS-boot-<DATE>.img` — fastboot-flashable boot image
   - `FogOS-Extreme-Gaming-v3-Holi-<DATE>.zip` — TWRP-flashable AnyKernel3 zip
4. On `push` to `main` / `sixteen-qpr2`, a GitHub Release is created automatically.

### GitHub Token

Add your Personal Access Token (PAT) as a **GitHub Repository Secret** named `FOGOS_GITHUB_TOKEN`:
> GitHub repo → Settings → Secrets and variables → Actions → New repository secret

This allows the workflow to make the repository public and create releases with elevated permissions.

## Key files

| File | Purpose |
|------|---------|
| `arch/arm64/configs/vendor/fogos_defconfig` | Main kernel config — hardware enablement |
| `arch/arm64/configs/vendor/fogos_gaming.config` | Gaming optimization config fragment |
| `anykernel3/fogos_gaming_init.sh` | Boot-time init: applies Balanced / Performance / Extreme Gaming profiles |
| `scripts/create_bootimg.sh` | Repacks stock `boot.img` with new kernel |
| `stock/boot.img` | Reference stock boot image for repacking |
| `.github/workflows/build.yml` | Full CI: configure → compile → pack → release |

## Gaming profiles (switch after boot)

```bash
# Extreme Gaming (default)
echo "extreme_gaming" > /data/local/fogos_profile

# Performance (balanced boost)
echo "performance" > /data/local/fogos_profile

# Balanced (daily driver / battery saver)
echo "balanced" > /data/local/fogos_profile
```

## Audio / Dolby Atmos

The kernel enables the full Qualcomm audio stack:
- **QDSP6 v2** — DSP framework (Q6AFE, Q6ADM, Q6ASM)
- **Bolero** — digital codec macro (RX/TX/VA macros)
- **WCD937x** — analog codec (speaker, mic, earpiece) — requires `MFD_WCD` + `REGMAP_WCD_IRQ`
- **QTI_PP** — post-processing (Dolby Atmos spatial audio)
- **SoundWire / BTFM_SLIM** — codec interconnect + Bluetooth audio

## User preferences

- Keep existing project structure — do not restructure or rename files
- Never hardcode secrets; use GitHub repository secrets
- Cross-compile only: do not attempt to build the kernel inside Replit itself
