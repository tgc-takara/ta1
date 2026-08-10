import SwiftUI

/// 計測中のタイマーを全画面表示するビュー。
/// 経過時間は TimelineView で毎秒更新し、実際の計算は
/// ActiveTimer.elapsedSeconds(now:state:) の「開始時刻との差分」方式に委ねる。
struct TimerView: View {
    var activeTimer: ActiveTimer
    /// 「終了して記録」が押されたときに、記録フォームへ渡す値を親へ通知する。
    var onFinish: (ActivityCategory, Date, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDiscardConfirm = false

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

                Spacer()

                VStack(spacing: 16) {
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

    private func finish() {
        guard let result = activeTimer.finish() else {
            dismiss()
            return
        }
        onFinish(result.category, result.startedAt, result.durationMinutes)
        dismiss()
    }
}
