import Foundation
import Combine

final class SubjectSimulationViewModel: ObservableObject {

    @Published private(set) var simulation: SubjectSimulation
    @Published var targetGrade: Int = 0 {
        didSet {
            goalService.setGoal(targetGrade > 0 ? targetGrade : nil, for: simulation.subject)
            updateGoalSummary()
        }
    }
    @Published private(set) var goalSummary: String?

    private let goalService = GoalService()

    init(subject: String, marks: [Int]) {
        self.simulation = SubjectSimulation(
            subject: subject,
            originalMarks: marks
        )
        self.targetGrade = goalService.getGoal(for: subject) ?? 0
        updateGoalSummary()
    }

    func add(mark: Int) {
        simulation.addedMarks.append(mark)
        updateGoalSummary() // Пересчитываем при добавлении
        objectWillChange.send()
    }

    func removeLast() {
        guard !simulation.addedMarks.isEmpty else { return }
        simulation.addedMarks.removeLast()
        updateGoalSummary() // Пересчитываем при удалении
        objectWillChange.send()
    }

    func removeAddedMark(at index: Int) {
        guard simulation.addedMarks.indices.contains(index) else { return }
        simulation.addedMarks.remove(at: index)
        updateGoalSummary()
        objectWillChange.send()
    }

    func clearAddedMarks() {
        guard !simulation.addedMarks.isEmpty else { return }
        simulation.addedMarks.removeAll()
        updateGoalSummary()
        objectWillChange.send()
    }

    /// Рассчитывает, сколько оценок нужно для достижения цели
    private func updateGoalSummary() {
        // Используем roundedAverage для проверки
        guard targetGrade > 0, simulation.roundedAverage < targetGrade else {
            self.goalSummary = nil
            return
        }

        var tempMarks = simulation.allMarks
        var marksToAdd = 0

        // Пытаемся достичь цели, добавляя десятки
        for i in 1...100 { // Ограничимся 100 итерациями на всякий случай
            tempMarks.append(10)
            marksToAdd = i
            
            let totalSum = tempMarks.reduce(0, +)
            let newAverage = Double(totalSum) / Double(tempMarks.count)

            // Округляем новый средний балл перед сравнением
            if Int(newAverage.rounded()) >= targetGrade {
                let markString = marksToAdd == 1 ? "десятка" : (marksToAdd > 1 && marksToAdd < 5 ? "десятки" : "десяток")
                self.goalSummary = "Нужно еще \(marksToAdd) \(markString)"
                return
            }
        }
        
        self.goalSummary = "Цель кажется недостижимой"
    }
}
