# FogOS Extreme Gaming Kernel — Change Log

---

## v2.0 — Ultra Gaming Mode
**Developer:** Prince (VirgoYT707)  
**Device:** Motorola G45 (SM6375 / Holi)  
**Base:** Linux 5.4.302 (Android GKI)

### New in v2.0

| Area | Change |
|------|--------|
| CPU | Switched from schedutil → **performance governor** (always at max) |
| CPU | `scaling_min_freq = scaling_max_freq = cpuinfo_max_freq` (hard locked) |
| CPU | Big-core (CPU4-7) deep C-states disabled (C0/C1 only — zero wake latency) |
| GPU | `devfreq min_freq = max_freq` (GPU locked to absolute max clock) |
| GPU | `force_no_nap=1` — GPU power collapse disabled |
| GPU | `max_pwrlevel=0` — highest power bin enforced |
| Thermal | **All thermal zones disabled** at boot (`mode=disabled`) |
| Thermal | **All trip points → 125°C** (no throttle before physical limit) |
| Thermal | `msm_thermal enabled=N` — SW thermal mitigation off |
| Charging | **33W turbo** — charge current set to 3300mA / USB input 3700mA |
| Charging | `fast_charge_enable=1` on PMIC nodes |
| Display | 120 FPS frame scheduling — RT priority for SurfaceFlinger/composer |
| Display | `schedtune.boost=100` for top-app, `prefer_idle=1` |
| Touch | Touch + input IRQs pinned to big cores (CPU6-7 affinity `0xf0`) |
| Touch | `input_boost_ms=2000` (2s boost after every touch) |
| Touch | WLAN power-save disabled (`iwconfig wlan0 power off`) |
| BGMI/PUBG | Game processes pinned to CPU4-7 (`taskset 0xf0`) |
| BGMI/PUBG | `SCHED_FIFO` + `renice -20` on game PID |
| BGMI/PUBG | Game PID added to top-app cgroup/cpuset/stune |
| BGMI/PUBG | Background loop re-applies tuning every 30s after game launch |
| Network | `net.ipv4.tcp_keepalive_time=10` (was 60) — dead connections detected instantly |
| Network | `tcp_nodelay=1` — packets sent immediately (no Nagle buffering) |
| Network | DSCP EF marking on UDP + HTTPS (game traffic gets network priority) |
| Network | `tcp_mtu_probing=1` — finds optimal packet size per route |
| Memory | `vm.swappiness=20` (was 40) — keep even more game data in RAM |
| Memory | `vm.extra_free_kbytes=48600` (was 24300) — bigger LMKD buffer |
| Scheduler | `sched_min_granularity_ns=500000` (was 1ms → 0.5ms) |
| Scheduler | `sched_latency_ns=3000000` (was 5ms → 3ms) |
| Scheduler | `sched_wakeup_granularity_ns=250000` (was 0.5ms → 0.25ms) |
| Logging | Tracing disabled (`tracing_on=0`) |
| Logging | `printk="3 3 1 7"` (errors only) |
| New file | `fogos_oc.md` — overclocking guide (DTS OPP table, 2.5GHz how-to) |

---

## v1.0 — Initial Release

### Configuration (`arch/arm64/configs/vendor/fogos_gaming.config`)

#### CPU
- `CONFIG_PREEMPT=y` — Full kernel preemption
- `CONFIG_SCHED_WALT=y` + `CONFIG_SCHED_CASS=y`
- `CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y`
- `CONFIG_UCLAMP_TASK=y` + `CONFIG_UCLAMP_TASK_GROUP=y`
- `CONFIG_HIGH_RES_TIMERS=y`
- `CONFIG_SCHED_MC=y` + `CONFIG_SCHED_SMT=y`

#### GPU
- `CONFIG_DEVFREQ_GOV_QCOM_ADRENO_TZ=y`
- `CONFIG_DEVFREQ_GOV_QCOM_GPUBW_MON=y`

#### Memory
- `CONFIG_LRU_GEN=y` + `CONFIG_LRU_GEN_ENABLED=y`
- `CONFIG_ZRAM=y` + `CONFIG_ZRAM_DEF_COMP_ZSTD=y`
- `CONFIG_TRANSPARENT_HUGEPAGE=y`
- `CONFIG_BALANCE_ANON_FILE_RECLAIM=y`
- `CONFIG_PRIORITIZE_OOM_TASKS=y`

#### I/O
- `CONFIG_IOSCHED_BFQ=y`, `CONFIG_DEFAULT_IOSCHED="bfq"`
- `CONFIG_MQ_IOSCHED_DEADLINE=y`, `CONFIG_MQ_IOSCHED_KYBER=y`

#### Network
- `CONFIG_TCP_CONG_BBR=y`, `CONFIG_DEFAULT_TCP_CONG="bbr"`
- `CONFIG_NET_SCH_FQ=y`, `CONFIG_NET_SCH_FQ_CODEL=y`

#### Performance
- `CONFIG_INLINE_OPTIMIZATION=y`
- `CONFIG_LLVM_POLLY=y`
- `CONFIG_LTO_CLANG=y`
- `CONFIG_RCU_FAST_NO_HZ=y`

### New in v2.0 config (`fogos_gaming.config`)
- `CONFIG_THERMAL_WRITABLE_TRIPS=y` — runtime trip-point override
- `CONFIG_THERMAL_GOV_USER_SPACE=y` — userspace controls thermal
- `CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y` — performance as default
- `CONFIG_RT_GROUP_SCHED=y` — RT group for 120 FPS threads
- `CONFIG_QPNP_SMB5=y`, `CONFIG_QPNP_QNOVO=y` — 33W SMB charger
- `CONFIG_USB_PD_POLICY=y` — USB PD for QC4+/33W
- WLAN/BT power-save options disabled at config level
