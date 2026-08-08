import Foundation

/// トレーニング入力中の種目 1 件分の編集用値型。
/// 保存時に ExerciseLog(記録)または MenuItem(メニュー雛形)へ変換する。
/// TextField バインディングを単純にするため cardio 系フィールドは非オプショナルで持ち、
/// 0 のときは「未入力」として nil に変換する。
struct ExerciseDraft: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var kind: ExerciseKind
    var sets: [SetRecord]
    var distanceKm: Double
    var durationMinutes: Int

    init(name: String, kind: ExerciseKind) {
        self.name = name
        self.kind = kind
        self.sets = kind == .strength ? [SetRecord(weightKg: 20, reps: 10)] : []
        self.distanceKm = 0
        self.durationMinutes = 0
    }

    init(log: ExerciseLog) {
        self.name = log.exerciseName
        self.kind = log.kind
        self.sets = log.sets
        self.distanceKm = log.distanceKm ?? 0
        self.durationMinutes = log.durationMinutes ?? 0
    }

    init(item: MenuItem) {
        self.name = item.exerciseName
        self.kind = item.kind
        self.sets = item.defaultSets
        self.distanceKm = item.defaultDistanceKm ?? 0
        self.durationMinutes = item.defaultDurationMinutes ?? 0
    }

    func makeLog(order: Int) -> ExerciseLog {
        let log = ExerciseLog(exerciseName: name, kind: kind, order: order)
        if kind == .strength {
            log.sets = sets
        } else {
            log.distanceKm = distanceKm > 0 ? distanceKm : nil
            log.durationMinutes = durationMinutes > 0 ? durationMinutes : nil
        }
        return log
    }

    func makeMenuItem() -> MenuItem {
        MenuItem(
            exerciseName: name,
            kindRaw: kind.rawValue,
            defaultSets: kind == .strength ? sets : [],
            defaultDistanceKm: kind == .cardio && distanceKm > 0 ? distanceKm : nil,
            defaultDurationMinutes: kind == .cardio && durationMinutes > 0 ? durationMinutes : nil
        )
    }
}
