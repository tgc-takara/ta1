import SwiftUI

/// 月表示のカレンダー。日付をタップするとその日のセッション一覧を下に表示する。
struct MonthCalendarView: View {
    let sessions: [Session]

    private let calendar = Calendar.current

    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay: Date? = Calendar.current.startOfDay(for: Date())
    @State private var editingSession: Session?

    private var minutesByDay: [Date: Int] {
        StatsCalculator.minutesByDay(sessions, in: displayedMonth, calendar: calendar)
    }

    private var dominantCategoryByDay: [Date: ActivityCategory] {
        StatsCalculator.dominantCategoryByDay(sessions, in: displayedMonth, calendar: calendar)
    }

    /// 月グリッド用の日付一覧。前月・翌月の日で埋めて週単位を揃える。
    private var gridDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth)
        else { return [] }

        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// 週の開始曜日(calendar.firstWeekday)に合わせた曜日ラベル
    private var weekdayLabels: [String] {
        let labels = ["日", "月", "火", "水", "木", "金", "土"]
        let offset = calendar.firstWeekday - 1
        return (0..<7).map { labels[(offset + $0) % 7] }
    }

    private var selectedDaySessions: [Session] {
        guard let selectedDay else { return [] }
        return StatsCalculator.sessions(sessions, on: selectedDay, calendar: calendar)
            .sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        VStack(spacing: 16) {
            monthHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(gridDays, id: \.self) { day in
                    dayCell(for: day)
                }
            }
            .padding(.horizontal)

            Divider()

            selectedDaySection
        }
        .padding(.vertical)
        .sheet(item: $editingSession) { session in
            SessionFormView(sessionToEdit: session)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            Spacer()
            Text(monthTitle)
                .font(.headline)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: displayedMonth)
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = newMonth
        // 表示月と選択日がずれたままにならないよう、月外の選択は解除する
        // (移動先が今月なら今日を選び直す)
        if let selectedDay, !calendar.isDate(selectedDay, equalTo: newMonth, toGranularity: .month) {
            let today = calendar.startOfDay(for: Date())
            self.selectedDay = calendar.isDate(today, equalTo: newMonth, toGranularity: .month) ? today : nil
        }
    }

    private func dayCell(for day: Date) -> some View {
        let isCurrentMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let totalMinutes = minutesByDay[day] ?? 0
        let dominantCategory = dominantCategoryByDay[day]

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline)
                    .foregroundStyle(isCurrentMonth ? Color.primary : Color.secondary.opacity(0.5))
                Circle()
                    .fill(dominantCategory?.color.opacity(dotOpacity(for: totalMinutes)) ?? .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Theme.ai : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    /// 合計分に応じたドットの不透明度(30分未満0.4 / 60分未満0.7 / それ以上1.0)
    private func dotOpacity(for minutes: Int) -> Double {
        switch minutes {
        case ..<30: return 0.4
        case ..<60: return 0.7
        default: return 1.0
        }
    }

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedDay {
                Text(Formatters.dayHeader(selectedDay))
                    .font(.subheadline.bold())
                    .padding(.horizontal)
            }

            if selectedDay == nil {
                Text("日付をタップすると、その日の記録を表示します")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else if selectedDaySessions.isEmpty {
                Text("記録がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(selectedDaySessions) { session in
                    Button {
                        editingSession = session
                    } label: {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }
}
