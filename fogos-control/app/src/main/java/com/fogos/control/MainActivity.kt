package com.fogos.control

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class MainActivity : Activity() {
    private val profileFile = "/data/local/fogos_profile"
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        status = TextView(this).apply { textSize = 16f; setPadding(24, 24, 24, 24) }
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(24, 24, 24, 24) }
        layout.addView(status)
        listOf("balanced" to "Balanced Mode", "performance" to "Performance Mode", "extreme_gaming" to "Extreme Gaming Mode").forEach { (profile, label) ->
            layout.addView(Button(this).apply { text = label; setOnClickListener { setProfile(profile) } })
        }
        setContentView(ScrollView(this).apply { addView(layout) })
        refresh()
    }

    private fun setProfile(profile: String) {
        runRoot("echo $profile > $profileFile; sh /data/adb/modules/fogos/profile_manager.sh $profile || sh /system/bin/profile_manager.sh $profile")
        refresh()
    }

    private fun refresh() {
        val profile = runRoot("cat $profileFile 2>/dev/null || echo balanced").trim().ifEmpty { "balanced" }
        val kernel = runRoot("uname -r").trim()
        val cpu = runRoot("cat /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null | sort -u | tr '\n' ' '").trim()
        val gpu = runRoot("cat /sys/class/kgsl/kgsl-3d0/devfreq/governor 2>/dev/null").trim().ifEmpty { "unavailable" }
        val temp = runRoot("for t in /sys/class/thermal/thermal_zone*/temp; do cat \$t 2>/dev/null; done | sort -nr | head -1").trim()
        val ram = runRoot("awk '/MemAvailable|MemTotal/ {print}' /proc/meminfo").trim()
        status.text = "Profile: $profile\nKernel: $kernel\nCPU governors: $cpu\nGPU governor: $gpu\nMax temp(m°C): $temp\nRAM:\n$ram"
    }

    private fun runRoot(command: String): String = try {
        val process = Runtime.getRuntime().exec(arrayOf("su", "-c", command))
        process.inputStream.bufferedReader().readText().also { process.waitFor() }
    } catch (_: Exception) { "Root unavailable" }
}
