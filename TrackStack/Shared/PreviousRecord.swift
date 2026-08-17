import Foundation
import SwiftData

extension ExerciseLog {
    /// 「60kg×10, 60kg×8(片手)」/ 有酸素は「3.0km 20分」形式の要約。
    /// 前回記録の表示と終了後のまとめ画面で共用する。
    var summaryDetail: String {
        if bodyPart.isCardio {
            var parts: [String] = []
            if let distance = distanceKm, distance > 0 {
                parts.append(String(format: "%.1fkm", distance))
            }
            if let minutes = durationMinutes, minutes > 0 {
                parts.append("\(minutes)分")
            }
            return parts.joined(separator: " ")
        }
        return sets.map { set in
            let weight = set.weightKg == set.weightKg.rounded()
                ? String(Int(set.weightKg))
                : String(set.weightKg)
            return "\(weight)kg×\(set.reps)\(set.isSingleArm ? "(片手)" : "")"
        }
        .joined(separator: ", ")
    }
}

/// 種目ごとの「前回の記録」を引くための検索。
/// 記録フォームで種目を並べたときに、前回どれくらい挙げたかを添えるために使う。
enum PreviousRecord {
    struct Entry {
        let date: Date
        let detail: String
    }

    /// 直近のトレーニングセッションから、種目名ごとの最新1件を返す。
    /// - Parameters:
    ///   - names: 探したい種目名
    ///   - excluding: 編集中のセッションID(自分自身は「前回」に含めない)
    ///   - limit: さかのぼるセッション数の上限(古い記録まで舐めないための打ち切り)
    static func latest(
        for names: [String],
        excluding excludedSessionID: UUID?,
        in context: ModelContext,
        limit: Int = 60
    ) -> [String: Entry] {
        let wanted = Set(names)
        guard !wanted.isEmpty else { return [:] }

        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.categoryRaw == "training" },
            sortBy: [SortDescriptor(\Session.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        guard let sessions = try? context.fetch(descriptor) else { return [:] }

        var result: [String: Entry] = [:]
        for session in sessions where session.id != excludedSessionID {
            for log in session.exerciseLogs
            where wanted.contains(log.exerciseName) && result[log.exerciseName] == nil {
                let detail = log.summaryDetail
                guard !detail.isEmpty else { continue }
                result[log.exerciseName] = Entry(date: session.startedAt, detail: detail)
            }
            // 全種目そろったら打ち切る
            if result.count == wanted.count { break }
        }
        return result
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    /// 「前回 8/11: 60kg×10, 60kg×8」
    static func label(_ entry: Entry) -> String {
        "前回 \(dateFormatter.string(from: entry.date)): \(entry.detail)"
    }
}
