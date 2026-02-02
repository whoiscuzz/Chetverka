import Foundation
import Combine

final class ResultsViewModel: ObservableObject {

    @Published var results: [SubjectResult] = []

    func calculate(from weeks: [Week]) {

        var subjectMarks: [String: [Int]] = [:]

        for week in weeks {
            for day in week.days {
                for lesson in day.lessons {
                    guard let mark = lesson.markInt else { continue }

                    subjectMarks[lesson.safeSubject, default: []]
                        .append(mark)
                }
            }
        }

        let computed = subjectMarks.map { subject, marks in
            let avg = Double(marks.reduce(0, +)) / Double(marks.count)

            return SubjectResult(
                subject: subject,
                average: avg,
                marksCount: marks.count
            )
        }
        .sorted { $0.average > $1.average }

        DispatchQueue.main.async {
            self.results = computed
        }
    }
}
