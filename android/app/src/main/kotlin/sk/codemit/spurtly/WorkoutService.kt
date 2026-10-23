package sk.codemit.spurtly

import android.Manifest
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.core.os.bundleOf

/** What the workout notification shows; mirrors `LiveActivityState` in Dart. */
data class WorkoutState(
    val phase: String,
    val label: String,
    val position: String,
    val next: String,
    val phaseEndMs: Long,
    /** Seconds left in the phase while paused; null while running. */
    val pausedRemaining: Double?,
) {
    companion object {
        fun from(map: Map<*, *>) = WorkoutState(
            phase = map["phase"] as String,
            label = map["label"] as String,
            position = map["position"] as String,
            next = map["next"] as String,
            phaseEndMs = (map["phaseEndMs"] as Number).toLong(),
            pausedRemaining = (map["pausedRemaining"] as Number?)?.toDouble(),
        )
    }
}

/**
 * Runs while a workout does, so Android keeps the app and its cues audible
 * with the screen off (Android 16 mutes background apps without one). Its
 * ongoing notification counts the phase down by itself and, with Pro, has
 * Pause/Resume and Skip buttons and asks to be a Live Update.
 */
class WorkoutService : Service() {
    companion object {
        /** 1 is the fallback notification from flutter_local_notifications. */
        private const val ONGOING_ID = 2
        private const val FINISHED_ID = 3
        private const val CHANNEL_ID = "workout_live"
        private const val ACTION_CONTROL = "sk.codemit.spurtly.CONTROL"
        private const val EXTRA_CONTROL = "control"

        /** The running workout; null once it ended. */
        private var state: WorkoutState? = null
        private var lastState: WorkoutState? = null
        private var controls = false
        private var running = false

        /** Forwards a tapped button ("togglePause" or "skip") to Dart. */
        var onControl: ((String) -> Unit)? = null

        fun start(context: Context, state: WorkoutState, controls: Boolean) {
            this.state = state
            lastState = state
            this.controls = controls
            NotificationManagerCompat.from(context).cancel(FINISHED_ID)
            ContextCompat.startForegroundService(
                context,
                Intent(context, WorkoutService::class.java),
            )
        }

        fun update(context: Context, state: WorkoutState) {
            this.state = state
            lastState = state
            if (running) post(context, ONGOING_ID, ongoing(context, state))
        }

        /** Stops the service, leaving [finalState] for [dismissAfterMs]. */
        fun end(context: Context, finalState: WorkoutState?, dismissAfterMs: Long?) {
            state = null
            context.stopService(Intent(context, WorkoutService::class.java))
            if (finalState == null) {
                NotificationManagerCompat.from(context).cancel(FINISHED_ID)
            } else {
                post(context, FINISHED_ID, finished(context, finalState, dismissAfterMs))
            }
        }

        private fun ongoing(context: Context, state: WorkoutState): Notification {
            val paused = state.pausedRemaining != null
            val summary = if (paused) {
                "${formatSeconds(state.pausedRemaining!!)} left · ${state.position}"
            } else {
                state.position
            }
            val builder = base(context, state, summary)
                .setOngoing(true)
                .setForegroundServiceBehavior(
                    NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE,
                )
            if (paused) {
                builder.setContentTitle("Paused · ${state.label}").setShowWhen(false)
            } else {
                // The system counts down to the end of the phase by itself.
                builder
                    .setWhen(state.phaseEndMs)
                    .setShowWhen(true)
                    .setUsesChronometer(true)
                    .setChronometerCountDown(true)
            }
            if (controls) {
                builder
                    .addAction(
                        if (paused) android.R.drawable.ic_media_play
                        else android.R.drawable.ic_media_pause,
                        if (paused) "Resume" else "Pause",
                        control(context, "togglePause"),
                    )
                    .addAction(
                        android.R.drawable.ic_media_next,
                        "Skip",
                        control(context, "skip"),
                    )
                    // Android 16+: a chip in the status bar with the
                    // countdown, like the Dynamic Island.
                    .addExtras(bundleOf("android.requestPromotedOngoing" to true))
            }
            return builder.build()
        }

        private fun finished(
            context: Context,
            state: WorkoutState,
            dismissAfterMs: Long?,
        ): Notification {
            val builder = base(context, state, state.position)
                .setShowWhen(false)
                .setAutoCancel(true)
            if (dismissAfterMs != null) builder.setTimeoutAfter(dismissAfterMs)
            return builder.build()
        }

        /** Shows [summary], and under it what comes next once expanded. */
        private fun base(context: Context, state: WorkoutState, summary: String) =
            NotificationCompat.Builder(context, channel(context))
                .setSmallIcon(R.drawable.ic_launcher_monochrome)
                .setColor(accent(state.phase))
                .setContentTitle(state.label)
                .setContentText(summary)
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText(listOf(summary, state.next)
                            .filter { it.isNotEmpty() }
                            .joinToString("\n")),
                )
                .setContentIntent(openApp(context))
                .setCategory(NotificationCompat.CATEGORY_WORKOUT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOnlyAlertOnce(true)
                .setSilent(true)

        /** Silent: the app plays its own cues. */
        private fun channel(context: Context): String {
            NotificationManagerCompat.from(context).createNotificationChannel(
                NotificationChannelCompat.Builder(
                    CHANNEL_ID,
                    NotificationManagerCompat.IMPORTANCE_DEFAULT,
                )
                    .setName("Workout in progress")
                    .setDescription("The running workout with its countdown.")
                    .setSound(null, null)
                    .setVibrationEnabled(false)
                    .setShowBadge(false)
                    .build(),
            )
            return CHANNEL_ID
        }

        private fun post(context: Context, id: Int, notification: Notification) {
            val allowed = Build.VERSION.SDK_INT < 33 ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) == PackageManager.PERMISSION_GRANTED
            if (allowed) NotificationManagerCompat.from(context).notify(id, notification)
        }

        private fun openApp(context: Context): PendingIntent? {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName) ?: return null
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        private fun control(context: Context, control: String): PendingIntent {
            val intent = Intent(context, WorkoutService::class.java)
                .setAction(ACTION_CONTROL)
                .putExtra(EXTRA_CONTROL, control)
            return PendingIntent.getService(
                context,
                control.hashCode(),
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }

        /** The phase colors of the app. */
        private fun accent(phase: String) = when (phase) {
            "warmup" -> 0xFFFFB547
            "work" -> 0xFFFF6A4D
            "rest" -> 0xFF2DD4BF
            "roundRest" -> 0xFF38BDF8
            else -> 0xFF8B92FF
        }.toInt()

        private fun formatSeconds(seconds: Double): String {
            val total = kotlin.math.ceil(seconds).toInt()
            return "%d:%02d".format(total / 60, total % 60)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CONTROL) {
            intent.getStringExtra(EXTRA_CONTROL)?.let { onControl?.invoke(it) }
            // A button on a notification left over from an ended workout.
            if (!running) stopSelf()
            return START_NOT_STICKY
        }
        // Android requires this after every startForegroundService, even if
        // the workout already ended in the meantime.
        val shown = state ?: lastState ?: return START_NOT_STICKY.also { stopSelf() }
        ServiceCompat.startForeground(
            this,
            ONGOING_ID,
            ongoing(this, shown),
            if (Build.VERSION.SDK_INT >= 29) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            } else {
                0
            },
        )
        running = true
        if (state == null) stopSelf()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
