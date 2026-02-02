import Foundation

// MARK: - Root

struct DiaryResponse: Codable {
    let weeks: [Week]
}

struct Week: Identifiable, Codable, Equatable {
    let id = UUID()

    let monday: String
    let days: [Day]
    
    enum CodingKeys: String, CodingKey {
        case monday, days
    }

    /// Дата понедельника как Date
    var startDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.date(from: monday)
    }

    /// КРАСИВОЕ НАЗВАНИЕ НЕДЕЛИ
    var title: String {
        guard let start = startDate else {
            return "Неизвестная неделя"
        }

        let calendar = Calendar.current
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else {
            return "Неизвестная неделя"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")

        formatter.dateFormat = "d"
        let startDay = formatter.string(from: start)

        formatter.dateFormat = "d MMMM"
        let endDay = formatter.string(from: end)

        return "\(startDay) – \(endDay)"
    }
}


// MARK: - Day

struct Day: Codable, Identifiable, Equatable {
    let id = UUID()
    let date: String // YYYY-MM-DD
    let name: String
    let lessons: [Lesson]
    
    enum CodingKeys: String, CodingKey {
        case date, name, lessons
    }
}

// MARK: - Lesson

struct Lesson: Identifiable, Codable, Equatable {
    let id = UUID()
    let subject: String
    let mark: String?
    let hw: String?

    enum CodingKeys: String, CodingKey {
        case subject, mark, hw
    }

    var markInt: Int? {
        guard let mark = mark?.trimmingCharacters(in: .whitespacesAndNewlines), !mark.isEmpty else {
            return nil
        }

        if mark.contains("/") {
            let components = mark.split(separator: "/").map(String.init)
            guard components.count == 2,
                  let first = Double(components[0]),
                  let second = Double(components[1]) else {
                return nil // Некорректный формат дроби
            }
            
            let average = (first + second) / 2.0
            return Int(average.rounded()) // Округляем до ближайшего целого
            
        } else {
            // Для обычных оценок или букв (Н)
            return Int(mark)
        }
    }

    /// Гарантированное название предмета
    var safeSubject: String {
        subject
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

// MARK: - Error

struct ApiError: Decodable {
    let detail: String
}



