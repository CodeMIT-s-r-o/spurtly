package sk.codemit.spurtly

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The Android side of `PlatformVibrations` in Dart: a vibration pattern per
 * cue. It uses the alarm usage, like a kitchen timer, so it isn't scaled
 * down by the touch feedback settings and still plays while the screen is
 * locked (the workout's foreground service keeps the app in the foreground).
 */
class VibrationChannel(context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "spurtly/vibration")
    private val vibrator: Vibrator =
        if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                .defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "vibrate") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            // Off and on in milliseconds, starting with a pause.
            val timings = when (call.arguments as? String) {
                "work" -> longArrayOf(0, 180, 120, 180)
                "rest" -> longArrayOf(0, 450)
                "countdown" -> longArrayOf(0, 60)
                "finish" -> longArrayOf(0, 250, 150, 250, 150, 600)
                else -> null
            }
            if (timings != null && vibrator.hasVibrator()) vibrate(timings)
            result.success(null)
        }
    }

    private fun vibrate(timings: LongArray) {
        val effect = VibrationEffect.createWaveform(timings, -1)
        if (Build.VERSION.SDK_INT >= 33) {
            vibrator.vibrate(
                effect,
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(
                effect,
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
            )
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
