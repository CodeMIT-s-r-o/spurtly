import ActivityKit
import Flutter
import Foundation

/// Lets Dart start, update and end the workout Live Activity
/// (`spurtly/live_activity`), and sends taps on its buttons back to Dart as
/// `control` calls.
final class LiveActivityChannel: NSObject {
  private let channel: FlutterMethodChannel
  private var controlObserver: NSObjectProtocol?
  private var activityID: String?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "spurtly/live_activity", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    controlObserver = NotificationCenter.default.addObserver(
      forName: .spurtlyControl, object: nil, queue: .main
    ) { [weak self] notification in
      guard let action = notification.object as? String else { return }
      self?.channel.invokeMethod("control", arguments: action)
    }
    // An activity left over from a run that was killed would show a frozen
    // timer with buttons nobody listens to.
    if #available(iOS 17.0, *) {
      Task { await Self.endAll() }
    }
  }

  deinit {
    if let controlObserver { NotificationCenter.default.removeObserver(controlObserver) }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // The buttons need interactive Live Activities, which arrived in iOS 17.
    guard #available(iOS 17.0, *) else {
      result(call.method == "start" ? false : nil)
      return
    }
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "start":
      guard ActivityAuthorizationInfo().areActivitiesEnabled,
        let state = Self.state(from: arguments?["state"])
      else {
        result(false)
        return
      }
      Task { @MainActor in
        await Self.endAll()
        do {
          let activity = try Activity.request(
            attributes: SpurtlyActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil)
          )
          self.activityID = activity.id
          result(true)
        } catch {
          NSLog("Spurtly: Live Activity not started: \(error)")
          result(false)
        }
      }
    case "update":
      guard let activity = currentActivity(), let state = Self.state(from: arguments?["state"]) else {
        result(nil)
        return
      }
      Task {
        await activity.update(ActivityContent(state: state, staleDate: nil))
        result(nil)
      }
    case "end":
      guard let activity = currentActivity() else {
        // Nothing running: clear whatever is still on screen, such as a
        // finished workout's summary.
        Task {
          await Self.endAll()
          result(nil)
        }
        return
      }
      activityID = nil
      let finalState = Self.state(from: arguments?["state"])
      var dismissal = ActivityUIDismissalPolicy.immediate
      if let seconds = arguments?["dismissAfterSeconds"] as? Double {
        dismissal = .after(Date().addingTimeInterval(seconds))
      }
      Task {
        await activity.end(
          finalState.map { ActivityContent(state: $0, staleDate: nil) },
          dismissalPolicy: dismissal
        )
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 17.0, *)
  private func currentActivity() -> Activity<SpurtlyActivityAttributes>? {
    Activity<SpurtlyActivityAttributes>.activities.first { $0.id == activityID }
  }

  @available(iOS 17.0, *)
  private static func endAll() async {
    for activity in Activity<SpurtlyActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private static func state(from value: Any?) -> SpurtlyActivityAttributes.ContentState? {
    guard let map = value as? [String: Any],
      let phase = map["phase"] as? String,
      let label = map["label"] as? String,
      let position = map["position"] as? String,
      let next = map["next"] as? String,
      let start = map["phaseStartMs"] as? Double,
      let end = map["phaseEndMs"] as? Double
    else { return nil }
    return SpurtlyActivityAttributes.ContentState(
      phase: phase,
      label: label,
      position: position,
      next: next,
      phaseStart: Date(timeIntervalSince1970: start / 1000),
      phaseEnd: Date(timeIntervalSince1970: max(start, end) / 1000),
      pausedRemaining: map["pausedRemaining"] as? Double
    )
  }
}
