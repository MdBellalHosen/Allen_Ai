package com.allen.allen_ai.actions

import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.provider.Settings
import com.allen.allen_ai.accessibility.AllenAccessibilityService

/**
 * Android does not let normal apps flip Wi-Fi / Bluetooth / Do-Not-Disturb programmatically (API 29+),
 * so those open the matching system panel. The torch can be switched directly.
 */
class SystemSettings(private val ctx: Context) {
    private var torchOn = false

    fun torch(on: Boolean?): Result<Boolean> = try {
        val cm = ctx.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val id = cm.cameraIdList.firstOrNull {
            cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } ?: throw IllegalStateException("no_flash")
        val target = on ?: !torchOn
        cm.setTorchMode(id, target)
        torchOn = target
        Result.success(target)
    } catch (e: Exception) {
        Result.failure(e)
    }

    /** name: wifi | bluetooth | dnd | airplane. Opens the panel; returns false if it could not open. */
    fun openPanel(name: String): Boolean {
        val intent = when (name) {
            "wifi" ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY)
                else Intent(Settings.ACTION_WIFI_SETTINGS)
            "bluetooth" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            "dnd" -> Intent("android.settings.ZEN_MODE_PRIORITY_SETTINGS")
            "airplane" -> Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS)
            else -> return false
        }
        return try {
            val c = AllenAccessibilityService.instance ?: ctx
            c.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
    }
}
