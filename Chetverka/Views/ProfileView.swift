import SwiftUI

struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var newsViewModel: NewsViewModel
    @Environment(\.openURL) private var openURL
    @State private var feedbackError: String?
    @State private var showNewsComposer = false
    
    private let supportEmail = "chetverka@proton.me"
    
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
                    } else if viewModel.profile == nil {
                        Text("Профиль не загружен. Перезайди в аккаунт, чтобы вернуть ФИО и классного руководителя.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    // Можно добавить другие поля из профиля если они появятся
                }

                if viewModel.isCurrentUserAdmin {
                    Section("Администрирование") {
                        Button {
                            showNewsComposer = true
                        } label: {
                            Label("Добавить новость", systemImage: "plus.bubble.fill")
                        }
                    }
                }

                Section("Обратная связь") {
                    FeedbackActionButton(
                        icon: "ant.fill",
                        iconColor: .red,
                        title: "Сообщить о проблеме",
                        subtitle: "Опиши, что сломалось и на каком экране"
                    ) {
                        sendEmail(
                            subject: "Chetverka iOS: Проблема",
                            body: """
                            Что произошло:
                            """
                        )
                    }

                    FeedbackActionButton(
                        icon: "lightbulb.fill",
                        iconColor: .orange,
                        title: "Предложить идею",
                        subtitle: "Функции, которых не хватает в приложении"
                    ) {
                        sendEmail(
                            subject: "Chetverka iOS: Идея",
                            body: "Хочу предложить улучшение:\n\n"
                        )
                    }
                }
                
                // --- Секция с выходом ---
                Section {
                    Button(role: .destructive, action: viewModel.logout) {
                        Label("Выйти", systemImage: "arrow.backward.square")
                    }
                }
            }
            .navigationTitle("Профиль")
            .onAppear {
                viewModel.loadProfile()
            }
            .alert("Не удалось открыть почту", isPresented: Binding(
                get: { feedbackError != nil },
                set: { value in
                    if !value { feedbackError = nil }
                }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedbackError ?? "Попробуй позже.")
            }
            .sheet(isPresented: $showNewsComposer) {
                AdminNewsComposerSheet(
                    authorName: "fimacuzz",
                    newsViewModel: newsViewModel
                )
            }
        }
    }

    private func sendEmail(subject: String, body: String) {
        let metadata = "Версия: \(appVersion()) (\(appBuild()))"
        let composedBody = "\(body)\n\n\(metadata)"
        guard let url = mailtoURL(to: supportEmail, subject: subject, body: composedBody) else {
            feedbackError = "Некорректный адрес поддержки."
            return
        }

        openURL(url) { accepted in
            if !accepted {
                feedbackError = "На устройстве нет настроенной почты."
            }
        }
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private func appBuild() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    private func mailtoURL(to email: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
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

struct FeedbackActionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(iconColor)
                    .frame(width: 30, height: 30)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct AdminNewsComposerSheet: View {
    let authorName: String
    @ObservedObject var newsViewModel: NewsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var contentText = ""
    @State private var imageURLText = ""
    @State private var isPublishing = false
    @State private var errorMessage: String?

    var bodyView: some View {
        NavigationView {
            Form {
                Section("Заголовок") {
                    TextField("Например: Изменение расписания", text: $title)
                }

                Section("Текст новости") {
                    TextEditor(text: $contentText)
                        .frame(minHeight: 180)
                }

                Section("Фото (ссылка)") {
                    TextField("https://...", text: $imageURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Новая новость")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPublishing ? "Публикация..." : "Опубликовать") {
                        publish()
                    }
                    .disabled(isPublishing || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    var body: some View {
        bodyView
    }

    private func publish() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanImageURL = imageURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanBody.isEmpty else { return }

        let validatedImageURL: String?
        if cleanImageURL.isEmpty {
            validatedImageURL = nil
        } else if URL(string: cleanImageURL) != nil {
            validatedImageURL = cleanImageURL
        } else {
            errorMessage = "Укажи корректную ссылку на фото (https://...) или оставь поле пустым."
            return
        }

        isPublishing = true
        errorMessage = nil

        Task { @MainActor in
            defer { isPublishing = false }
            do {
                try await newsViewModel.publish(
                    title: cleanTitle,
                    body: cleanBody,
                    authorName: authorName,
                    imageURL: validatedImageURL
                )
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
