package sk.codemit.spurtly

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * The Android side of `PlatformLiveActivity` in Dart: shows the workout as
 * the notification of [WorkoutService] and forwards its buttons back.
 */
class LiveActivityChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "spurtly/live_activity")

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        WorkoutService.start(
                            context,
                            WorkoutState.from(call.argument<Map<*, *>>("state")!!),
                            controls = call.argument<Boolean>("controls") ?: true,
                        )
                        result.success(true)
                    }
                    "update" -> {
                        WorkoutService.update(
                            context,
                            WorkoutState.from(call.argument<Map<*, *>>("state")!!),
                        )
                        result.success(null)
                    }
                    "end" -> {
                        WorkoutService.end(
                            context,
                            call.argument<Map<*, *>>("state")?.let(WorkoutState::from),
                            call.argument<Double>("dismissAfterSeconds")
                                ?.let { (it * 1000).toLong() },
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                // E.g. the service may not start while the app is in the
                // background; the app then falls back to plain notifications.
                result.error("live_activity", error.message, null)
            }
        }
        WorkoutService.onControl = { control -> channel.invokeMethod("control", control) }
    }

    /** The engine is going away: nothing can react to the buttons anymore. */
    fun dispose() {
        WorkoutService.onControl = null
        WorkoutService.end(context, finalState = null, dismissAfterMs = null)
        channel.setMethodCallHandler(null)
    }
}
