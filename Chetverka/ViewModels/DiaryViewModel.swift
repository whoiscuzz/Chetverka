import Foundation
import Combine

struct RecentLesson: Identifiable {
    let id = UUID()
    let subject: String
    let mark: String
    let markComment: String // "Рофл" коммент
}

final class DiaryViewModel: ObservableObject {

    @Published var weeks: [Week] = []
    
    // For NEW Dashboard
    @Published var randomGreeting: String = "Привет 👋"
    @Published var recentLessons: [RecentLesson] = []
    @Published var subjectsForAttention: [(name: String, average: Double)] = []
    @Published var todayLessons: [Lesson] = []
    
    // For OLD Dashboard (StatCards)
    @Published var lessonsTodayCount: String = "—"
    @Published var homeworkTodayCount: String = "—"
    @Published var overallAverageGrade: String = "—"

    // State
    @Published var isLoading = false
    @Published var error: String?
    @Published var isLoaded = false

    // MARK: - Private Properties
    
    private let api = DiaryAPI()
    private let cache = DiaryCache()
    private var cancellables = Set<AnyCancellable>()
    
    private let greetings = [
        "Снова за учебу?",
        "Готов(а) к новым знаниям (и мемам)?",
        "Загружаем оценки... надеюсь, там не все плохо.",
        "Какие оценки мы получим сегодня?",
        "Смотрим дневник... одним глазком."
    ]

    // MARK: - Public Methods

    func reset() {
        weeks = []
        recentLessons = []
        subjectsForAttention = []
        todayLessons = []
        lessonsTodayCount = "—"
        homeworkTodayCount = "—"
        overallAverageGrade = "—"
        error = nil
        isLoading = false
        isLoaded = false
    }
    
    func load(sessionid: String, pupilid: String) {
        print("🔥 loadDiary CALLED with sessionid and pupilid")

        guard !sessionid.isEmpty, !pupilid.isEmpty else {
            error = "SessionID или PupilID пустой"
            return
        }

        isLoading = true
        error = nil

        // Сначала пытаемся загрузить из кэша для этого пользователя
        if let cachedResponse = cache.load(for: pupilid) {
            print("✅ Loaded from cache for pupil \(pupilid), processing...")
            self.processResponse(cachedResponse)
            self.isLoaded = true
            // Не прекращаем загрузку, чтобы обновить данные в фоне
        }

        api.loadDiary(sessionid: sessionid, pupilid: pupilid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let response):
                    print("✅ Loaded from API, processing and caching for pupil \(pupilid)...")
                    self.processResponse(response)
                    self.cache.save(response, for: pupilid) // Сохраняем в кэш для этого пользователя
                    self.isLoaded = true
                    
                case .failure(let err):
                    // Показываем ошибку только если у нас нет вообще никаких данных (даже из кэша)
                    if !self.isLoaded {
                        self.error = err.localizedDescription
                    }
                    print("❌ Load error:", err.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func processResponse(_ response: DiaryResponse) {
        // --- Обновляем базовые данные ---
        self.weeks = response.weeks
        self.randomGreeting = greetings.randomElement() ?? "Привет 👋"
        
        let allLessons = response.weeks.flatMap { $0.days.flatMap { $0.lessons } }
        
        // --- Вычисляем данные для StatCards и расписания ---
        calculateStatCardMetrics(lessons: allLessons, weeks: response.weeks)
        
        // --- Вычисляем НОВЫЕ данные для дашборда ---
        calculateRecentLessons(from: allLessons)
        calculateSubjectsForAttention(from: allLessons)
    }
    
    private func calculateStatCardMetrics(lessons: [Lesson], weeks: [Week]) {
        // 1. Средний балл
        let allMarks = lessons.compactMap { $0.markInt }
        if !allMarks.isEmpty {
            let average = Double(allMarks.reduce(0, +)) / Double(allMarks.count)
            self.overallAverageGrade = String(format: "%.2f", average)
        } else {
            self.overallAverageGrade = "—"
        }
        
        // 2. Данные на сегодня (по дате)
        let todayString = todayDateString()
        let todayLessons = weeks
            .flatMap { $0.days }
            .first { $0.date == todayString }?
            .lessons ?? []
        
        self.todayLessons = todayLessons // Сохраняем уроки
        
        if !todayLessons.isEmpty {
            self.lessonsTodayCount = "\(todayLessons.count)"
            self.homeworkTodayCount = "\(todayLessons.filter { !($0.hw ?? "").isEmpty }.count)"
        } else {
            self.lessonsTodayCount = "0"
            self.homeworkTodayCount = "0"
        }
    }
    
    /// Расчет последних полученных оценок
    private func calculateRecentLessons(from lessons: [Lesson]) {
        let lessonsWithMarks: [Lesson] = lessons.filter { $0.markInt != nil && !($0.mark ?? "").isEmpty }
        let lastFour = lessonsWithMarks.suffix(4)
        let recent: [RecentLesson] = lastFour.map { lesson in
            RecentLesson(
                subject: lesson.subject.capitalized,
                mark: lesson.mark!,
                markComment: comment(for: lesson.markInt!)
            )
        }
        self.recentLessons = recent.reversed()
    }
    
    /// Расчет предметов, требующих внимания
    private func calculateSubjectsForAttention(from lessons: [Lesson]) {
        var subjectMarks: [String: [Int]] = [:]
        for lesson in lessons {
            guard let mark = lesson.markInt else { continue }
            subjectMarks[lesson.safeSubject, default: []].append(mark)
        }
        
        let allAverages: [(name: String, average: Double)] = subjectMarks.map { key, values in
             (
                name: key.capitalized,
                average: Double(values.reduce(0, +)) / Double(values.count)
            )
        }
        
        let weakSubjects = allAverages.filter { $0.average < 6.5 }
        let sortedWeak = weakSubjects.sorted { $0.average < $1.average }
        
        self.subjectsForAttention = Array(sortedWeak.prefix(2))
    }
    
    /// Возвращает "рофл" коммент для оценки
    private func comment(for mark: Int) -> String {
        switch mark {
        case 10: return "Это было легендарно!"
        case 9: return "Почти идеально!"
        case 7, 8: return "Так держать!"
        case 5, 6: return "Неплохо, но можно лучше."
        case 4: return "Бывает... Главное, чтобы не система."
        default: return "Ого, редкая оценка!"
        }
    }
    
    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Находит индекс недели, которая содержит сегодняшнюю дату.
    func findCurrentWeekIndex(in weeks: [Week]) -> Int {
        let todayString = todayDateString()
        if let index = weeks.firstIndex(where: { week in
            week.days.contains(where: { $0.date == todayString })
        }) {
            return index
        }
        return 0 // Возвращаем первую неделю, если текущая не найдена
    }
}
