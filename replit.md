# VirgoYT Gaming Kernel — FogOS Extreme Gaming Edition

**Developer:** Prince · VirgoYT707  
**Device:** Motorola G45 / G34 (SM6375 — Holi Platform)  
**Base:** Linux 5.4.302 · Android 16  

This repo is a kernel source tree — it is not a web app and has no Replit preview.  
All builds run on **GitHub Actions** (Ubuntu 24.04, ARM64 cross-compile).

---

## How to push changes from Replit → GitHub

```bash
git add <files>
git commit -m "your message"
git push origin HEAD:main
```

The `GH_PAT` secret (already saved) is embedded in the remote URL automatically by the environment.  
If you ever rotate your token, update the remote:

```bash
git remote set-url origin "https://${GH_PAT}@github.com/darkvirgoyt-beep/Motorola-g45-34-gaming-kernel-Fogos-new.git"
```

---

## GitHub Actions Workflows

| Workflow | File | Trigger |
|----------|------|---------|
| Build kernel + boot.img + release | `.github/workflows/build.yml` | Push to `main`/`sixteen-qpr2`, or manual |
| Publish release from artifact | `.github/workflows/release.yml` | Manual only |

### What the build does
1. Installs ARM64 cross-compiler (clang + gcc-aarch64)
2. Configures kernel with `arch/arm64/configs/vendor/fogos_defconfig`
3. Builds `out/arch/arm64/boot/Image`
4. Repacks `stock/boot.img` → `release/FogOS-boot-<DATE>.img` via `scripts/create_bootimg.sh`
5. Packs AnyKernel3 TWRP ZIP
6. Creates a **public GitHub Release** with both files attached

### Triggering a release manually
Go to **Actions → FogOS Kernel — Build & Boot Image → Run workflow** and set `release = true`.  
Or just push any kernel/config/script change to `main` — a release is created automatically.

---

## Key files

| Path | Purpose |
|------|---------|
| `arch/arm64/configs/vendor/fogos_defconfig` | FogOS gaming kernel config |
| `scripts/create_bootimg.sh` | Unpacks stock boot.img, replaces kernel, repacks |
| `anykernel3/` | AnyKernel3 template for TWRP flashing |
| `stock/boot.img` | Stock Moto G45 boot image used as base |
| `CHANGES.md` | Changelog / patch notes |
| `fogos_oc.md` | Overclocking guide (DTS OPP table) |

---

## User preferences
- Push all changes from Replit to the `main` branch on GitHub using `GH_PAT`.
- Keep existing project structure — do not restructure or rename dirs.
