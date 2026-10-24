package sk.codemit.spurtly

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var liveActivity: LiveActivityChannel? = null
    private var vibration: VibrationChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveActivity = LiveActivityChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        vibration = VibrationChannel(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        liveActivity?.dispose()
        liveActivity = null
        vibration?.dispose()
        vibration = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
