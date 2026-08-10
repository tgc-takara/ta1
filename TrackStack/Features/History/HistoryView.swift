import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    @State private var filter: ActivityCategory?
    @State private var editingSession: Session?
    @State private var viewMode: HistoryViewMode = .list

    private enum HistoryViewMode: String, CaseIterable, Identifiable {
        case list
        case calendar

        var id: String { rawValue }

        var label: String {
            switch self {
            case .list: "リスト"
            case .calendar: "カレンダー"
            }
        }

        var symbolName: String {
            switch self {
            case .list: "list.bullet"
            case .calendar: "calendar"
            }
        }
    }

    private var filtered: [Session] {
        guard let filter else { return sessions }
        return sessions.filter { $0.category == filter }
    }

    /// 日付ごとにグルーピング(新しい日が先頭)
    private var grouped: [(day: Date, sessions: [Session])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.startedAt) }
        return dict.keys.sorted(by: >).map { (day: $0, sessions: dict[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewMode {
                case .list:
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "まだ記録がありません",
                            systemImage: "tray",
                            description: Text("ホームの + ボタンから最初の記録を追加しましょう")
                        )
                    } else {
                        List {
                            ForEach(grouped, id: \.day) { group in
                                Section {
                                    ForEach(group.sessions) { session in
                                        SessionRowView(session: session)
                                            .contentShape(Rectangle())
                                            .onTapGesture { editingSession = session }
                                    }
                                    .onDelete { offsets in
                                        delete(offsets, in: group.sessions)
                                    }
                                } header: {
                                    HStack {
                                        Text(Formatters.dayHeader(group.day))
                                        Spacer()
                                        Text(Formatters.duration(
                                            minutes: group.sessions.reduce(0) { $0 + $1.durationMinutes }
                                        ))
                                    }
                                }
                            }
                        }
                    }
                case .calendar:
                    ScrollView {
                        MonthCalendarView(sessions: filtered)
                    }
                }
            }
            .navigationTitle("記録")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("表示切替", selection: $viewMode) {
                        ForEach(HistoryViewMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.symbolName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .sheet(item: $editingSession) { session in
                SessionFormView(sessionToEdit: session)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button("すべて") { filter = nil }
            ForEach(ActivityCategory.allCases) { category in
                Button {
                    filter = category
                } label: {
                    Label(category.label, systemImage: category.symbolName)
                }
            }
        } label: {
            Image(systemName: filter == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func delete(_ offsets: IndexSet, in sessions: [Session]) {
        for index in offsets {
            context.delete(sessions[index])
        }
    }
}
