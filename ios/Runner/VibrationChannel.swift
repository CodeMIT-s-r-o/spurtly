import AudioToolbox
import CoreHaptics
import Flutter
import UIKit

/// The iOS side of `PlatformVibrations` in Dart (`spurtly/vibration`).
/// Phase changes use the system vibration, which also plays while the app
/// runs in the background with the screen locked. The 3-2-1 ticks use Core
/// Haptics, which plays while the app is on screen; unlike
/// `UIImpactFeedbackGenerator` it isn't muted when System Haptics is off.
final class VibrationChannel: NSObject {
  private let channel: FlutterMethodChannel
  private var engine: CHHapticEngine?

  /// The system vibration lasts about 0.4 s; repeats are spaced so they
  /// don't merge into one.
  private static let gap: TimeInterval = 0.55

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "spurtly/vibration", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "vibrate" else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.arguments as? String {
      case "work": Self.buzz(times: 2)
      case "rest": Self.buzz(times: 1)
      case "finish": Self.buzz(times: 3)
      case "countdown": self?.tick()
      default: break
      }
      result(nil)
    }
  }

  private static func buzz(times: Int) {
    for index in 0..<times {
      DispatchQueue.main.asyncAfter(deadline: .now() + gap * Double(index)) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
      }
    }
  }

  /// A short, strong tap.
  private func tick() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
      UIApplication.shared.applicationState == .active
    else { return }
    do {
      let engine = try startedEngine()
      let event = CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
        ],
        relativeTime: 0
      )
      let player = try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      NSLog("Spurtly: haptic tick failed: \(error)")
    }
  }

  /// The system stops the engine in the background and after a reset, so
  /// it is started before every tick; starting a running engine is cheap.
  private func startedEngine() throws -> CHHapticEngine {
    let engine = try self.engine ?? CHHapticEngine()
    // Only haptics: the cues play through the app's own audio session.
    engine.playsHapticsOnly = true
    try engine.start()
    self.engine = engine
    return engine
  }
}
