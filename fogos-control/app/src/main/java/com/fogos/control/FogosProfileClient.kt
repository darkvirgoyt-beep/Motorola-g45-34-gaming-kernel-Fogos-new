package com.fogos.control

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.charset.StandardCharsets

/**
 * Non-root client for the FogOS kernel profile endpoint.
 *
 * Android SELinux and ueventd must grant this signed app access to
 * /dev/fogos_profile. The client deliberately does not invoke su, shell
 * commands, or arbitrary kernel paths.
 */
class FogosProfileClient(
    private val device: File = File(DEVICE_PATH),
) {
    fun readProfile(): String? {
        return try {
            FileInputStream(device).bufferedReader(StandardCharsets.UTF_8).use { reader ->
                normalize(reader.readText())
            }
        } catch (_: IOException) {
            null
        } catch (_: SecurityException) {
            null
        }
    }

    fun writeProfile(profile: Profile): WriteResult {
        return try {
            FileOutputStream(device).use { output ->
                output.write((profile.id + "\n").toByteArray(StandardCharsets.UTF_8))
                output.flush()
            }
            val active = readProfile()
            if (active == profile.id) {
                WriteResult.Success(profile)
            } else {
                WriteResult.Failure("The kernel did not confirm profile ${profile.id}.")
            }
        } catch (_: IOException) {
            WriteResult.Failure(
                "FogOS control is unavailable. Install the signed app as a privileged FogOS app and merge the SELinux policy.",
            )
        } catch (_: SecurityException) {
            WriteResult.Failure(
                "Android denied access to /dev/fogos_profile. Check the FogOS SELinux domain and device label.",
            )
        }
    }

    private fun normalize(value: String): String? {
        val normalized = value.trim()
        return Profile.entries.firstOrNull { it.id == normalized }?.id
    }

    companion object {
        const val DEVICE_PATH = "/dev/fogos_profile"
    }
}

enum class Profile(
    val id: String,
    val title: String,
    val description: String,
) {
    BALANCED(
        id = "balanced",
        title = "Balanced",
        description = "Normal thermal and battery behavior.",
    ),
    PERFORMANCE(
        id = "performance",
        title = "Performance",
        description = "Faster response while retaining thermal protection.",
    ),
    EXTREME_GAMING(
        id = "extreme_gaming",
        title = "Extreme gaming",
        description = "Maximum FogOS gaming tuning with thermal protection retained.",
    ),
}

sealed interface WriteResult {
    data class Success(val profile: Profile) : WriteResult
    data class Failure(val message: String) : WriteResult
}
