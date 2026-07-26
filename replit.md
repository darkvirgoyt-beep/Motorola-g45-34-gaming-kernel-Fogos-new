# FogOS Extreme Gaming Kernel — Build Dashboard

**Developer:** Prince · VirgoYT707  
**Device:** Motorola G45 5G (SM6375 / Holi Platform)  
**Kernel Base:** Linux 5.4.302 · Android 16  
**GitHub Repo:** [darkvirgoyt-beep/Motorola-g45-34-gaming-kernel-Fogos-new](https://github.com/darkvirgoyt-beep/Motorola-g45-34-gaming-kernel-Fogos-new)  
**Branch:** `sixteen-qpr2`

---

## How to run

```bash
python app.py
```

The web dashboard serves at **port 5000** and lets you trigger GitHub Actions kernel builds with a button.

---

## Required Secret

Add your GitHub Personal Access Token as a Replit Secret:

| Key | Value |
|-----|-------|
| `FOGOS_GITHUB_TOKEN` | Your GitHub PAT |

**PAT scopes needed:** `repo` (full) + `workflow`  
→ [Generate PAT here](https://github.com/settings/tokens)

The dashboard shows a red banner if the token is missing or invalid.

---

## Project structure

| Path | Purpose |
|------|---------|
| `app.py` | Flask Build Dashboard web app |
| `templates/index.html` | Dashboard UI |
| `.github/workflows/build.yml` | GitHub Actions build pipeline |
| `scripts/create_bootimg.sh` | Repacks stock boot.img with new kernel |
| `scripts/trigger_build.sh` | CLI alternative to trigger builds |
| `arch/arm64/configs/vendor/fogos_defconfig` | Kernel configuration |
| `arch/arm64/configs/vendor/fogos_gaming.config` | Gaming optimisation fragment |
| `anykernel3/` | TWRP flashable ZIP scripts |
| `stock/boot.img` | Reference stock boot image for repacking |

---

## Build outputs

GitHub Actions produces:
- `FogOS-boot-<DATE>.img` — fastboot-flashable boot image
- `FogOS-Extreme-Gaming-v3-Holi-<DATE>.zip` — TWRP-flashable AnyKernel3 ZIP

Flash via fastboot:
```bash
adb reboot bootloader
fastboot flash boot FogOS-boot-<DATE>.img
fastboot reboot
```

---

## Kernel features (v3)

- Full Qualcomm QDSP6 audio stack — speaker, mic, earpiece, BT, Dolby Atmos
- Venus hardware video decoder — fixes Reels / YT Shorts loading
- Widevine L1 (HDCP_QSEECOM) — HD Netflix / Hotstar / Prime
- 3 gaming profiles: Balanced / Performance / Extreme Gaming
- Clang LLVM + LTO + ThinLTO compiler pipeline
- TCP BBR + WLAN power-save off for lowest ping
- WALT + SCHED_CASS scheduler
- PREEMPT full + HZ_300

---

## User preferences

- Never hardcode tokens — always use Replit Secrets
- Keep stock compatibility — do not remove vendor drivers
- Preserve Dolby Atmos and Motorola charging drivers
