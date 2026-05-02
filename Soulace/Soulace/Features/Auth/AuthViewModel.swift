//
//  AuthViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import AuthenticationServices
import Combine

// MARK: - AuthViewModel
final class AuthViewModel: ObservableObject {
    @Published var isLoading: Bool       = false
    @Published var errorMessage: String? = nil

    private let authService  = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.isLoading = value }
            .store(in: &cancellables)

        authService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.errorMessage = value }
            .store(in: &cancellables)
    }

    // MARK: - Apple Sign In
    func handleAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        authService.handleSignInWithAppleRequest(request)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        authService.handleSignInWithAppleCompletion(result)
    }

    // MARK: - Google Sign In
    func signInWithGoogle() {
        Task { await authService.signInWithGoogle() }
    }
}
