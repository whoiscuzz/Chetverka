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

    /// Красивое название недели (например, "1 – 7 сентября")
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
    let cabinet: String?
    let attachments: [LessonAttachment]?

    enum CodingKeys: String, CodingKey {
        case subject, mark, hw, cabinet, attachments
    }

    /// Преобразование строковой оценки (в т.ч. дробной "8/9") в число для Badge
    var markInt: Int? {
        guard let mark = mark?.trimmingCharacters(in: .whitespacesAndNewlines), !mark.isEmpty else {
            return nil
        }

        if mark.contains("/") {
            let components = mark.split(separator: "/").map(String.init)
            guard components.count == 2,
                  let first = Double(components[0]),
                  let second = Double(components[1]) else {
                return nil
            }
            let average = (first + second) / 2.0
            return Int(average.rounded())
        } else {
            return Int(mark)
        }
    }

    /// Очищенное название предмета для логики сравнения
    var safeSubject: String {
        subject
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasAttachments: Bool {
        !(attachments ?? []).isEmpty
    }
}

struct LessonAttachment: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let url: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case name, url, type
    }
}

// MARK: - Lesson Extensions (Fix for 'no member icon')

extension Lesson {
    /// Возвращает название иконки SF Symbols для конкретного предмета
    static func icon(for subject: String) -> String {
        let s = subject.lowercased()
        
        switch s {
        // Точные науки
        case _ where s.contains("матем") || s.contains("алгебр") || s.contains("геом"):
            return "function"
        case _ where s.contains("физик"):
            return "atom"
        case _ where s.contains("хими"):
            return "flask.fill"
        case _ where s.contains("биоло") || s.contains("природ"):
            return "leaf.fill"
        case _ where s.contains("информ"):
            return "laptopcomputer"
            
        // Языки и литература
        case _ where s.contains("русск") || s.contains("белор") || s.contains("яз"):
            return "character.book.closed.fill"
        case _ where s.contains("англ") || s.contains("иностр") || s.contains("нем"):
            return "abc"
        case _ where s.contains("литер"):
            return "book.fill"
            
        // Гуманитарные науки
        case _ where s.contains("истор"):
            return "scroll.fill"
        case _ where s.contains("геогр"):
            return "globe.europe.africa.fill"
        case _ where s.contains("общество"):
            return "person.2.fill"
            
        // Творчество и спорт
        case _ where s.contains("физк") || s.contains("час здор"):
            return "figure.run"
        case _ where s.contains("музык"):
            return "music.note"
        case _ where s.contains("изо") || s.contains("искус") || s.contains("хтп"):
            return "paintpalette.fill"
        case _ where s.contains("труд") || s.contains("технол"):
            return "hammer.fill"
        case _ where s.contains("черчен"):
            return "pencil.and.ruler.fill"
            
        // Остальное
        case _ where s.contains("поведен"):
            return "person.badge.shield.checkered.fill"
        default:
            return "book.closed"
        }
    }
}

// MARK: - Error

struct ApiError: Decodable {
    let detail: String
}
