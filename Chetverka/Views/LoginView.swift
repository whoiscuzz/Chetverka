//
//  LoginView.swift
//  Chetverka
//
//  Created by whoiscuzz on 26.01.26.
//

import SwiftUI

struct LoginView: View {
    
    @StateObject private var viewModel = LoginViewModel()
    
    // Binding для управления состоянием показа этого View
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Text("Вход в schools.by")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                TextField("Логин", text: $viewModel.username)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)

                SecureField("Пароль", text: $viewModel.password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button(action: viewModel.login) {
                        Text("Войти")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("Авторизация")
            .navigationBarHidden(true)
            .onChange(of: viewModel.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    // Если вход успешен, скрываем это View
                    isPresented = false
                }
            }
        }
    }
}

// Для превью
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isPresented: .constant(true))
    }
}
