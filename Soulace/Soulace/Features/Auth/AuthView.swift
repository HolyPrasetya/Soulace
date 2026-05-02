//
//  AuthView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()

    private let mint = Color(red: 0.820, green: 0.890, blue: 0.890)
    private let sage = Color(red: 0.933, green: 0.957, blue: 0.816)
    private let peach = Color(red: 1.000, green: 0.933, blue: 0.878)
    private let dark = Color(red: 0.173, green: 0.243, blue: 0.208)
    private let accent = Color(red: 0.290, green: 0.486, blue: 0.435)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [peach, sage, mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    Image("SecondarySoulace")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)

                    VStack(spacing: 10) {
                        Text("Welcome to Soulace")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(dark)
                            .multilineTextAlignment(.center)

                        Text("Sign in to join yoga sessions, connect with your group, and keep your practice together.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(dark.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 14) {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: viewModel.handleRequest,
                            onCompletion: viewModel.handleCompletion
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {
                            viewModel.signInWithGoogle()
                        } label: {
                            HStack(spacing: 12) {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)

                                Text("Continue with Google")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(dark)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white.opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(accent.opacity(0.18), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading)
                    }

                    if viewModel.isLoading {
                        ProgressView("Signing in...")
                            .tint(accent)
                            .foregroundStyle(dark.opacity(0.7))
                    }

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

#Preview {
    AuthView()
}
