import SwiftUI
import Charts

struct SubjectAnalyticsDetailView: View {
    
    @StateObject private var viewModel: SubjectAnalyticsDetailViewModel
    
    init(subjectName: String, lessons: [Lesson]) {
        _viewModel = StateObject(
            wrappedValue: SubjectAnalyticsDetailViewModel(
                subjectName: subjectName,
                lessons: lessons
            )
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                
                if viewModel.distributionData.isEmpty {
                    Text("Нет данных для анализа")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    distributionChart
                    dynamicsChart
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.subjectName)
    }
    
    // MARK: - График распределения
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Распределение оценок")
                .font(.title2.bold())
            
            Chart(viewModel.distributionData) { data in
                BarMark(
                    x: .value("Оценка", data.mark),
                    y: .value("Количество", data.count)
                )
                .foregroundStyle(by: .value("Оценка", data.mark))
                .annotation(position: .top) {
                    Text("\(data.count)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 200)
        }
    }
    
    // MARK: - График динамики
    private var dynamicsChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Динамика среднего балла")
                .font(.title2.bold())
            
            Chart(viewModel.dynamicsData) { data in
                // Линия
                LineMark(
                    x: .value("Номер урока", data.lessonNumber),
                    y: .value("Средний балл", data.average)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.blue)
                
                // Точки на линии
                PointMark(
                    x: .value("Номер урока", data.lessonNumber),
                    y: .value("Средний балл", data.average)
                )
                .foregroundStyle(.blue)
                .symbolSize(60)
            }
            .chartYScale(domain: 1...10) // Фиксируем шкалу от 1 до 10
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .frame(height: 220)
        }
    }
}
