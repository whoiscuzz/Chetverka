import SwiftUI

struct SubjectMarkEntry: Identifiable, Equatable {
    let id = UUID()
    let mark: Int
    let markText: String
    let dateISO: String
}

struct SubjectSimulationView: View {

    @StateObject private var viewModel: SubjectSimulationViewModel
    private let originalMarkEntries: [SubjectMarkEntry]

    init(subject: String, markEntries: [SubjectMarkEntry]) {
        self.originalMarkEntries = markEntries
        _viewModel = StateObject(
            wrappedValue: SubjectSimulationViewModel(
                subject: subject,
                marks: markEntries.compactMap(\.mark)
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                marksHistoryCard
                goalCard
                addMarksCard
                addedMarksCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(viewModel.simulation.subject)
    }

    private var marksHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Все оценки")
                .font(.headline)

            if originalMarkEntries.isEmpty {
                Text("Пока нет оценок по этому предмету.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(originalMarkEntries) { entry in
                        HStack(spacing: 12) {
                            Text(formattedDate(entry.dateISO))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            GradeValueChip(valueText: entry.markText, value: entry.mark)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    private var summaryCard: some View {
        VStack(spacing: 14) {
            RingProgressView(
                value: viewModel.simulation.average,
                maxValue: 10,
                title: "Итоговый балл",
                color: color(for: viewModel.simulation.average)
            )

            HStack(spacing: 10) {
                statPill(title: "Исходных", value: "\(viewModel.simulation.originalMarks.count)")
                statPill(title: "Добавлено", value: "\(viewModel.simulation.addedMarks.count)")
                statPill(title: "Всего", value: "\(viewModel.simulation.allMarks.count)")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Цель на четверть")
                .font(.headline)

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
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    private var addMarksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Добавить оценку")
                    .font(.headline)
                Spacer()
                Text("Выбери значение")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let columns = [GridItem(.adaptive(minimum: 56, maximum: 74), spacing: 10)]
            let orderedMarks = [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(orderedMarks, id: \.self) { mark in
                    Button {
                        viewModel.add(mark: mark)
                    } label: {
                        MarkAddButtonLabel(mark: mark)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    private var addedMarksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Добавленные оценки")
                    .font(.headline)
                Spacer()
                if !viewModel.simulation.addedMarks.isEmpty {
                    Button("Очистить все", role: .destructive) {
                        viewModel.clearAddedMarks()
                    }
                    .font(.caption)
                }
            }

            if viewModel.simulation.addedMarks.isEmpty {
                Text("Пока ничего не добавлено. Нажми на оценку выше, чтобы смоделировать итог.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(viewModel.simulation.addedMarks.enumerated()), id: \.offset) { index, mark in
                            HStack(spacing: 6) {
                                Text("\(mark)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)

                                Button {
                                    viewModel.removeAddedMark(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(color(for: Double(mark)))
                            .cornerRadius(12)
                        }
                    }
                }

                Button(role: .destructive) {
                    viewModel.removeLast()
                } label: {
                    Text("Удалить последнюю")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
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

    private func formattedDate(_ isoDate: String) -> String {
        let source = DateFormatter()
        source.locale = Locale(identifier: "en_US_POSIX")
        source.dateFormat = "yyyy-MM-dd"

        guard let date = source.date(from: isoDate) else {
            return isoDate
        }

        let target = DateFormatter()
        target.locale = Locale(identifier: "ru_RU")
        target.dateFormat = "d MMMM"
        return target.string(from: date)
    }
}

private struct MarkAddButtonLabel: View {
    let mark: Int

    var body: some View {
        Text("\(mark)")
            .font(.title3)
            .fontWeight(.heavy)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            LinearGradient(
                colors: gradientColors(for: mark),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(14)
        .shadow(color: shadowColor(for: mark).opacity(0.28), radius: 6, x: 0, y: 3)
    }

    private func gradientColors(for value: Int) -> [Color] {
        switch value {
        case 9...10:
            return [Color(red: 0.08, green: 0.65, blue: 0.39), Color(red: 0.14, green: 0.77, blue: 0.48)]
        case 7...8:
            return [Color(red: 0.93, green: 0.53, blue: 0.08), Color(red: 0.98, green: 0.67, blue: 0.13)]
        case 5...6:
            return [Color(red: 0.16, green: 0.49, blue: 0.92), Color(red: 0.24, green: 0.61, blue: 0.99)]
        case 3...4:
            return [Color(red: 0.84, green: 0.30, blue: 0.14), Color(red: 0.92, green: 0.38, blue: 0.20)]
        default:
            return [Color(red: 0.62, green: 0.24, blue: 0.24), Color(red: 0.74, green: 0.30, blue: 0.30)]
        }
    }

    private func shadowColor(for value: Int) -> Color {
        switch value {
        case 9...10: return .green
        case 7...8: return .orange
        case 5...6: return .blue
        case 3...4: return .orange
        default: return .red
        }
    }
}

private struct GradeValueChip: View {
    let valueText: String
    let value: Int

    var body: some View {
        Text(valueText)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(10)
    }

    private var backgroundColor: Color {
        switch value {
        case 9...10:
            return .green
        case 7...8:
            return .orange
        case 5...6:
            return .blue
        case 3...4:
            return .orange.opacity(0.9)
        default:
            return .red
        }
    }
}
