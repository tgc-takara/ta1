import SwiftUI
import WidgetKit

/// いま計測中の記録。ウィジェットの各エントリが共通で持つ。
struct ActiveRecording: Equatable {
    let category: ActivityCategory
    let startedAt: Date

    /// スナップショットから取り出す(両方揃っているときだけ有効)
    static func make(from snapshot: WidgetSnapshot?) -> ActiveRecording? {
        guard let snapshot,
              let category = snapshot.activeCategory,
              let startedAt = snapshot.activeStartedAt else { return nil }
        return ActiveRecording(category: category, startedAt: startedAt)
    }

    static let sample = ActiveRecording(
        category: .reading,
        startedAt: Date().addingTimeInterval(-754)
    )
}

/// カテゴリごとの「開始」ボタンの見た目。small(Button(intent:))と medium(Link)の両方から使う。
///
/// - 進行中のカテゴリ: カテゴリ色で塗りつぶし、白文字で「計測中」と経過時間を出す
/// - 進行中があるときの他カテゴリ: opacity 0.5 に落として「いま動いているのはこれ」を示す
struct StartButtonLabel: View {
    let category: ActivityCategory
    let active: ActiveRecording?
    /// 通常時のラベルを「読書を開始」にする(medium 用。small は幅が足りないのでカテゴリ名だけ)
    var showsStartSuffix = false
    var cornerRadius: CGFloat = 8

    private var isActive: Bool { active?.category == category }
    private var isDimmed: Bool { active != nil && !isActive }

    private var title: String {
        if isActive { return "\(category.label) 計測中" }
        return showsStartSuffix ? "\(category.label)を開始" : category.label
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: category.symbolName)
                .font(.caption)
            Text(title)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 2)
            if isActive, let startedAt = active?.startedAt {
                Text(startedAt, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 46, alignment: .trailing)
            }
        }
        .foregroundStyle(isActive ? Color.white : category.color)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(isActive ? AnyShapeStyle(category.color) : AnyShapeStyle(category.color.opacity(0.15)))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .opacity(isDimmed ? 0.5 : 1)
    }
}
