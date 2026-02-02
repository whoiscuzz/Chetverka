import SwiftUI

struct DashboardView: View {

    @EnvironmentObject var viewModel: DiaryViewModel

    // MARK: - Body
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    greetingSection
                    statCardsSection
                    todayLessonsSection
                    recentLessonsSection
                    attentionSubjectsSection
                }
                .padding()
            }
            .navigationTitle("Главная")
        }
    }

    // MARK: - Subviews
    
    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.randomGreeting)
                .font(.title)
                .bold()
            Text(today)
                .foregroundColor(.secondary)
        }
    }
    
    private var statCardsSection: some View {
        HStack(spacing: 12) {
            StatCard(title: "Уроков", value: viewModel.lessonsTodayCount, icon: "book.closed", color: .orange)
            StatCard(title: "ДЗ", value: viewModel.homeworkTodayCount, icon: "pencil.and.list.clipboard", color: .cyan)
            StatCard(title: "Средний балл", value: viewModel.overallAverageGrade, icon: "star", color: .yellow)
        }
    }
    
    private var todayLessonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Уроки на сегодня")
                .font(.title2)
                .bold()
            
            if viewModel.todayLessons.isEmpty {
                PlaceholderCard(text: "Уроков нет, можно отдыхать!", icon: "powersleep")
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.todayLessons) { lesson in
                        LessonRow(lesson: lesson)
                        if viewModel.todayLessons.last?.id != lesson.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
    
    private var recentLessonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние оценки")
                .font(.title2)
                .bold()
            
            if viewModel.recentLessons.isEmpty {
                PlaceholderCard(text: "Оценок пока нет. Время ставить рекорды!", icon: "sparkles")
            } else {
                ForEach(viewModel.recentLessons) { lesson in
                    RecentLessonRow(lesson: lesson)
                }
            }
        }
    }
    
    private var attentionSubjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Требуют внимания")
                .font(.title2)
                .bold()
            
            if viewModel.subjectsForAttention.isEmpty {
                PlaceholderCard(text: "Проблемных предметов нет. Так держать!", icon: "trophy.fill")
            } else {
                ForEach(viewModel.subjectsForAttention, id: \.name) { subject in
                    AttentionSubjectRow(subject: subject.name, average: subject.average)
                }
            }
        }
    }
    
    private var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date()).capitalized
    }
}


// MARK: - UI Components

struct RecentLessonRow: View {
    let lesson: RecentLesson
    
    var body: some View {
        HStack(spacing: 15) {
            Text(lesson.mark)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(Color.blue)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.subject)
                    .fontWeight(.semibold)
                Text(lesson.markComment)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
}

struct AttentionSubjectRow: View {
    let subject: String
    let average: Double
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(subject)
            
            Spacer()
            
            Text(String(format: "%.2f", average))
                .bold()
                .foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

struct PlaceholderCard: View {
    let text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            Text(text)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    DashboardView()
        .environmentObject(DiaryViewModel()) // Для превью
}

