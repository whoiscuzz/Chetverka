import Foundation
import Combine

final class ResultsViewModel: ObservableObject {

    @Published var results: [SubjectResult] = []
    @Published var quarterGrades: QuarterGradesTable?
    @Published var isQuarterGradesLoading = false
    @Published var quarterGradesError: String?

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

    @MainActor
    func loadQuarterGrades(sessionid: String?, pupilid: String?) async {
        guard let pupilid, !pupilid.isEmpty else {
            quarterGradesError = "Не найден pupilid. Выполни вход заново."
            quarterGrades = nil
            return
        }

        isQuarterGradesLoading = true
        quarterGradesError = nil
        defer { isQuarterGradesLoading = false }

        do {
            let table = try await SchoolsByWebClient.shared.fetchQuarterGrades(pupilid: pupilid, sessionid: sessionid)
            quarterGrades = table
            if table.rows.isEmpty {
                quarterGradesError = "Не удалось найти таблицу оценок на странице итогов."
            }
        } catch {
            quarterGrades = nil
            quarterGradesError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
