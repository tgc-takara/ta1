import SwiftUI
import WidgetKit

// MARK: - Entry

struct HitotsumiEntry: TimelineEntry {
    let date: Date
    let totalMinutes: Int
    let minutesByCategory: [ActivityCategory: Int]
    let streak: Int

    /// プレースホルダ(初回配置時・ギャラリー表示用)のダミー値
    static let placeholder = HitotsumiEntry(
        date: Date(),
        totalMinutes: 75,
        minutesByCategory: [.reading: 30, .training: 20, .study: 25],
        streak: 5
    )

    static let empty = HitotsumiEntry(
        date: Date(),
        totalMinutes: 0,
        minutesByCategory: [:],
        streak: 0
    )

    /// App Group のスナップショットからエントリを作る。
    /// スナップショットが今日のものでなければ日付が変わったということなので 0 表示にする。
    /// ストリークだけは「昨日までの連続」も今日いっぱいは有効なので、前日分なら引き継ぐ。
    static func make(
        from snapshot: WidgetSnapshot?,
        now: Date,
        calendar: Calendar = .current
    ) -> HitotsumiEntry {
        guard let snapshot else {
            return HitotsumiEntry(date: now, totalMinutes: 0, minutesByCategory: [:], streak: 0)
        }
        let byCategory = snapshot.minutesByCategory.reduce(into: [ActivityCategory: Int]()) { result, pair in
            guard let category = ActivityCategory(rawValue: pair.key) else { return }
            result[category] = pair.value
        }
        if calendar.isDate(snapshot.date, inSameDayAs: now) {
            return HitotsumiEntry(
                date: now,
                totalMinutes: snapshot.totalMinutes,
                minutesByCategory: byCategory,
                streak: snapshot.streak
            )
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        let streakStillValid = yesterday.map { calendar.isDate(snapshot.date, inSameDayAs: $0) } ?? false
        return HitotsumiEntry(
            date: now,
            totalMinutes: 0,
            minutesByCategory: [:],
            streak: streakStillValid ? snapshot.streak : 0
        )
    }
}

// MARK: - Provider

struct HitotsumiProvider: TimelineProvider {
    func placeholder(in context: Context) -> HitotsumiEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (HitotsumiEntry) -> Void) {
        completion(context.isPreview ? .placeholder : .make(from: WidgetSnapshot.load(), now: Date()))
    }

    /// 「今」と「次の午前0時(日付が変わって 0 に戻る)」の2エントリ。
    /// 記録が増えたときはアプリ側が reloadAllTimelines() を呼ぶので、こちらは日付の切り替えだけ担う。
    func getTimeline(in context: Context, completion: @escaping (Timeline<HitotsumiEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let snapshot = WidgetSnapshot.load()
        var entries = [HitotsumiEntry.make(from: snapshot, now: now, calendar: calendar)]

        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            entries.append(.make(from: snapshot, now: midnight, calendar: calendar))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

/// 今日の合計・カテゴリ内訳・ストリークを縦に積む共通部分(small はこれだけ、medium は左半分)
private struct SummaryColumn: View {
    let entry: HitotsumiEntry
    /// 合計時間の文字サイズ(medium では少し小さくする)
    var totalFontSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text("ひとつみ")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer(minLength: 0)
                if entry.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                        Text("\(entry.streak)日")
                            .monospacedDigit()
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.ai)
                }
            }

            Spacer(minLength: 0)

            Text(Formatters.duration(minutes: entry.totalMinutes))
                .font(.mincho(size: totalFontSize))
                .fontDesign(.serif)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ForEach(ActivityCategory.allCases) { category in
                    HStack(spacing: 3) {
                        Rectangle()
                            .fill(category.color)
                            .frame(width: 2.5, height: 12)
                        Image(systemName: category.symbolName)
                        Text("\(entry.minutesByCategory[category] ?? 0)")
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// medium の右半分。カテゴリごとの「開始」ボタン。
private struct StartButtonsColumn: View {
    var body: some View {
        VStack(spacing: 6) {
            ForEach(ActivityCategory.allCases) { category in
                Link(destination: DeepLinkURL.start(category)) {
                    HStack(spacing: 5) {
                        Image(systemName: category.symbolName)
                            .font(.caption)
                        Text("\(category.label)を開始")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(category.color)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(category.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// ウィジェットから開く URL。アプリ側の DeepLink.parse と対になる。
enum DeepLinkURL {
    static func start(_ category: ActivityCategory) -> URL {
        URL(string: "hitotsumi://start?category=\(category.rawValue)")!
    }

    static let record = URL(string: "hitotsumi://record")!
}

struct HitotsumiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HitotsumiEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(spacing: 12) {
                    SummaryColumn(entry: entry, totalFontSize: 26)
                    StartButtonsColumn()
                        .frame(width: 132)
                }
            } else {
                SummaryColumn(entry: entry)
            }
        }
        .containerBackground(for: .widget) { Theme.paper }
        // ボタン以外(small 全体 / medium の左半分)をタップしたら記録追加フォームを開く
        .widgetURL(DeepLinkURL.record)
    }
}

// MARK: - Widget

struct HitotsumiWidget: Widget {
    let kind = "HitotsumiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HitotsumiProvider()) { entry in
            HitotsumiWidgetView(entry: entry)
        }
        .configurationDisplayName("ひとつみ")
        .description("今日の積み上げと記録開始")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TrackStackWidgetBundle: WidgetBundle {
    var body: some Widget {
        HitotsumiWidget()
    }
}

// MARK: - Preview

#Preview("small", as: .systemSmall) {
    HitotsumiWidget()
} timeline: {
    HitotsumiEntry.placeholder
    HitotsumiEntry.empty
}

#Preview("medium", as: .systemMedium) {
    HitotsumiWidget()
} timeline: {
    HitotsumiEntry.placeholder
    HitotsumiEntry.empty
}
