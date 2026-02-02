import SwiftUI

struct AnalyticsView: View {

    @StateObject private var viewModel = AnalyticsViewModel()
    @EnvironmentObject var diaryVM: DiaryViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Средний балл
                    RingProgressView(
                        value: viewModel.average,
                        maxValue: 10,
                        title: "Средний балл"
                    )
                    .padding(.vertical)

                    // MARK: - Диаграмма
                    if !viewModel.pieData.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {

                            Text("Распределение оценок")
                                .font(.headline)

                            AnimatedPieChartView(slices: viewModel.pieData)
                                .frame(height: 220)

                            PieLegendView(slices: viewModel.pieData)
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(18)
                        .shadow(radius: 3)
                    }

                    // MARK: - Лучшие предметы
                    subjectsBlock(
                        title: "Лучшие предметы",
                        items: viewModel.bestSubjects,
                        color: .green
                    )

                    // MARK: - Проблемные предметы
                    subjectsBlock(
                        title: "Требуют внимания",
                        items: viewModel.weakSubjects,
                        color: .red
                    )
                }
                .padding()
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
                                Text(subject)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)

                                Spacer()

                                Text(String(format: "%.1f", avg))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(color)
                                    .cornerRadius(10)
                            }
                            .padding()
                        }
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
}

