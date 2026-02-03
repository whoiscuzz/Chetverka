import SwiftUI
import Combine

final class AnalyticsViewModel: ObservableObject {

    @Published var average: Double = 0
    @Published var totalMarks: Int = 0
    @Published var bestSubjects: [(String, Double)] = []
    @Published var weakSubjects: [(String, Double)] = []
    @Published var pieData: [SubjectSlice] = []

    func calculate(from weeks: [Week]) {

        DispatchQueue.global(qos: .userInitiated).async {

            var subjectMarks: [String: [Int]] = [:]
            var allMarks: [Int] = []

            for week in weeks {
                for day in week.days {
                    for lesson in day.lessons {
                        guard let mark = lesson.markInt else { continue }

                        subjectMarks[lesson.safeSubject, default: []].append(mark)
                        allMarks.append(mark)
                    }
                }
            }

            let total = allMarks.reduce(0, +)
            let count = allMarks.count
            let average = count > 0 ? Double(total) / Double(count) : 0

            // --- Расчет средних по предметам ---
            let subjectAverages = subjectMarks
                .map { key, values in
                    (
                        key.capitalized,
                        Double(values.reduce(0, +)) / Double(values.count)
                    )
                }
            

            let sortedByAverage = subjectAverages.sorted { $0.1 > $1.1 }
            let best = Array(sortedByAverage.prefix(5))
            let weak = Array(subjectAverages.filter { $0.1 < 6.5 }.sorted { $0.1 < $1.1 }.prefix(5))


            let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow]


            let sortedByCount = subjectMarks.sorted { $0.value.count > $1.value.count }


            let topSubjects = sortedByCount.prefix(colors.count)


            let slices = topSubjects.enumerated().map { index, item in
                SubjectSlice(
                    subject: item.key.capitalized,
                    value: item.value.count,
                    color: colors[index % colors.count]
                )
            }

            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    self.average = average
                    self.totalMarks = count
                    self.bestSubjects = best
                    self.weakSubjects = weak
                    self.pieData = slices
                }
            }
        }
    }
}
