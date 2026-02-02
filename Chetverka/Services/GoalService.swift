import Foundation

/// Сервис для управления целями по предметам.
/// Использует UserDefaults для простоты хранения.
final class GoalService {

    private let userDefaults: UserDefaults
    private let goalsKey = "subject_goals"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Загружает все сохраненные цели.
    private func loadGoals() -> [String: Int] {
        return userDefaults.dictionary(forKey: goalsKey) as? [String: Int] ?? [:]
    }

    /// Сохраняет все цели.
    private func saveGoals(_ goals: [String: Int]) {
        userDefaults.set(goals, forKey: goalsKey)
    }

    /// Получает цель для конкретного предмета.
    /// - Parameter subject: Название предмета (будет приведено к нижнему регистру).
    /// - Returns: Целевая оценка или `nil`, если цель не установлена.
    func getGoal(for subject: String) -> Int? {
        let goals = loadGoals()
        return goals[subject.lowercased()]
    }

    /// Устанавливает цель для конкретного предмета.
    /// - Parameters:
    ///   - goal: Целевая оценка. Если передать `nil`, цель будет удалена.
    ///   - subject: Название предмета (будет приведено к нижнему регистру).
    func setGoal(_ goal: Int?, for subject: String) {
        var goals = loadGoals()
        goals[subject.lowercased()] = goal
        saveGoals(goals)
    }
}
