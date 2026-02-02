import Foundation

struct SubjectSimulation {
    let subject: String
    let originalMarks: [Int]
    var addedMarks: [Int] = []

    var allMarks: [Int] {
        originalMarks + addedMarks
    }

    var average: Double {
        guard !allMarks.isEmpty else { return 0 }
        return Double(allMarks.reduce(0, +)) / Double(allMarks.count)
    }

    var roundedAverage: Int {
        Int(average.rounded())
    }
}
