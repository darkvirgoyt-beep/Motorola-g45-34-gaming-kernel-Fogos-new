package com.fogos.control

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.util.Locale
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class MainActivity : Activity() {
    private val client = FogosProfileClient()
    private val executor: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var connection: TextView
    private lateinit var activeProfile: TextView
    private lateinit var statusDetail: TextView
    private lateinit var applyButton: Button
    private lateinit var cpuValue: TextView
    private lateinit var cpuMeta: TextView
    private lateinit var gpuValue: TextView
    private lateinit var gpuMeta: TextView
    private lateinit var ramValue: TextView
    private lateinit var ramMeta: TextView
    private lateinit var tempValue: TextView
    private lateinit var tempMeta: TextView
    private lateinit var batteryValue: TextView
    private lateinit var batteryMeta: TextView
    private lateinit var kernelValue: TextView
    private lateinit var kernelMeta: TextView
    private lateinit var fpsValue: TextView
    private lateinit var fpsMeta: TextView
    private val profileCards = mutableMapOf<Profile, LinearLayout>()
    private var selectedProfile = Profile.BALANCED
    private var telemetryTask: ScheduledFuture<*>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(5, 7, 5)
        window.navigationBarColor = Color.rgb(5, 7, 5)
        buildDashboard()
    }

    override fun onResume() {
        super.onResume()
        refreshProfile()
        startTelemetry()
    }

    override fun onPause() {
        telemetryTask?.cancel(false)
        telemetryTask = null
        super.onPause()
    }

    override fun onDestroy() {
        telemetryTask?.cancel(true)
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun buildDashboard() {
        val scroll = ScrollView(this).apply {
            setBackgroundColor(COLOR_BACKGROUND)
            isFillViewport = true
            overScrollMode = View.OVER_SCROLL_NEVER
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(12), dp(18), dp(28))
            setBackgroundColor(COLOR_BACKGROUND)
        }
        scroll.addView(root)

        val glowBar = View(this).apply { setBackgroundColor(COLOR_LIME) }
        root.addView(glowBar, LinearLayout.LayoutParams(-1, dp(3)).apply {
            bottomMargin = dp(18)
        })

        root.addView(buildTopBar())
        root.addView(space(18))
        root.addView(buildStatusPill())
        root.addView(space(14))
        root.addView(buildActiveProfileCard())
        root.addView(space(18))
        root.addView(sectionLabel("PERFORMANCE PROFILES", "SELECT A SYSTEM TUNING PRESET"))
        root.addView(space(10))
        Profile.entries.forEach { profile ->
            val card = buildProfileCard(profile)
            profileCards[profile] = card
            root.addView(card, LinearLayout.LayoutParams(-1, dp(82)).apply {
                bottomMargin = dp(10)
            })
        }
        root.addView(space(4))
        root.addView(buildApplyButton(), LinearLayout.LayoutParams(-1, dp(58)).apply {
            bottomMargin = dp(22)
        })
        root.addView(sectionLabel("LIVE KERNEL TELEMETRY", "READ-ONLY DEVICE HUD"))
        root.addView(space(10))
        root.addView(buildTelemetryGrid())
        root.addView(space(18))
        root.addView(buildFooter())

        setContentView(scroll)
    }

    private fun buildTopBar(): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val logo = ImageView(this).apply {
            setImageResource(R.drawable.fogos_profile_changer_logo)
            scaleType = ImageView.ScaleType.CENTER_CROP
            contentDescription = "FogOS Profile Changer logo"
            background = rounded(COLOR_PANEL, COLOR_LIME, 1)
            setPadding(dp(3), dp(3), dp(3), dp(3))
        }
        row.addView(logo, LinearLayout.LayoutParams(dp(68), dp(68)))

        val titleColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), 0, 0, 0)
        }
        titleColumn.addView(label("FOGOS", 12f, COLOR_LIME, true))
        titleColumn.addView(label("Profile Changer", 25f, Color.WHITE, true))
        titleColumn.addView(label("MOTO G45 / G34  •  SM6375", 10f, COLOR_MUTED, false).apply {
            letterSpacing = 0.12f
            setPadding(0, dp(3), 0, 0)
        })
        row.addView(titleColumn, LinearLayout.LayoutParams(0, -2, 1f))

        val signal = TextView(this).apply {
            text = "◉\nLINK"
            gravity = Gravity.CENTER
            textSize = 10f
            letterSpacing = 0.08f
            setTextColor(COLOR_LIME)
            background = rounded(Color.rgb(17, 29, 17), COLOR_GREEN, 1)
            setPadding(dp(8), dp(5), dp(8), dp(5))
        }
        row.addView(signal, LinearLayout.LayoutParams(dp(54), dp(48)))
        return row
    }

    private fun buildStatusPill(): View {
        connection = TextView(this).apply {
            text = "  ◉  INITIALIZING KERNEL LINK"
            textSize = 11f
            letterSpacing = 0.08f
            gravity = Gravity.CENTER_VERTICAL
            setTextColor(COLOR_LIME)
            background = rounded(Color.rgb(12, 25, 14), COLOR_GREEN, 1)
            setPadding(dp(10), 0, dp(10), 0)
        }
        return connection
    }

    private fun buildActiveProfileCard(): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = rounded(COLOR_PANEL, COLOR_LIME, 2)
            elevation = dp(10).toFloat()
        }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(label("ACTIVE PROFILE", 11f, COLOR_LIME, true), LinearLayout.LayoutParams(0, -2, 1f))
        header.addView(label("LIVE", 10f, COLOR_LIME, true).apply {
            letterSpacing = 0.16f
            background = rounded(Color.rgb(20, 44, 19), COLOR_LIME, 1)
            setPadding(dp(9), dp(4), dp(9), dp(4))
        })
        card.addView(header)
        activeProfile = label("BALANCED", 32f, Color.WHITE, true).apply {
            setPadding(0, dp(9), 0, dp(3))
            letterSpacing = 0.08f
        }
        card.addView(activeProfile)
        statusDetail = label("Thermal-safe daily configuration", 12f, COLOR_MUTED, false)
        card.addView(statusDetail)
        return card
    }

    private fun buildProfileCard(profile: Profile): LinearLayout {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), dp(12), dp(14), dp(12))
            background = rounded(COLOR_CARD, COLOR_BORDER, 1)
            isClickable = true
            isFocusable = true
            setOnClickListener { selectProfile(profile, this) }
        }
        val accent = TextView(this).apply {
            text = when (profile) {
                Profile.EXTREME_GAMING -> "⚡"
                Profile.PERFORMANCE -> "🚀"
                Profile.BALANCED -> "🔋"
            }
            textSize = 22f
            gravity = Gravity.CENTER
            setTextColor(COLOR_LIME)
        }
        card.addView(accent, LinearLayout.LayoutParams(dp(38), -1))

        val textColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), 0, dp(8), 0)
        }
        textColumn.addView(label(profile.title.uppercase(Locale.US), 15f, Color.WHITE, true).apply {
            letterSpacing = 0.06f
        })
        textColumn.addView(label(profile.description, 11f, COLOR_MUTED, false).apply {
            setPadding(0, dp(5), 0, 0)
        })
        card.addView(textColumn, LinearLayout.LayoutParams(0, -2, 1f))

        val chevron = label("›", 28f, COLOR_MUTED, false).apply {
            gravity = Gravity.CENTER
        }
        card.addView(chevron, LinearLayout.LayoutParams(dp(24), -1))
        return card
    }

    private fun buildApplyButton(): Button {
        applyButton = Button(this).apply {
            text = "APPLY PROFILE  〉"
            textSize = 15f
            letterSpacing = 0.1f
            setTextColor(Color.rgb(3, 10, 3))
            typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
            setAllCaps(false)
            background = rounded(COLOR_LIME, COLOR_LIME, 1)
            elevation = dp(8).toFloat()
            setOnClickListener { applySelectedProfile() }
        }
        return applyButton
    }

    private fun buildTelemetryGrid(): LinearLayout {
        val grid = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val cpu = metricCard("CPU LOAD", "--", "SAMPLING", "CPU")
        cpuValue = cpu.first
        cpuMeta = cpu.second
        val gpu = metricCard("GPU LOAD", "--", "FREQUENCY --", "GPU")
        gpuValue = gpu.first
        gpuMeta = gpu.second
        val ram = metricCard("MEMORY", "--", "AVAILABLE", "RAM")
        ramValue = ram.first
        ramMeta = ram.second
        val temp = metricCard("THERMAL", "--", "SENSOR LINK", "TMP")
        tempValue = temp.first
        tempMeta = temp.second
        val battery = metricCard("BATTERY", "--", "POWER STATE", "BAT")
        batteryValue = battery.first
        batteryMeta = battery.second
        val kernel = metricCard("KERNEL", "--", "RELEASE", "SYS")
        kernelValue = kernel.first
        kernelMeta = kernel.second
        val fps = metricCard("FPS", "--", "GAME OVERLAY", "FPS")
        fpsValue = fps.first
        fpsMeta = fps.second
        val device = metricCard("DEVICE", "G45", "FOGOS TARGET", "DEV")

        addMetricRow(grid, cpu.third, gpu.third)
        addMetricRow(grid, ram.third, temp.third)
        addMetricRow(grid, battery.third, kernel.third)
        addMetricRow(grid, fps.third, device.third)
        return grid
    }

    private fun metricCard(title: String, initial: String, meta: String, code: String): Triple<TextView, TextView, LinearLayout> {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(13), dp(11), dp(13), dp(10))
            background = rounded(COLOR_CARD, COLOR_BORDER, 1)
        }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(label(title, 10f, COLOR_MUTED, true), LinearLayout.LayoutParams(0, -2, 1f))
        header.addView(label(code, 9f, COLOR_GREEN, true).apply { letterSpacing = 0.14f })
        card.addView(header)
        val value = label(initial, 22f, Color.WHITE, true).apply {
            setPadding(0, dp(8), 0, dp(1))
        }
        card.addView(value)
        val metaText = label(meta, 9f, COLOR_MUTED, false).apply { letterSpacing = 0.08f }
        card.addView(metaText)
        return Triple(value, metaText, card)
    }

    private fun addMetricRow(parent: LinearLayout, left: View, right: View) {
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row.addView(left, LinearLayout.LayoutParams(0, dp(104), 1f).apply { rightMargin = dp(6); bottomMargin = dp(8) })
        row.addView(right, LinearLayout.LayoutParams(0, dp(104), 1f).apply { leftMargin = dp(6); bottomMargin = dp(8) })
        parent.addView(row)
    }

    private fun buildFooter(): View {
        val footer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(15), dp(14), dp(15))
            background = rounded(Color.rgb(9, 16, 10), Color.rgb(31, 62, 31), 1)
        }
        footer.addView(label("FOGOS PROFILE CHANGER  •  PROFILE LINK READY", 10f, COLOR_LIME, true).apply {
            gravity = Gravity.CENTER
            letterSpacing = 0.08f
        })
        footer.addView(label("Thermal protection remains enabled", 10f, COLOR_MUTED, false).apply {
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, 0)
        })
        return footer
    }

    private fun selectProfile(profile: Profile, card: LinearLayout) {
        selectedProfile = profile
        profileCards.values.forEach { it.background = rounded(COLOR_CARD, COLOR_BORDER, 1) }
        card.background = rounded(Color.rgb(17, 35, 17), COLOR_LIME, 2)
        card.animate().scaleX(1.02f).scaleY(1.02f).setDuration(120).setInterpolator(DecelerateInterpolator()).withEndAction {
            card.animate().scaleX(1f).scaleY(1f).setDuration(140).start()
        }.start()
        applyButton.text = "APPLY ${profile.title.uppercase(Locale.US)}  〉"
        connection.text = "  ◉  PROFILE QUEUED  //  ${profile.id.uppercase(Locale.US)}"
    }

    private fun applySelectedProfile() {
        applyButton.isEnabled = false
        applyButton.alpha = 0.65f
        applyButton.text = "APPLYING  //  ${selectedProfile.title.uppercase(Locale.US)}"
        connection.text = "  ◌  WRITING PROFILE TO KERNEL"
        executor.execute {
            val result = client.writeProfile(selectedProfile)
            runOnUiThread {
                applyButton.isEnabled = true
                applyButton.alpha = 1f
                applyButton.text = "APPLY ${selectedProfile.title.uppercase(Locale.US)}  〉"
                when (result) {
                    is WriteResult.Success -> {
                        activeProfile.text = result.profile.title.uppercase(Locale.US)
                        statusDetail.text = "Profile link established  •  thermal-safe tuning active"
                        connection.text = "  ◉  PROFILE APPLIED  //  ${result.profile.id.uppercase(Locale.US)}"
                        Toast.makeText(this, "PROFILE APPLIED  •  ${result.profile.title}", Toast.LENGTH_SHORT).show()
                        activeProfile.animate().alpha(0.35f).setDuration(100).withEndAction {
                            activeProfile.animate().alpha(1f).setDuration(240).start()
                        }.start()
                    }
                    is WriteResult.Failure -> {
                        connection.text = "  !  KERNEL LINK UNAVAILABLE"
                        statusDetail.text = result.message
                        Toast.makeText(this, result.message, Toast.LENGTH_LONG).show()
                    }
                }
            }
        }
    }

    private fun refreshProfile() {
        executor.execute {
            val profileId = client.readProfile()
            val profile = Profile.entries.firstOrNull { it.id == profileId }
            runOnUiThread {
                if (profile == null) {
                    connection.text = "  !  KERNEL LINK UNAVAILABLE"
                    activeProfile.text = "OFFLINE"
                    statusDetail.text = "Flash CONFIG_FOGOS_PROFILE=y and merge the FogOS SELinux policy"
                    return@runOnUiThread
                }
                selectedProfile = profile
                activeProfile.text = profile.title.uppercase(Locale.US)
                statusDetail.text = profile.description
                profileCards[profile]?.let { card ->
                    profileCards.values.forEach { it.background = rounded(COLOR_CARD, COLOR_BORDER, 1) }
                    card.background = rounded(Color.rgb(17, 35, 17), COLOR_LIME, 2)
                }
                applyButton.text = "APPLY ${profile.title.uppercase(Locale.US)}  〉"
                connection.text = "  ◉  KERNEL LINK ESTABLISHED"
            }
        }
    }

    private fun startTelemetry() {
        telemetryTask?.cancel(false)
        telemetryTask = executor.scheduleAtFixedRate({
            val snapshot = TelemetrySnapshot.read(this)
            mainHandler.post { renderTelemetry(snapshot) }
        }, 0, 2, TimeUnit.SECONDS)
    }

    private fun renderTelemetry(snapshot: TelemetrySnapshot) {
        cpuValue.text = snapshot.cpuLoad
        cpuMeta.text = snapshot.cpuFrequency
        gpuValue.text = snapshot.gpuLoad
        gpuMeta.text = snapshot.gpuFrequency
        ramValue.text = snapshot.ramUsed
        ramMeta.text = snapshot.ramMeta
        tempValue.text = snapshot.temperature
        tempMeta.text = snapshot.temperatureMeta
        batteryValue.text = snapshot.battery
        batteryMeta.text = snapshot.batteryMeta
        kernelValue.text = snapshot.kernel
        kernelMeta.text = snapshot.kernelMeta
        fpsValue.text = snapshot.fps
        fpsMeta.text = snapshot.fpsMeta
    }

    private fun sectionLabel(title: String, subtitle: String): View {
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        column.addView(label(title, 12f, Color.WHITE, true).apply { letterSpacing = 0.12f })
        column.addView(label(subtitle, 9f, COLOR_MUTED, false).apply {
            letterSpacing = 0.14f
            setPadding(0, dp(4), 0, 0)
        })
        return column
    }

    private fun label(textValue: String, size: Float, textColor: Int, bold: Boolean): TextView {
        return TextView(this).apply {
            text = textValue
            textSize = size
            setTextColor(textColor)
            typeface = Typeface.create("sans-serif-condensed", if (bold) Typeface.BOLD else Typeface.NORMAL)
        }
    }

    private fun space(height: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(1, dp(height))
    }

    private fun rounded(fill: Int, stroke: Int, strokeWidth: Int): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            setColor(fill)
            setStroke(dp(strokeWidth), stroke)
            cornerRadius = dp(18).toFloat()
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val COLOR_BACKGROUND = 0xFF050705.toInt()
        private const val COLOR_PANEL = 0xFF101711.toInt()
        private const val COLOR_CARD = 0xFF0C120E.toInt()
        private const val COLOR_BORDER = 0xFF1D3520.toInt()
        private const val COLOR_LIME = 0xFFB7FF2C.toInt()
        private const val COLOR_GREEN = 0xFF4DFF47.toInt()
        private const val COLOR_MUTED = 0xFF849183.toInt()
    }
}

