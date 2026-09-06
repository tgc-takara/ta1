import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Entry

struct StartEntry: TimelineEntry {
    let date: Date
    let active: ActiveRecording?

    static let placeholder = StartEntry(date: Date(), active: nil)
    static let running = StartEntry(date: Date(), active: .sample)
}

// MARK: - Provider

struct StartProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StartEntry) -> Void) {
        completion(
            context.isPreview
                ? .placeholder
                : StartEntry(date: Date(), active: .make(from: WidgetSnapshot.load()))
        )
    }

    /// 経過時間は Text(_:style:.timer) が自前で進むので、定期更新は保険程度でよい。
    /// 計測の開始・終了時はアプリ側が reloadAllTimelines() を呼ぶ。
    func getTimeline(in context: Context, completion: @escaping (Timeline<StartEntry>) -> Void) {
        let now = Date()
        let entry = StartEntry(date: now, active: .make(from: WidgetSnapshot.load()))
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

// MARK: - View

struct HitotsumiStartWidgetView: View {
    let entry: StartEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                Text("ひとつみ")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer(minLength: 0)
            }

            VStack(spacing: 4) {
                ForEach(ActivityCategory.allCases) { category in
                    Button(intent: StartRecordingIntent(category: category)) {
                        StartButtonLabel(category: category, active: entry.active)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .containerBackground(for: .widget) { Theme.paper }
    }
}

// MARK: - Widget

struct HitotsumiStartWidget: Widget {
    let kind = "HitotsumiStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StartProvider()) { entry in
            HitotsumiStartWidgetView(entry: entry)
        }
        .configurationDisplayName("記録開始")
        .description("ロゴと3つの開始ボタン")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview("start", as: .systemSmall) {
    HitotsumiStartWidget()
} timeline: {
    StartEntry.placeholder
    StartEntry.running
}
