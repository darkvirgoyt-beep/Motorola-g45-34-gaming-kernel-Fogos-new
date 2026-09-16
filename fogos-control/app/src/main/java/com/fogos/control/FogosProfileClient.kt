package com.fogos.control

import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.nio.charset.StandardCharsets

/** Controls the real FogOS kernel endpoint with direct and Magisk-root paths. */
class FogosProfileClient(private val device: File = File(DEVICE_PATH)) {
    fun readProfile(): String? = directRead() ?: rootCommand("cat $DEVICE_PATH")?.let(::normalize)

    fun writeProfile(profile: Profile): WriteResult {
        try {
            FileOutputStream(device).use { it.write((profile.id + "\n").toByteArray(StandardCharsets.UTF_8)) }
            if (directRead() == profile.id) return WriteResult.Success(profile)
        } catch (_: IOException) { } catch (_: SecurityException) { }
        val result = rootCommand("$BRIDGE_PATH set ${profile.id}")?.let(::normalize)
        return if (result == profile.id || readProfile() == profile.id) WriteResult.Success(profile)
        else WriteResult.Failure("FogOS kernel/module unavailable. Install the FogOS Control Bridge and approve root access.")
    }

    fun connectionState(): ConnectionState {
        val kernel = File(DEVICE_PATH).exists()
        val module = rootCommand("test -x $BRIDGE_PATH && echo ready") == "ready"
        return when {
            kernel && module -> ConnectionState.CONNECTED
            kernel -> ConnectionState.KERNEL_ONLY
            module -> ConnectionState.MODULE_ONLY
            else -> ConnectionState.OFFLINE
        }
    }

    private fun directRead(): String? = try {
        FileInputStream(device).bufferedReader(StandardCharsets.UTF_8).use { normalize(it.readText()) }
    } catch (_: IOException) { null } catch (_: SecurityException) { null }

    private fun rootCommand(command: String): String? = try {
        val process = ProcessBuilder("su", "-c", command).redirectErrorStream(true).start()
        val output = process.inputStream.bufferedReader().use { it.readText().trim() }
        process.waitFor()
        output.takeIf { process.exitValue() == 0 }
    } catch (_: Exception) { null }

    private fun normalize(value: String?): String? = value?.trim()?.let { raw ->
        Profile.entries.firstOrNull { it.id == raw }?.id
    }

    companion object {
        const val DEVICE_PATH = "/dev/fogos_profile"
        const val BRIDGE_PATH = "/data/adb/modules/fogos-control/action.sh"
    }
}

enum class ConnectionState { CONNECTED, KERNEL_ONLY, MODULE_ONLY, OFFLINE }

enum class Profile(val id: String, val title: String, val description: String) {
    BALANCED("balanced", "Balanced", "Restores stock CPU-idle behavior and thermal protection."),
    PERFORMANCE("performance", "Performance", "Applies a bounded CPU-idle latency hint while retaining stock thermal limits."),
    EXTREME_GAMING("extreme_gaming", "Extreme gaming", "Applies the strongest supported low-latency hint; stock thermal limits stay active."),
}

sealed interface WriteResult {
    data class Success(val profile: Profile) : WriteResult
    data class Failure(val message: String) : WriteResult
}
