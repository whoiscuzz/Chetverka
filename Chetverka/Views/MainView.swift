
import SwiftUI

struct MainView: View {
    @StateObject private var diaryViewModel = DiaryViewModel()
    @StateObject private var newsViewModel = NewsViewModel()
    @State private var showLogin = false
    @State private var sessionid: String?
    @State private var pupilid: String?

    var body: some View {
        Group {
            // Используем TabView, как более стандартный корневой элемент
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Главная", systemImage: "house.fill")
                    }
                
                DiaryView()
                    .tabItem {
                        Label("Дневник", systemImage: "book.fill")
                    }
                
                AnalyticsView()
                    .tabItem {
                        Label("Аналитика", systemImage: "chart.pie.fill")
                    }

                ResultsView()
                    .tabItem {
                        Label("Итоги", systemImage: "graduationcap.fill")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Профиль", systemImage: "person.crop.circle.fill")
                    }
            }
            .environmentObject(diaryViewModel)
            .environmentObject(newsViewModel)
        }
        .onAppear(perform: setup)
        .sheet(isPresented: $showLogin) {
            // Этот блок вызывается после закрытия sheet
            reloadData()
        } content: {
            LoginView(isPresented: $showLogin)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
            // При получении уведомления о выходе
            self.showLogin = true
            self.diaryViewModel.reset()
            // Можно также сбросить состояние diaryViewModel, чтобы при следующем входе
            // данные точно перезагрузились
            // self.diaryViewModel = DiaryViewModel() // это вызовет ошибку, так как он @StateObject
        }
    }

    private func setup() {
        // Проверяем наличие sessionid и pupilid при запуске
        self.sessionid = KeychainService.shared.load(key: "sessionid")
        self.pupilid = KeychainService.shared.load(key: "pupilid")
        
        if self.sessionid != nil && self.pupilid != nil {
            // Загружаем данные, если id уже есть
            reloadData()
            Task { await newsViewModel.loadIfNeeded() }
        } else {
            // Если чего-то нет, показываем экран входа
            showLogin = true
        }
    }
    
    private func reloadData() {
        self.sessionid = KeychainService.shared.load(key: "sessionid")
        self.pupilid = KeychainService.shared.load(key: "pupilid")
        
        guard let sid = self.sessionid, let pid = self.pupilid else {
            // Если данных нет, снова показываем логин
            showLogin = true
            return
        }
        
        // Загружаем только если еще не загружено
        if !diaryViewModel.isLoaded {
             diaryViewModel.load(sessionid: sid, pupilid: pid)
        }
        Task { await newsViewModel.loadIfNeeded() }
    }
}

#Preview {
    MainView()
}
