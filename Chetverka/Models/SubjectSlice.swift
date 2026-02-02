import SwiftUI

struct SubjectSlice: Identifiable {
    let id: UUID
    let subject: String
    let value: Int
    let color: Color

    init(subject: String, value: Int, color: Color) {
        self.id = UUID()
        self.subject = subject
        self.value = value
        self.color = color
    }
}
