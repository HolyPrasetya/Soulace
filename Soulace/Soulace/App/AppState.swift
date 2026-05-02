import SwiftUI
import Combine

// MARK: - App Screen Enum
enum AppScreen {
    case splash
    case auth
    case home
    case call(sessionId: String)
}

// MARK: - AppState
/// Central state manager — injected via @EnvironmentObject throughout app
final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .splash
    @Published var currentUser: SoulaceUser? = nil
    @Published var isAuthenticated: Bool = false

    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        observeAuthState()
    }

    private func observeAuthState() {
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
            .store(in: &cancellables)
    }

    func navigateTo(_ screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = screen
        }
    }
}

// MARK: - Root View
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var splashDone = false

    var body: some View {
        ZStack {
            if !splashDone {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        splashDone = true
                    }
                }
                .zIndex(2)
                .transition(.opacity)
            } else {
                if appState.isAuthenticated {
                    HomeView()
                        .transition(.opacity)
                } else {
                    AuthView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.45), value: splashDone)
        .animation(.easeInOut(duration: 0.45), value: appState.isAuthenticated)
    }
}
