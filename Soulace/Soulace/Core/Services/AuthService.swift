//
//  AuthService.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import FirebaseAuth
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift
import CryptoKit
import Combine

// MARK: - Auth Method
enum AuthMethod {
    case apple
    case google
}

// MARK: - AuthService
/// Handles Apple Sign In + Google Sign In + Firebase Auth
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: SoulaceUser? = nil
    @Published var isLoading: Bool           = false
    @Published var error: String?            = nil

    private var currentNonce: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()
        observeFirebaseAuth()
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Observe Firebase Auth State
    private func observeFirebaseAuth() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            if let firebaseUser {
                Task { await self.fetchOrCreateUser(firebaseUser: firebaseUser) }
            } else {
                DispatchQueue.main.async { self.currentUser = nil }
            }
        }
    }

    // MARK: - ─────────────────────────────────────────────
    // MARK: APPLE SIGN IN
    // MARK: - ─────────────────────────────────────────────

    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce    = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let err):
            DispatchQueue.main.async { self.error = err.localizedDescription }

        case .success(let auth):
            guard
                let credential  = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce       = currentNonce,
                let tokenData   = credential.identityToken,
                let tokenString = String(data: tokenData, encoding: .utf8)
            else {
                DispatchQueue.main.async { self.error = "Unable to fetch Apple identity token" }
                return
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce:    nonce,
                fullName:    credential.fullName
            )

            let fullName = [credential.fullName?.givenName,
                            credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            signInToFirebase(with: firebaseCredential,
                             fullNameOverride: fullName.isBlank ? nil : fullName)
        }
    }

    // MARK: - ─────────────────────────────────────────────
    // MARK: GOOGLE SIGN IN
    // MARK: - ─────────────────────────────────────────────

    @MainActor
    func signInWithGoogle() async {
        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes
                .first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            self.error = "Cannot find root view controller"
            return
        }

        isLoading = true
        error     = nil

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

            guard let idToken = result.user.idToken?.tokenString else {
                self.error = "Missing Google ID token"
                isLoading  = false
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken:     idToken,
                accessToken:     result.user.accessToken.tokenString
            )

            let fullName = [result.user.profile?.givenName,
                            result.user.profile?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            signInToFirebase(with: credential,
                             fullNameOverride: fullName.isBlank ? nil : fullName)

        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                // GIDSignIn cancelled by user — don't show error
                if (error as NSError).code != GIDSignInError.canceled.rawValue {
                    self.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: - ─────────────────────────────────────────────
    // MARK: SHARED FIREBASE SIGN IN
    // MARK: - ─────────────────────────────────────────────

    private func signInToFirebase(with credential: AuthCredential,
                                   fullNameOverride: String? = nil) {
        DispatchQueue.main.async { self.isLoading = true }

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self else { return }
            DispatchQueue.main.async { self.isLoading = false }

            if let error {
                DispatchQueue.main.async { self.error = error.localizedDescription }
                return
            }

            guard let firebaseUser = authResult?.user else { return }

            Task {
                await self.fetchOrCreateUser(
                    firebaseUser:     firebaseUser,
                    fullNameOverride: fullNameOverride
                )
            }
        }
    }

    // MARK: - Fetch or Create Firestore User
    private func fetchOrCreateUser(firebaseUser: FirebaseAuth.User,
                                   fullNameOverride: String? = nil) async {
        do {
            if let existing = try await FirestoreService.shared.getUser(id: firebaseUser.uid) {
                DispatchQueue.main.async { self.currentUser = existing }
            } else {
                let newUser = SoulaceUser(
                    id:                    firebaseUser.uid,
                    fullName:              fullNameOverride
                                           ?? firebaseUser.displayName
                                           ?? "Soulace User",
                    email:                 firebaseUser.email ?? "",
                    appleUserIdentifier:   firebaseUser.uid
                )
                try await FirestoreService.shared.createUser(newUser)
                DispatchQueue.main.async { self.currentUser = newUser }
            }
        } catch {
            DispatchQueue.main.async { self.error = error.localizedDescription }
        }
    }

    // MARK: - Sign Out
    func signOut() {
        // Sign out from Google too if active
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        DispatchQueue.main.async { self.currentUser = nil }
    }

    // MARK: - Handle Google URL (add to SoulaceApp.swift)
    /// Call this from scene(_:openURLContexts:) or onOpenURL modifier
    func handleGoogleURL(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - ─────────────────────────────────────────────
    // MARK: NONCE HELPERS (Apple Sign In)
    // MARK: - ─────────────────────────────────────────────

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode   = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("SecRandomCopyBytes failed: \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData  = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
