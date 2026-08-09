import SwiftUI
import UIKit

/// インターバルタイマーのプリセット秒数(UserDefaults 保存)。
/// タイマー本体(IntervalTimerSection)と設定画面(IntervalPresetSettingsView)で共有する。
enum IntervalTimerPresets {
    static let userDefaultsKey = "intervalTimerPresets"
    /// 既定値。保存値が未設定/空のときに使う
    static let defaultValues: [Int] = [30, 60, 90, 120, 180]

    /// 保存済みプリセットを昇順で読み込む。未設定または空配列なら既定値を返す。
    static func load() -> [Int] {
        guard let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [Int], !saved.isEmpty else {
            return defaultValues
        }
        return saved.sorted()
    }

    static func save(_ presets: [Int]) {
        UserDefaults.standard.set(presets, forKey: userDefaultsKey)
    }
}

/// トレーニング記録フォームに埋め込む、セット間休憩用のカウントダウンタイマー。
/// ロジックは ActiveTimer と同じ「時刻差分」方式: 開始時に endDate(終了予定時刻)を
/// 保持し、残り秒 = endDate - now を毎秒(TimelineView)再計算して表示する。
/// フォーム保存には関与しない(記録には残さない、あくまで補助UI)。
struct IntervalTimerSection: View {
    private static let userDefaultsKey = "intervalTimerSeconds"

    /// プリセット秒数一覧(設定画面で編集可能。表示直前に再読み込みする)
    @State private var presets: [Int]
    /// 選択中のインターバル秒数(既定 90 秒。前回値を UserDefaults から復元)
    @State private var selectedSeconds: Int
    /// カウントダウンの終了予定時刻。nil なら停止中
    @State private var endDate: Date?
    /// 終了ハプティクスを一度だけ発火させるためのフラグ
    @State private var hasFiredHaptic = false

    init() {
        let presets = IntervalTimerPresets.load()
        let saved = UserDefaults.standard.integer(forKey: Self.userDefaultsKey)
        _presets = State(initialValue: presets)
        _selectedSeconds = State(initialValue: Self.defaultSelection(presets: presets, preferring: saved))
    }

    var body: some View {
        Section("インターバルタイマー") {
            if let endDate {
                runningContent(endDate: endDate)
            } else {
                idleContent
            }
        }
        .onAppear {
            // 設定画面でプリセットが変更されている可能性があるため、表示のたびに再読み込みする
            presets = IntervalTimerPresets.load()
            if !presets.contains(selectedSeconds) {
                selectedSeconds = Self.defaultSelection(presets: presets, preferring: selectedSeconds)
            }
        }
    }

    /// プリセット一覧の中から選択初期値を決める。saved があればそれを、なければ 90 秒に近いものを優先する
    private static func defaultSelection(presets: [Int], preferring saved: Int) -> Int {
        if presets.contains(saved) { return saved }
        if presets.contains(90) { return 90 }
        return presets.first ?? 90
    }

    // MARK: - 停止中(プリセット選択 + 開始)

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { seconds in
                    presetChip(seconds: seconds)
                }
            }

            Button {
                start(seconds: selectedSeconds)
            } label: {
                Label("開始", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }

    private func presetChip(seconds: Int) -> some View {
        let isSelected = selectedSeconds == seconds
        return Button {
            selectedSeconds = seconds
            UserDefaults.standard.set(seconds, forKey: Self.userDefaultsKey)
        } label: {
            Text(Formatters.presetLabel(seconds: seconds))
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - カウント中 / 終了

    @ViewBuilder
    private func runningContent(endDate: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Self.remainingSeconds(now: context.date, endDate: endDate)

            if remaining <= 0 {
                finishedContent
                    .onAppear { handleFinished() }
            } else {
                VStack(spacing: 12) {
                    Text(Formatters.countdownClock(seconds: remaining))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())

                    HStack(spacing: 12) {
                        Button {
                            self.endDate = endDate.addingTimeInterval(30)
                        } label: {
                            Label("+30秒", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            stop()
                        } label: {
                            Text("停止")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var finishedContent: some View {
        VStack(spacing: 12) {
            Text("インターバル終了!")
                .font(.title3.bold())
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Button {
                    start(seconds: selectedSeconds)
                } label: {
                    Label("もう一度", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    stop()
                } label: {
                    Text("閉じる")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func start(seconds: Int) {
        selectedSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: Self.userDefaultsKey)
        hasFiredHaptic = false
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
    }

    private func stop() {
        endDate = nil
        hasFiredHaptic = false
    }

    private func handleFinished() {
        guard !hasFiredHaptic else { return }
        hasFiredHaptic = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - 純粋関数(テスト対象)

    /// 現在時刻と終了予定時刻から残り秒を計算する。切り上げ、負値(過ぎている)なら 0。
    static func remainingSeconds(now: Date, endDate: Date) -> Int {
        let diff = endDate.timeIntervalSince(now)
        if diff <= 0 { return 0 }
        return Int(diff.rounded(.up))
    }
}
