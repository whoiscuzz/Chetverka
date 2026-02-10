import Foundation

struct QuarterGradesTable: Codable, Equatable {
    let columns: [String]
    let rows: [QuarterGradesRow]
}

struct QuarterGradesRow: Identifiable, Codable, Equatable {
    let id = UUID()
    let subject: String
    let grades: [String?]

    enum CodingKeys: String, CodingKey {
        case subject, grades
    }
}

