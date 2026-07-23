# FogOS Extreme Gaming Kernel - Change Log

## v1.0 — Initial Release
**Developer:** Prince (VirgoYT707)  
**Device:** Motorola G45 (SM6375 / Holi)  
**Base:** Linux 5.4.302 (Android GKI)

---

### 🔧 Configuration Changes (`arch/arm64/configs/vendor/fogos_gaming.config`)

#### CPU
- `CONFIG_PREEMPT=y` — Full kernel preemption (lowest scheduling latency)
- `CONFIG_SCHED_WALT=y` + `CONFIG_SCHED_CASS=y` — WALT + CASS scheduler
- `CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y` — Fast, adaptive WALT-aware governor
- `CONFIG_UCLAMP_TASK=y` + `CONFIG_UCLAMP_TASK_GROUP=y` — Task utility clamping
- `CONFIG_UCLAMP_BUCKETS_COUNT=20` — Fine-grained uclamp buckets
- `CONFIG_HIGH_RES_TIMERS=y` — High-resolution timer subsystem
- `CONFIG_SCHED_MC=y` + `CONFIG_SCHED_SMT=y` — Multi-core aware scheduling

#### GPU
- `CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y` — Adreno TZ governor
- `CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y` — GPU bandwidth monitor
- `CONFIG_QCOM_KGSL=y` — Qualcomm GPU driver

#### Memory
- `CONFIG_LRU_GEN=y` + `CONFIG_LRU_GEN_ENABLED=y` — MGLRU memory reclaim
- `CONFIG_ZRAM=y` + `CONFIG_ZRAM_DEF_COMP_ZSTD=y` — ZRAM with ZSTD
- `CONFIG_TRANSPARENT_HUGEPAGE=y` — THP for better memory throughput
- `CONFIG_BALANCE_ANON_FILE_RECLAIM=y` — Better RAM/cache balance
- `CONFIG_PRIORITIZE_OOM_TASKS=y` — Smart OOM task selection
- `CONFIG_SLUB_CPU_PARTIAL=y` — Faster per-CPU memory allocation

#### I/O
- `CONFIG_IOSCHED_BFQ=y` + `CONFIG_BFQ_GROUP_IOSCHED=y` — BFQ I/O scheduler
- `CONFIG_DEFAULT_IOSCHED="bfq"` — BFQ as default
- `CONFIG_MQ_IOSCHED_DEADLINE=y` + `CONFIG_MQ_IOSCHED_KYBER=y` — Additional schedulers

#### Network
- `CONFIG_TCP_CONG_BBR=y` — BBR congestion control
- `CONFIG_DEFAULT_TCP_CONG="bbr"` — BBR as default
- `CONFIG_TCP_CONG_ADVANCED=y` — All TCP algorithms available
- `CONFIG_NET_SCH_FQ=y` + `CONFIG_NET_SCH_FQ_CODEL=y` — FQ/FQ-CoDel qdiscs

#### Filesystem
- `CONFIG_F2FS_FS=y` — F2FS flash-optimized filesystem
- `CONFIG_EROFS_FS=y` — EROFS read-only compressed filesystem
- `CONFIG_EXFAT_FS=y` — ExFAT support
- `CONFIG_DCACHE_WORD_ACCESS=y` — Faster dentry cache

#### Performance / Optimization
- `CONFIG_INLINE_OPTIMIZATION=y` — Aggressive function inlining
- `CONFIG_LLVM_POLLY=y` — Polly loop optimizer
- `CONFIG_LTO_CLANG=y` — Link Time Optimization
- `CONFIG_ADAPTIVE_TOLERANCE_OPTIMIZATION=y` — Adaptive CPU tolerance
- `CONFIG_RCU_FAST_NO_HZ=y` + `CONFIG_RCU_NOCB_CPU=y` — RCU optimizations
- `CONFIG_SUSPEND_SKIP_SYNC=y` — Skip sync on suspend (faster resume)
- `CONFIG_WIREGUARD=y` — Fast in-kernel VPN
- `CONFIG_NR_CPUS=8` — 8 CPUs (SM6375 octa-core)
- `CONFIG_ZRAM_SIZE_OVERRIDE=3` — ZRAM = 3× RAM

#### Debug Disabled
- `CONFIG_DISABLE_TRACE_PRINTK=y`
- `# CONFIG_DEBUG_PREEMPT is not set`
- `# CONFIG_SLUB_DEBUG is not set`
- `# CONFIG_DEBUG_KMEMLEAK is not set`
- `# CONFIG_DEBUG_VM is not set`
- `# CONFIG_BUG_ON_DATA_CORRUPTION is not set`

---

### 🚀 Runtime Tweaks (`anykernel3/fogos_gaming_init.sh`)

Applied at every boot via init.d:

| Category | Tweak |
|----------|-------|
| CPU | schedutil governor, 200μs up ramp, 2ms down ramp, big core min 1.7GHz |
| CPU Boost | Input boost: CPU4-7 → 1.7GHz for 80ms on touch |
| GPU | msm-adreno-tz, idle_timer=64, throttling=0 |
| Memory | swappiness=40, vfs_cache_pressure=50, dirty_ratio=20, extra_free_kbytes=24300 |
| ZRAM | comp_algorithm=zstd |
| I/O | BFQ, low_latency=1, slice_idle=0, read_ahead_kb=128 |
| Network | TCP BBR + FQ, Fast Open, keepalive tuned, fin_timeout=15 |
| Scheduler | min_granularity=1ms, latency=5ms, wakeup_gran=0.5ms |
| Thermal | Trip points +3°C (max 95°C) |
| Power | workqueue power_efficient=N |
| Logging | printk level 4 (warnings+errors only) |
| Filesystem | fstrim /data + /cache at boot (background) |
