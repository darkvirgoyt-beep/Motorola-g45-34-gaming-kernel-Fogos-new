# VirgoYT Gaming Kernel — FogOS Build Dashboard

## Project Overview

A Flask web dashboard for triggering and monitoring GitHub Actions kernel builds for the **VirgoYT Gaming Kernel (FogOS Extreme Gaming Edition)** — a hand-tuned Android gaming kernel for Motorola G45 / G34 (SM6375 / Holi platform), Linux 5.4.302, Android 16.

**The kernel compiles on GitHub Actions (remote CI), not locally.** This Replit app is the control panel.

## How to Run

```
python app.py
```

The workflow `Start application` handles this automatically on port 5000.

## Architecture

- `app.py` — Flask backend; proxies GitHub API calls to trigger builds, fetch run status, and stream logs
- `templates/index.html` — Single-page dashboard UI (vanilla JS, dark theme)
- `.github/workflows/build.yml` — GitHub Actions workflow that cross-compiles the kernel (aarch64 toolchain) and produces a flashable ZIP/boot.img
- `anykernel3/` — AnyKernel3 installer scripts packed into the release ZIP
- `build_fogos.sh` / `build.config.*` — Kernel build configuration files

## GitHub Token

The dashboard needs a GitHub PAT with `repo` + `workflow` + `contents:write` scopes to trigger builds and read logs.

- **Stored as:** `FOGOS_GITHUB_TOKEN` Replit Secret (picked up automatically)
- **Fallback:** paste directly into the "GitHub PAT Token" box in the dashboard UI (saved to `.fogos_token` file, owner-only)

## User Preferences

- Keep the existing Flask + vanilla JS stack — no framework migration needed.
- Kernel source structure is standard Linux — do not restructure.
