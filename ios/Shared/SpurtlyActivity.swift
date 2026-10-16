import ActivityKit
import AppIntents
import Foundation

// Compiled into both the app and the SpurtlyLiveActivity extension: the app
// starts and updates the activity, the extension draws it.

/// The workout Live Activity on the lock screen and in the Dynamic Island.
struct SpurtlyActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// `warmup`, `work`, `rest`, `roundRest` or `done`.
    var phase: String
    /// "Work", "Rest", ...
    var label: String
    /// "Round 2 / 3 · Interval 1 / 4".
    var position: String
    /// "Next: Rest · 0:15".
    var next: String
    var phaseStart: Date
    var phaseEnd: Date
    /// Seconds left in the phase while paused; `nil` while running.
    var pausedRemaining: Double?
  }
}

extension Notification.Name {
  /// Posted in the app process when a Live Activity button is tapped; the
  /// object is the action name sent on to Dart.
  static let spurtlyControl = Notification.Name("SpurtlyLiveActivityControl")
}

// Live Activity intents run in the app's process, so they can reach the
// timer through the notification above.

@available(iOS 17.0, *)
struct TogglePauseIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Pause or Resume Workout"
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    await MainActor.run {
      NotificationCenter.default.post(name: .spurtlyControl, object: "togglePause")
    }
    return .result()
  }
}

@available(iOS 17.0, *)
struct SkipPhaseIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Skip Phase"
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    await MainActor.run {
      NotificationCenter.default.post(name: .spurtlyControl, object: "skip")
    }
    return .result()
  }
}
