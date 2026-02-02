import SwiftUI

struct SubjectSimulationView: View {

    @StateObject private var viewModel: SubjectSimulationViewModel

    init(subject: String, marks: [Int]) {
        _viewModel = StateObject(
            wrappedValue: SubjectSimulationViewModel(
                subject: subject,
                marks: marks
            )
        )
    }

    var body: some View {
        Form {
            // MARK: - Хедер с общей информацией
            Section {
                VStack(spacing: 20) {
                    RingProgressView(
                        value: viewModel.simulation.average,
                        maxValue: 10, // Максимальная оценка 10
                        title: "Итоговый балл",
                        color: color(for: viewModel.simulation.average)
                    )
                    
                    Text("Всего оценок: \(viewModel.simulation.allMarks.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // MARK: - Секция установки цели
            Section(header: Text("Цель на четверть")) {
                Picker("Желаемая оценка", selection: $viewModel.targetGrade) {
                    Text("Не задана").tag(0)
                    Text("10").tag(10)
                    Text("9").tag(9)
                    Text("8").tag(8)
                    Text("7").tag(7)
                }
                .pickerStyle(.segmented)

                if let summary = viewModel.goalSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // MARK: - Секция симулятора
            Section(header: Text("Симулятор оценок")) {
                // Добавление оценок
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach((5...10).reversed(), id: \.self) { mark in
                            Button {
                                viewModel.add(mark: mark)
                            } label: {
                                Text("+\(mark)")
                                    .fontWeight(.bold)
                                    .frame(width: 50, height: 44)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                
                // Удаление
                if !viewModel.simulation.addedMarks.isEmpty {
                    Button(role: .destructive) {
                        viewModel.removeLast()
                    } label: {
                        Text("Удалить последнюю")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .navigationTitle(viewModel.simulation.subject)
    }
    
    // MARK: - Цвет для кольца (10-балльная система)
    private func color(for average: Double) -> Color {
        if average >= 8.5 {
            return .green
        } else if average >= 6.5 {
            return .orange
        } else if average > 0 {
            return .red
        } else {
            return .gray
        }
    }
}
