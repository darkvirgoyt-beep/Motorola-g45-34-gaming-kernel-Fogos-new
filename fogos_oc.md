# FogOS — Overclocking Guide (SM6375 / Holi)
## Can you overclock from 2.3 GHz to 2.5 GHz?

**Short answer:** Yes, but it requires modifying the device tree (DTS). Here is the full explanation and how to do it.

---

## How SM6375 CPU clocking works

The SM6375 uses Qualcomm's **EPSS (Epoch SubSystem)** hardware clock controller.
Frequencies are stored in a **hardware Look-Up Table (LUT)** inside the EPSS firmware.
The kernel reads these entries and exposes them as `scaling_available_frequencies`.

**Stock SM6375 Kryo 560 Gold (big core) LUT:**
```
614400
864000
1075200
1267200
1459200
1651200
1843200
1958400
2054400
2208000   ← typical hardware ceiling
```

> Some silicon bins (higher-quality chips) may go up to 2.3 GHz if Qualcomm validated that bin. Whether your chip does 2.3 GHz depends on the physical silicon.

---

## What the init script already does

The `fogos_gaming_init.sh` sets:
```sh
scaling_min_freq = cpuinfo_max_freq   # whatever is your chip's actual ceiling
scaling_max_freq = cpuinfo_max_freq
governor         = performance
```
This means your CPU **always runs at 100% of its certified maximum**. If your chip shows 2.3 GHz in `cpuinfo_max_freq`, it runs at 2.3 GHz 100% of the time.

---

## True OC: Adding 2.5 GHz OPP entry

To actually run at 2.5 GHz, you must add a new frequency+voltage OPP entry in the device tree and rebuild.

### Step 1 — Locate the OPP table in the DTS

In your Moto G45 DTS (once you have it), find:
```dts
&CPU4 {
    /* or cluster4 / cluster1 on Holi */
    opp-table {
        compatible = "operating-points-v2-kryo-cpu";
        ...
        opp-2208000000 {
            opp-hz = /bits/ 64 <2208000000>;
            opp-microvolt = <...>;
        };
    };
};
```

### Step 2 — Add the new OPP entry

```dts
        opp-2400000000 {
            opp-hz = /bits/ 64 <2400000000>;
            opp-microvolt = <1000000>;  /* Start at 1.0V — increase if unstable */
            clock-latency-ns = <200000>;
        };
        opp-2496000000 {
            opp-hz = /bits/ 64 <2496000000>;
            opp-microvolt = <1050000>;  /* 1.05V for 2.5GHz — tune up if crashes */
            clock-latency-ns = <200000>;
        };
```

### Step 3 — Verify EPSS LUT accepts the new entry

Qualcomm EPSS firmware may clamp to its internal LUT. Check after boot:
```bash
cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_available_frequencies
```
If 2496000 does not appear, the HW LUT is clamping it. You would then need to modify `drivers/cpufreq/qcom-cpufreq-hw.c` to bypass the LUT ceiling.

### Step 4 — Voltage tuning (important for stability)
- Start with +25mV above the highest stock entry voltage
- Run a stress test: `stress-ng --cpu 8 --timeout 5m`
- Increase by 25mV increments if you get reboots
- Temperature will rise — keep an eye on sensor readings

---

## ⚠️ Safety note

- **Stability first:** If the phone bootloops, flash the zip again without the OC entry
- **Temperature:** Disabling thermal + OC means you must watch temps manually at first
- **Battery wear:** Running at max voltage/freq constantly drains battery faster and creates more heat — expected for gaming mode
- The init script can be modified to apply OC only when a game is detected (see `optimize_game()` function) if you want to preserve battery during non-gaming use

---

## Current effective state (without DTS OC)

With the FogOS v2.0 init script, your CPU is running at:
- **All 8 cores at max rated frequency, 100% of the time**
- **Performance governor (never scales down)**
- **No thermal throttle (trip = 125°C)**

This gives you the maximum performance your chip can safely deliver. The init script already does everything software can do — actual OC requires the DTS changes above.
