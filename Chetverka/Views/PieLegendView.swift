import SwiftUI

struct PieLegendView: View {

    let slices: [SubjectSlice]   // ⬅️ НЕ Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(slices) { slice in
                HStack {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)

                    Text(slice.subject)
                        .lineLimit(1)

                    Spacer()

                    Text("\(slice.value)")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
