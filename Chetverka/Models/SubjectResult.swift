import Foundation

struct SubjectResult: Identifiable {
    let id = UUID()
    let subject: String
    let average: Double
    let marksCount: Int

    var roundedAverage: Int {
        Int(round(average))
    }

    var status: Status {
        switch average {
        case 0:
            return .noData
        case 1..<6:
            return .bad
        case 6..<8:
            return .warning
        default:
            return .good
        }
    }

    enum Status {
        case noData
        case bad
        case warning
        case good
    }
}
