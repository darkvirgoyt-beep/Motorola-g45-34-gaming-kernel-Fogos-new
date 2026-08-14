package com.fogos.control

import android.app.Activity
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.util.concurrent.Executors

class MainActivity : Activity() {
    private val client = FogosProfileClient()
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var status: TextView
    private lateinit var connection: TextView
    private lateinit var buttons: List<Button>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(20))
            setBackgroundColor(Color.rgb(18, 18, 18))
        }

        val title = TextView(this).apply {
            text = "FogOS Control"
            textSize = 28f
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, dp(6))
        }
        root.addView(title)

        val subtitle = TextView(this).apply {
            text = "Kernel profile controller · no root shell"
            textSize = 15f
            setTextColor(Color.LTGRAY)
            setPadding(0, 0, 0, dp(18))
        }
        root.addView(subtitle)

        connection = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.rgb(255, 183, 77))
            setPadding(0, 0, 0, dp(12))
        }
        root.addView(connection)

        status = TextView(this).apply {
            textSize = 15f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.rgb(38, 38, 38))
            setPadding(dp(14), dp(14), dp(14), dp(14))
        }
        root.addView(status, LinearLayout.LayoutParams(-1, -2).apply {
            bottomMargin = dp(18)
        })

        val section = TextView(this).apply {
            text = "Select profile"
            textSize = 19f
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, dp(8))
        }
        root.addView(section)

        buttons = Profile.entries.map { profile ->
            Button(this).apply {
                text = "${profile.title}\n${profile.description}"
                textSize = 14f
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
                setAllCaps(false)
                setOnClickListener { applyProfile(profile) }
            }.also { button ->
                root.addView(button, LinearLayout.LayoutParams(-1, dp(64)).apply {
                    bottomMargin = dp(8)
                })
            }
        }

        val note = TextView(this).apply {
            text = "Interface: ${FogosProfileClient.DEVICE_PATH}\nThe FogOS runtime service applies the selected profile and keeps thermal protection enabled."
            textSize = 13f
            setTextColor(Color.LTGRAY)
            setPadding(0, dp(18), 0, 0)
        }
        root.addView(note)

        setContentView(ScrollView(this).apply { addView(root) })
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun refresh() {
        connection.text = "Checking FogOS kernel interface…"
        status.text = "Reading ${FogosProfileClient.DEVICE_PATH}…"
        executor.execute {
            val profile = client.readProfile()
            runOnUiThread {
                if (profile == null) {
                    connection.text = "Connection unavailable"
                    connection.setTextColor(Color.rgb(255, 138, 128))
                    status.text = "The app cannot read the FogOS kernel interface.\n\nFlash a kernel with CONFIG_FOGOS_PROFILE=y and install this APK as the signed privileged FogOS app with the matching SELinux policy."
                } else {
                    connection.text = "Connected to FogOS kernel"
                    connection.setTextColor(Color.rgb(129, 199, 132))
                    status.text = "Active profile: ${profile.replace('_', ' ')}\n\nDevice: ${Build.MANUFACTURER} ${Build.MODEL}\nAndroid: ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})\nKernel endpoint: ${FogosProfileClient.DEVICE_PATH}"
                }
            }
        }
    }

    private fun applyProfile(profile: Profile) {
        buttons.forEach { it.isEnabled = false }
        connection.text = "Applying ${profile.title}…"
        executor.execute {
            val result = client.writeProfile(profile)
            runOnUiThread {
                buttons.forEach { it.isEnabled = true }
                when (result) {
                    is WriteResult.Success -> {
                        Toast.makeText(this, "${profile.title} profile requested", Toast.LENGTH_SHORT).show()
                    }
                    is WriteResult.Failure -> {
                        Toast.makeText(this, result.message, Toast.LENGTH_LONG).show()
                    }
                }
                refresh()
            }
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