private data class TelemetrySnapshot(
    val cpuLoad: String,
    val cpuFrequency: String,
    val gpuLoad: String,
    val gpuFrequency: String,
    val ramUsed: String,
    val ramMeta: String,
    val temperature: String,
    val temperatureMeta: String,
    val battery: String,
    val batteryMeta: String,
    val kernel: String,
    val kernelMeta: String,
    val fps: String,
    val fpsMeta: String,
) {
    companion object {
        fun read(context: Context): TelemetrySnapshot {
            val mem = readMemory()
            val batteryIntent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val batteryPct = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val batteryScale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
            val batteryTemp = batteryIntent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
            val batteryStatus = batteryIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val charging = batteryStatus == BatteryManager.BATTERY_STATUS_CHARGING || batteryStatus == BatteryManager.BATTERY_STATUS_FULL
            val temp = if (batteryTemp > 0) String.format(Locale.US, "%.1f°C", batteryTemp / 10f) else "--"
            val battery = if (batteryPct >= 0 && batteryScale > 0) "${batteryPct * 100 / batteryScale}%" else "--"
            val freq = readFirst(
                "/sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq",
                "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq",
            )?.let { "${it.toLongOrNull()?.div(1000) ?: it} MHz" } ?: "FREQ --"
            val gpuFreq = readFirst(
                "/sys/class/kgsl/kgsl-3d0/devfreq/cur_freq",
                "/sys/class/kgsl/kgsl-3d0/gpuclk",
            )?.let { "${it.toLongOrNull()?.div(1000000) ?: it} MHz" } ?: "FREQ --"
            return TelemetrySnapshot(
                cpuLoad = readCpuLoad(),
                cpuFrequency = freq,
                gpuLoad = "--",
                gpuFrequency = gpuFreq,
                ramUsed = mem.first,
                ramMeta = mem.second,
                temperature = temp,
                temperatureMeta = if (batteryTemp > 0) "BATTERY SENSOR" else "SENSOR LINK",
                battery = battery,
                batteryMeta = if (charging) "CHARGING" else "ON BATTERY",
                kernel = System.getProperty("os.version")?.substringBefore(' ').orEmpty().ifBlank { "--" },
                kernelMeta = "LINUX RELEASE",
                fps = "--",
                fpsMeta = "GAME OVERLAY",
            )
        }

        private fun readCpuLoad(): String {
            return try {
                val first = readProcStat()
                Thread.sleep(220)
                val second = readProcStat()
                val idleDelta = second.first - first.first
                val totalDelta = second.second - first.second
                if (totalDelta <= 0) "--" else "${((totalDelta - idleDelta) * 100 / totalDelta).coerceIn(0, 100)}%"
            } catch (_: Exception) {
                "--"
            }
        }

        private fun readProcStat(): Pair<Long, Long> {
            val line = File("/proc/stat").bufferedReader().use { it.readLine() }
            val values = line.trim().split(Regex("\\s+")).drop(1).map { it.toLongOrNull() ?: 0L }
            val idle = (values.getOrNull(3) ?: 0L) + (values.getOrNull(4) ?: 0L)
            return idle to values.sum()
        }

        private fun readMemory(): Pair<String, String> {
            return try {
                var total = 0L
                var available = 0L
                File("/proc/meminfo").forEachLine { line ->
                    when {
                        line.startsWith("MemTotal:") -> total = line.filter { it.isDigit() }.toLongOrNull() ?: 0L
                        line.startsWith("MemAvailable:") -> available = line.filter { it.isDigit() }.toLongOrNull() ?: 0L
                    }
                }
                val used = (total - available).coerceAtLeast(0L) / 1024 / 1024f
                val totalGb = total / 1024 / 1024f
                String.format(Locale.US, "%.1f GB", used) to String.format(Locale.US, "%.1f GB USED / %.1f GB", used, totalGb)
            } catch (_: Exception) {
                "--" to "MEMORY LINK"
            }
        }

        private fun readFirst(vararg paths: String): String? {
            for (path in paths) {
                try {
                    val value = File(path).readText().trim()
                    if (value.isNotEmpty()) return value
                } catch (_: Exception) {
                    // The matching ROM SELinux policy may hide optional telemetry paths.
                }
            }
            return null
        }
    }
}
