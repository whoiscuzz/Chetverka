import SwiftUI

struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationView {
            List {
                // --- Секция с аватаром и именем ---
                if let profile = viewModel.profile {
                    Section {
                        HStack(spacing: 16) {
                            // Аватар
                            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())

                            // Имя и класс
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.fullName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let className = profile.className {
                                    Text("\(className) класс")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // --- Секция с доп. информацией ---
                Section("Информация") {
                    if let teacher = viewModel.profile?.classTeacher {
                        InfoRow(label: "Классный руководитель", value: teacher)
                    }
                    // Можно добавить другие поля из профиля если они появятся
                }
                
                // --- Секция с выходом ---
                Section {
                    Button(role: .destructive, action: viewModel.logout) {
                        Label("Выйти", systemImage: "arrow.backward.square")
                    }
                }
            }
            .navigationTitle("Профиль")
        }
    }
}

// Вспомогательный View для строк с информацией
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}
