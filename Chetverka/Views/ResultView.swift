import SwiftUI

struct ResultsView: View {

    @StateObject private var viewModel = ResultsViewModel()
    @EnvironmentObject var diaryVM: DiaryViewModel
    @State private var selectedMode: Mode = .currentQuarter

    private enum Mode: String, CaseIterable, Identifiable {
        case currentQuarter = "Текущая"
        case allQuarters = "Все четверти"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    

                    Picker("Режим", selection: $selectedMode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedMode {
                    case .currentQuarter:
                        currentQuarterSection
                    case .allQuarters:
                        allQuartersSection
                    }
                }
                .padding()
            }
            .navigationTitle("Итоги")
            .onAppear {
                viewModel.calculate(from: diaryVM.weeks)
                if selectedMode == .allQuarters {
                    Task { @MainActor in await reloadQuarterGradesIfNeeded(force: false) }
                }
            }
            .onChange(of: diaryVM.weeks.count) { _, _ in
                viewModel.calculate(from: diaryVM.weeks)
            }
            .onChange(of: selectedMode) { _, mode in
                guard mode == .allQuarters else { return }
                Task { @MainActor in await reloadQuarterGradesIfNeeded(force: false) }
            }
        }
    }

    private var currentQuarterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Средний балл")
                    .font(.title2)
                    .bold()
                Spacer()
            }

            LazyVStack(spacing: 12) {
                ForEach(viewModel.results) { result in
                    NavigationLink {
                        SubjectSimulationView(
                            subject: result.subject,
                            marks: marks(for: result.subject)
                        )
                    } label: {
                        SubjectResultCard(
                            subject: result.subject,
                            marksCount: result.marksCount,
                            average: result.average,
                            status: result.status
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var allQuartersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Все четверти")
                    .font(.title2)
                    .bold()
                Spacer()
                Button {
                    Task { @MainActor in await reloadQuarterGradesIfNeeded(force: true) }
                } label: {
                    if viewModel.isQuarterGradesLoading {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Обновить")
            }

            if viewModel.isQuarterGradesLoading {
                LoadingCard(text: "Загрузка оценок по четвертям…")
            } else if let error = viewModel.quarterGradesError {
                InfoCard(
                    title: "Не удалось загрузить",
                    subtitle: error,
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            } else if let table = viewModel.quarterGrades, !table.rows.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(table.rows) { row in
                        NavigationLink {
                            SubjectQuarterDetailView(
                                subject: row.subject,
                                columns: table.columns,
                                grades: row.grades,
                                currentQuarterMarks: marks(for: row.subject)
                            )
                        } label: {
                            QuarterSubjectCard(
                                subject: row.subject,
                                columns: table.columns,
                                grades: row.grades
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                InfoCard(
                    title: "Пока пусто",
                    subtitle: "На странице итогов не найдено таблицы оценок. Иногда schools.by меняет разметку.",
                    icon: "doc.text.magnifyingglass",
                    tint: .blue
                )
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

    @MainActor
    private func reloadQuarterGradesIfNeeded(force: Bool) async {
        if !force, viewModel.quarterGrades != nil { return }
        await viewModel.loadQuarterGrades(
            sessionid: KeychainService.shared.load(key: "sessionid"),
            pupilid: KeychainService.shared.load(key: "pupilid")
        )
    }
}

private struct SubjectQuarterDetailView: View {
    let subject: String
    let columns: [String]
    let grades: [String?]
    let currentQuarterMarks: [Int]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Оценки по четвертям")
                        .font(.title3)
                        .bold()

                    LazyVStack(spacing: 10) {
                        ForEach(columns.indices, id: \.self) { idx in
                            HStack(spacing: 12) {
                                Text(columns[idx])
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                GradeChip(
                                    label: QuarterUI.shortLabel(columns[idx]),
                                    valueText: gradeText(at: idx)
                                )
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(16)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Симулятор")
                        .font(.title3)
                        .bold()

                    NavigationLink {
                        SubjectSimulationView(subject: subject, marks: currentQuarterMarks)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Открыть симулятор")
                                    .font(.headline)
                                Text("Работает для текущей четверти (оценки из дневника).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.10))
                        .cornerRadius(18)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(subject)
    }

    private func gradeText(at idx: Int) -> String {
        if idx >= grades.count { return "—" }
        return (grades[idx]?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "—"
    }
}

private struct SubjectResultCard: View {
    let subject: String
    let marksCount: Int
    let average: Double
    let status: SubjectResult.Status

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
                Image(systemName: Lesson.icon(for: subject))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(subject)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("Оценок: \(marksCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%.2f", average))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor)
                    .cornerRadius(12)
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch status {
        case .noData: return .gray
        case .bad: return .red
        case .warning: return .orange
        case .good: return .green
        }
    }

    private var statusLabel: String {
        switch status {
        case .noData: return "Нет данных"
        case .bad: return "Риск"
        case .warning: return "Норм"
        case .good: return "Отлично"
        }
    }
}

private struct QuarterSubjectCard: View {
    let subject: String
    let columns: [String]
    let grades: [String?]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(subject)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(columns.indices, id: \.self) { idx in
                        GradeChip(
                            label: QuarterUI.shortLabel(columns[idx]),
                            valueText: gradeText(at: idx)
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func gradeText(at idx: Int) -> String {
        if idx >= grades.count { return "—" }
        return (grades[idx]?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "—"
    }
}

private struct GradeChip: View {
    let label: String
    let valueText: String

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(valueText)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 54, height: 34)
                .background(colorForValue)
                .cornerRadius(14)
        }
        .accessibilityLabel("\(label): \(valueText)")
    }

    private var colorForValue: Color {
        guard let v = Int(valueText) else { return Color.gray.opacity(0.55) }
        switch v {
        case 9...10: return .green
        case 7...8: return .orange
        case 1...6: return .red
        default: return Color.gray.opacity(0.55)
        }
    }
}

private enum QuarterUI {
    static func shortLabel(_ s: String) -> String {
        let lower = s.lowercased()
        let compact = lower.replacingOccurrences(of: " ", with: "")
        if compact == "i" { return "I" }
        if compact == "ii/i" || compact == "ii" { return "II" }
        if compact == "iii" { return "III" }
        if compact == "iv/ii" || compact == "iv" { return "IV" }
        if lower.contains("четвер") {
            let digits = s.filter { $0.isNumber }
            return digits.isEmpty ? "Ч" : digits
        }
        if lower.contains("средн") {
            return "Ср."
        }
        if lower.contains("год") || lower.contains("итог") {
            return "Год"
        }
        if s.count <= 4 { return s }
        return String(s.prefix(4))
    }
}

private struct LoadingCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
    }
}

private struct InfoCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14))
                .cornerRadius(14)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(18)
    }
}
