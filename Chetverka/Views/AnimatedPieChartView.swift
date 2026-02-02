import SwiftUI

struct AnimatedPieChartView: View {

    let slices: [SubjectSlice]

    @State private var animatedValues: [UUID: Double] = [:]

    private var total: Double {
        slices.map { Double($0.value) }.reduce(0, +)
    }

    var body: some View {
        ZStack {
            ForEach(slices.indices, id: \.self) { index in
                let slice = slices[index]

                PieSliceShape(
                    startAngle: startAngle(for: index),
                    endAngle: endAngle(for: index)
                )
                .fill(slice.color)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            animate()
        }
        .onChange(of: slices.count) { _, _ in
            animate()
        }
    }

    private func animate() {
        animatedValues.removeAll()
        for (index, slice) in slices.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                withAnimation(.easeOut(duration: 0.6)) {
                    animatedValues[slice.id] = Double(slice.value)
                }
            }
        }
    }

    private func startAngle(for index: Int) -> Angle {
        let sum = slices[..<index].reduce(0) { $0 + $1.value }
        return .degrees(Double(sum) / total * 360 - 90)
    }

    private func endAngle(for index: Int) -> Angle {
        let sum = slices[...index].reduce(0) { $0 + $1.value }
        return .degrees(Double(sum) / total * 360 - 90)
    }
}
