import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SpurtlyWidgets: WidgetBundle {
  var body: some Widget {
    SpurtlyLiveActivity()
  }
}

struct SpurtlyLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SpurtlyActivityAttributes.self) { context in
      LockScreenView(state: context.state)
        .activityBackgroundTint(context.state.style.background)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Label(state.label, systemImage: state.style.symbol)
              .font(.headline)
              .foregroundStyle(state.style.accent)
            Text(state.position)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Countdown(state: state)
            .font(.system(size: 34, weight: .heavy).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 110, alignment: .trailing)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text(state.next)
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            // Icons only: the island is too narrow for labelled buttons.
            Controls(state: state, tint: state.style.accent)
              .labelStyle(.iconOnly)
          }
          .padding(.horizontal, 4)
        }
      } compactLeading: {
        Image(systemName: state.style.symbol)
          .foregroundStyle(state.style.accent)
      } compactTrailing: {
        Countdown(state: state)
          .monospacedDigit()
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 44)
          .foregroundStyle(state.style.accent)
      } minimal: {
        Image(systemName: state.style.symbol)
          .foregroundStyle(state.style.accent)
      }
      .keylineTint(state.style.accent)
    }
  }
}

private struct LockScreenView: View {
  let state: SpurtlyActivityAttributes.ContentState

  var body: some View {
    VStack(spacing: 10) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Label(state.isPaused ? "Paused" : state.label, systemImage: state.style.symbol)
            .font(.headline.weight(.heavy))
          Text(state.position)
            .font(.subheadline)
            .opacity(0.85)
          Text(state.next)
            .font(.caption)
            .opacity(0.75)
        }
        Spacer(minLength: 0)
        Countdown(state: state)
          .font(.system(size: 44, weight: .heavy).monospacedDigit())
          .multilineTextAlignment(.trailing)
          .frame(maxWidth: 130, alignment: .trailing)
      }
      if !state.isDone {
        PhaseProgress(state: state)
        Controls(state: state, tint: .white)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(16)
    .foregroundStyle(.white)
  }
}

/// Counts down by itself while running, so the app only has to update the
/// activity when the phase or the paused state changes.
private struct Countdown: View {
  let state: SpurtlyActivityAttributes.ContentState

  var body: some View {
    if state.isDone {
      Image(systemName: "checkmark")
    } else if let remaining = state.pausedRemaining {
      Text(Self.format(remaining))
    } else {
      Text(timerInterval: state.phaseStart...state.phaseEnd, countsDown: true)
    }
  }

  static func format(_ seconds: Double) -> String {
    let total = Int(seconds.rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}

private struct PhaseProgress: View {
  let state: SpurtlyActivityAttributes.ContentState

  var body: some View {
    Group {
      if let remaining = state.pausedRemaining {
        let length = state.phaseEnd.timeIntervalSince(state.phaseStart)
        ProgressView(value: length > 0 ? remaining / length : 0)
      } else {
        ProgressView(timerInterval: state.phaseStart...state.phaseEnd, countsDown: true) {
          EmptyView()
        } currentValueLabel: {
          EmptyView()
        }
      }
    }
    .tint(.white)
  }
}

private struct Controls: View {
  let state: SpurtlyActivityAttributes.ContentState
  let tint: Color

  var body: some View {
    HStack(spacing: 8) {
      Button(intent: TogglePauseIntent()) {
        Label(
          state.isPaused ? "Resume" : "Pause",
          systemImage: state.isPaused ? "play.fill" : "pause.fill"
        )
      }
      Button(intent: SkipPhaseIntent()) {
        Label("Skip", systemImage: "forward.end.fill")
      }
    }
    .font(.subheadline.weight(.semibold))
    .buttonStyle(.bordered)
    .buttonBorderShape(.capsule)
    .tint(tint)
  }
}

/// Colors and symbols per phase, matching the app.
private struct PhaseStyle {
  let background: Color
  let accent: Color
  let symbol: String
}

private extension SpurtlyActivityAttributes.ContentState {
  var isPaused: Bool { pausedRemaining != nil }
  var isDone: Bool { phase == "done" }

  var style: PhaseStyle {
    switch phase {
    case "warmup":
      PhaseStyle(background: Color(hex: 0xB86E00), accent: Color(hex: 0xFFB547), symbol: "figure.walk")
    case "work":
      PhaseStyle(background: Color(hex: 0xE0453A), accent: Color(hex: 0xFF6A4D), symbol: "flame.fill")
    case "rest":
      PhaseStyle(background: Color(hex: 0x0E8F80), accent: Color(hex: 0x2DD4BF), symbol: "figure.mind.and.body")
    case "roundRest":
      PhaseStyle(background: Color(hex: 0x0B6E7A), accent: Color(hex: 0x38BDF8), symbol: "hourglass")
    default:
      PhaseStyle(background: Color(hex: 0x4C55D6), accent: Color(hex: 0x8B92FF), symbol: "checkmark.circle.fill")
    }
  }
}

private extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}
