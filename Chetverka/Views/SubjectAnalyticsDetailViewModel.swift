import Foundation
import Combine

// MARK: - Модели данных для графиков

/// Точка данных для графика динамики среднего балла
struct AverageDataPoint: Identifiable {
    let id = UUID()
    let lessonNumber: Int // Номер урока по порядку (1-й, 2-й, ...)
    let average: Double
}

/// Точка данных для гистограммы распределения оценок
struct GradeCount: Identifiable {
    var id: String { mark }
    let mark: String // Оценка, например "10"
    let count: Int
}


// MARK: - ViewModel

final class SubjectAnalyticsDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dynamicsData: [AverageDataPoint] = []
    @Published var distributionData: [GradeCount] = []
    @Published var subjectName: String
    
    // MARK: - Init
    
    /// - Parameters:
    ///   - subjectName: Название предмета.
    ///   - lessons: Все уроки по этому предмету за период.
    init(subjectName: String, lessons: [Lesson]) {
        self.subjectName = subjectName
        
        // Для расчетов нам нужны только уроки с оценками,
        // отсортированные хронологически (предполагаем, что исходный массив уже такой)
        let lessonsWithMarks = lessons.filter { $0.markInt != nil }
        
        calculateDynamics(from: lessonsWithMarks)
        calculateDistribution(from: lessonsWithMarks)
    }
    
    // MARK: - Private Calculation Methods
    
    /// Рассчитывает данные для графика динамики среднего балла
    private func calculateDynamics(from lessons: [Lesson]) {
        var runningTotal = 0
        var dataPoints: [AverageDataPoint] = []
        
        for (index, lesson) in lessons.enumerated() {
            guard let mark = lesson.markInt else { continue }
            
            runningTotal += mark
            let currentAverage = Double(runningTotal) / Double(index + 1)
            
            dataPoints.append(
                AverageDataPoint(lessonNumber: index + 1, average: currentAverage)
            )
        }
        
        self.dynamicsData = dataPoints
    }
    
    /// Рассчитывает данные для гистограммы распределения оценок
    private func calculateDistribution(from lessons: [Lesson]) {
        // Считаем количество каждой оценки
        let counts = lessons.compactMap { $0.mark }.reduce(into: [:]) { counts, mark in
            counts[mark, default: 0] += 1
        }
        
        // Преобразуем в массив GradeCount и сортируем
        self.distributionData = counts.map { mark, count in
            GradeCount(mark: mark, count: count)
        }
        .sorted { (item1, item2) -> Bool in
            // Сортируем по оценке, чтобы на графике было "10, 9, 8...", а не вразнобой
            (Int(item1.mark) ?? 0) > (Int(item2.mark) ?? 0)
        }
    }
}
