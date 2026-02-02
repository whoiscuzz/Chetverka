import SwiftUI

struct ResultsView: View {

    @StateObject private var viewModel = ResultsViewModel()
    @EnvironmentObject var diaryVM: DiaryViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.results) { result in

                    NavigationLink {

                        // 🔥 ЭКРАН СИМУЛЯЦИИ
                        SubjectSimulationView(
                            subject: result.subject,
                            marks: marks(for: result.subject)
                        )

                    } label: {

                        // 📊 СТРОКА ПРЕДМЕТА
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.subject)
                                    .font(.headline)

                                Text("Оценок: \(result.marksCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(String(format: "%.2f", result.average))
                                .font(.title3)
                                .bold()
                                .padding(10)
                                .background(color(for: result.status))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Итоги")
            .onAppear {
                viewModel.calculate(from: diaryVM.weeks)
            }
            .onChange(of: diaryVM.weeks.count) { _, _ in
                viewModel.calculate(from: diaryVM.weeks)
            }
        }
    }

    // MARK: - Достаём оценки предмета
    private func marks(for subject: String) -> [Int] {
        diaryVM.weeks
            .flatMap { $0.days }
            .flatMap { $0.lessons }
            .filter { $0.safeSubject == subject.lowercased() }
            .compactMap { $0.markInt }
    }

    // MARK: - Цвет статуса
    private func color(for status: SubjectResult.Status) -> Color {
        switch status {
        case .noData:
            return .gray
        case .bad:
            return .red
        case .warning:
            return .orange
        case .good:
            return .green
        }
    }
}
