import SwiftUI

struct AnalyticsView: View {

    @StateObject private var viewModel = AnalyticsViewModel()
    @EnvironmentObject var diaryVM: DiaryViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    
                    RingProgressView(
                        value: viewModel.average,
                        maxValue: 10,
                        title: "Средний балл"
                    )
                    .padding(.vertical)



                    // MARK: - Все предметы
                    subjectsBlock(
                        title: "Все предметы",
                        items: viewModel.allSubjects,
                        color: .accentColor
                    )
                }
                .padding()
                .alert("Установить цель для \(subjectToSetGoal ?? "")", isPresented: $showGoalAlert) {
                    TextField("Цель (например, 8.5)", text: $goalInput)
                        .keyboardType(.decimalPad)
                    Button("Установить") {
                        if let subject = subjectToSetGoal {
                            let formatter = NumberFormatter()
                            formatter.locale = Locale.current // Ensure correct decimal separator
                            if let number = formatter.number(from: goalInput), let goal = Double(exactly: number) {
                                viewModel.saveSubjectGoal(subject: subject, goal: goal)
                            } else if goalInput.isEmpty { // Allow clearing the goal by empty input
                                viewModel.saveSubjectGoal(subject: subject, goal: nil)
                            }
                        }
                    }
                    Button("Очистить", role: .destructive) {
                        if let subject = subjectToSetGoal {
                            viewModel.saveSubjectGoal(subject: subject, goal: nil)
                        }
                    }
                    Button("Отмена", role: .cancel) { }
                }
            }
            .navigationTitle("Аналитика")
            .onAppear {
                viewModel.calculate(from: diaryVM.weeks)
            }
            .onChange(of: diaryVM.isLoaded) { _, loaded in
                if loaded {
                    viewModel.calculate(from: diaryVM.weeks)
                }
            }
        }
    }

    // MARK: - Блок предметов
    private func subjectsBlock(
        title: String,
        items: [(String, Double)],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            if items.isEmpty {
                Text("Нет данных")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(items, id: \.0) { subject, avg in
                        NavigationLink(destination: SubjectAnalyticsDetailView(subjectName: subject, lessons: lessons(for: subject))) {
                            HStack {
                                Image(systemName: Lesson.icon(for: subject))
                                    .font(.body)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 25, alignment: .center)
                                Text(subject)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)

                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text(String(format: "%.1f", avg))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(color)
                                        .cornerRadius(10)

                                    if let target = viewModel.subjectGoals[subject] {
                                        Text("Цель: \(String(format: "%.1f", target))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                        }
                        .simultaneousGesture(LongPressGesture().onEnded { _ in
                            presentGoalSetting(for: subject, currentGoal: viewModel.subjectGoals[subject])
                        })
                        if items.last?.0 != subject {
                           Divider()
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(18)
                .shadow(radius: 3)
            }
        }
    }

    /// Находит все уроки для указанного предмета
    private func lessons(for subject: String) -> [Lesson] {
        diaryVM.weeks
            .flatMap { $0.days }
            .flatMap { $0.lessons }
            .filter { $0.safeSubject == subject.lowercased() }
    }

    // MARK: - Goal Setting Logic
    @State private var showGoalAlert = false
    @State private var subjectToSetGoal: String?
    @State private var goalInput: String = ""

    private func presentGoalSetting(for subject: String, currentGoal: Double?) {
        subjectToSetGoal = subject
        goalInput = currentGoal.map { String(format: "%.1f", $0) } ?? ""
        showGoalAlert = true
    }
}

