import SwiftUI

struct RingProgressView: View {
    let value: Double          // текущее значение
    let maxValue: Double       // максимум (например 10)
    let title: String
    var color: Color? = nil    // опциональный цвет

    @State private var progress: Double = 0

    // Выбираем, что использовать для обводки
    private var strokeStyle: AnyShapeStyle {
        if let color {
            return AnyShapeStyle(color)
        } else {
            return AnyShapeStyle(
                AngularGradient(
                    gradient: Gradient(colors: [.purple, .blue, .green]),
                    center: .center
                )
            )
        }
    }

    var body: some View {
        ZStack {
            // Фон кольца
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: 14
                )

            // Прогресс
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    strokeStyle, // Используем выбранный стиль
                    style: StrokeStyle(
                        lineWidth: 14,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    .easeOut(duration: 1),
                    value: progress
                )

            // Текст в центре
            VStack(spacing: 4) {
                Text(String(format: "%.2f", value))
                    .font(.system(size: 28, weight: .bold))

                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 160, height: 160)
        .onAppear {
            animate()
        }
        .onChange(of: value) { _ in
            animate()
        }
    }

    private func animate() {
        let normalized = min(value / maxValue, 1)
        progress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            progress = normalized
        }
    }
}
