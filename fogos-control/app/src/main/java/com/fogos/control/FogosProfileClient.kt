package com.fogos.control

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.charset.StandardCharsets

/** Direct non-root client for the FogOS kernel profile endpoint. */
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
            WriteResult.Failure("FogOS control is unavailable. Check the app's device-node permissions and SELinux policy.")
        } catch (_: SecurityException) {
            WriteResult.Failure("Android denied access to /dev/fogos_profile.")
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
        description = "Restores stock CPU-idle behavior and thermal protection.",
    ),
    PERFORMANCE(
        id = "performance",
        title = "Performance",
        description = "Applies a modest CPU-idle latency hint while retaining stock thermal limits.",
    ),
    EXTREME_GAMING(
        id = "extreme_gaming",
        title = "Extreme gaming",
        description = "Applies the strongest supported low-latency hint; stock thermal limits stay active.",
    ),
}

sealed interface WriteResult {
    data class Success(val profile: Profile) : WriteResult
    data class Failure(val message: String) : WriteResult
}
