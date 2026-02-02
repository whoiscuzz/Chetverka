import SwiftUI

struct MarkBadge: View {
    let mark: Int?

    var color: Color {
        guard let mark else { return .gray }
        switch mark {
        case 9...10: return .green
        case 7...8: return .blue
        case 5...6: return .orange
        default: return .red
        }
    }

    var body: some View {
        Text(mark != nil ? "\(mark!)" : "—")
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(color)
            .clipShape(Circle())
    }
}

