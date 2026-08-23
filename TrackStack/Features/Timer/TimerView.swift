import SwiftUI
import UIKit
import AudioToolbox

/// 計測中のタイマーを全画面表示するビュー。
/// 経過時間は TimelineView で毎秒更新し、実際の計算は
/// ActiveTimer.elapsedSeconds(now:state:) の「開始時刻との差分」方式に委ねる。
/// ポモドーロモードでは Pomodoro の局面計算に切り替わり、記録時間は作業局面の合計だけになる。
struct TimerView: View {
    var activeTimer: ActiveTimer
    /// 「終了して記録」が押されたときに、記録フォームへ渡す値を親へ通知する。
    var onFinish: (ActivityCategory, Date, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscardConfirm = false

    /// モード切替を許す経過秒の上限。これを過ぎると誤操作で計測を捨ててしまうため固定する
    private static let modeSwitchLimitSeconds = 60

    /// 局面の切り替わりを知らせる音(インターバルタイマーの終了音と同じ)
    private static let phaseChangeSoundID: SystemSoundID = 1005

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let state = activeTimer.state, let category = activeTimer.category {
            let elapsed = ActiveTimer.elapsedSeconds(now: now, state: state)

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Label(category.label, systemImage: category.symbolName)
                        .font(.title2.bold())
                        .foregroundStyle(category.color)

                    modePicker(canSwitch: elapsed <= Self.modeSwitchLimitSeconds)

                    if let pomodoro = activeTimer.pomodoroState {
                        pomodoroDisplay(now: now, pomodoro: pomodoro, category: category)
                    } else {
                        stopwatchDisplay(elapsed: elapsed)
                    }
                }

                Spacer()

                VStack(spacing: 16) {
                    if activeTimer.isPomodoro {
                        Button {
                            activeTimer.skipPhase()
                        } label: {
                            Label("スキップ", systemImage: "forward.end.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Button {
                            if activeTimer.isPaused {
                                activeTimer.resume()
                            } else {
                                activeTimer.pause()
                            }
                        } label: {
                            Label(
                                activeTimer.isPaused ? "再開" : "一時停止",
                                systemImage: activeTimer.isPaused ? "play.fill" : "pause.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button {
                        finish()
                    } label: {
                        Label("終了して記録", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        showingDiscardConfirm = true
                    } label: {
                        Text("破棄")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper.ignoresSafeArea())
            // 局面の追いつき処理は body の描画中ではなく、時刻が進んだタイミングで行う
            .onChange(of: now) { _, newValue in
                if activeTimer.tick(now: newValue) {
                    notifyPhaseChange()
                }
            }
            .confirmationDialog(
                "このタイマーを破棄しますか?",
                isPresented: $showingDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("破棄する", role: .destructive) {
                    activeTimer.cancel()
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("計測した時間は記録されません")
            }
        } else {
            // state が取れない(すでに終了/破棄済みなど)場合は自動的に閉じる
            Color.clear
                .onAppear { dismiss() }
        }
    }

    // MARK: - モード切替

    @ViewBuilder
    private func modePicker(canSwitch: Bool) -> some View {
        VStack(spacing: 4) {
            Picker("モード", selection: modeBinding) {
                Text("ストップウォッチ").tag(false)
                Text("ポモドーロ").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(!canSwitch)

            if !canSwitch {
                Text("開始から1分を過ぎると切り替えられません")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var modeBinding: Binding<Bool> {
        Binding(
            get: { activeTimer.isPomodoro },
            set: { toPomodoro in
                guard toPomodoro != activeTimer.isPomodoro else { return }
                if toPomodoro {
                    PomodoroNotifier.requestAuthorizationIfNeeded()
                }
                activeTimer.switchMode(toPomodoro: toPomodoro)
            }
        )
    }

    // MARK: - 表示

    private func stopwatchDisplay(elapsed: Int) -> some View {
        VStack(spacing: 12) {
            Text(Formatters.elapsedClock(seconds: elapsed))
                .font(.mincho(size: 64))
                .monospacedDigit()
                .contentTransition(.numericText())

            if activeTimer.isPaused {
                Text("一時停止中")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
            }
        }
    }

    private func pomodoroDisplay(now: Date, pomodoro: PomodoroState, category: ActivityCategory) -> some View {
        let remaining = Pomodoro.remainingSeconds(now: now, state: pomodoro)
        let workSeconds = Pomodoro.workSeconds(now: now, state: pomodoro)
        let cycle = pomodoro.completedWorkCycles + (pomodoro.phase == .work ? 1 : 0)

        return VStack(spacing: 8) {
            Text(pomodoro.phase.label)
                .font(.title3.bold())
                .foregroundStyle(pomodoro.phase == .work ? category.color : Theme.ai)

            Text(Formatters.countdownClock(seconds: remaining))
                .font(.mincho(size: 64))
                .monospacedDigit()
                .contentTransition(.numericText())

            VStack(spacing: 2) {
                Text("サイクル \(cycle) / \(pomodoro.settings.cyclesBeforeLongBreak)")
                Text("作業 累計 \(Formatters.duration(minutes: workSeconds / 60))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    /// 局面が切り替わったことを音と振動で知らせる(フォアグラウンド用)
    private func notifyPhaseChange() {
        AudioServicesPlaySystemSound(Self.phaseChangeSoundID)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func finish() {
        guard let result = activeTimer.finish() else {
            dismiss()
            return
        }
        onFinish(result.category, result.startedAt, result.durationMinutes)
        dismiss()
    }
}
