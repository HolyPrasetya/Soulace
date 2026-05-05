//
//  AuthView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var appeared = false

    // Inline color values — safe from compile order issues
    private let colorDark   = Color(red: 0.173, green: 0.243, blue: 0.208)
    private let colorAccent = Color(red: 0.290, green: 0.486, blue: 0.435)
    private let colorMint   = Color(red: 0.820, green: 0.890, blue: 0.890)
    private let colorSage   = Color(red: 0.933, green: 0.957, blue: 0.816)
    private let colorPeach  = Color(red: 1.000, green: 0.933, blue: 0.878)

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [colorPeach, colorSage, colorMint],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
            .ignoresSafeArea()

            // Blobs
            Circle()
                .fill(colorMint.opacity(0.5))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -100, y: -220)

            Circle()
                .fill(colorPeach.opacity(0.55))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: 120, y: 240)

            VStack(spacing: 0) {
                Spacer()

                // Logo
                logoSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer()

                // Tagline
                taglineSection
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .padding(.bottom, 44)

                // Auth buttons
                authButtons
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Spacer().frame(height: 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Logo
    private var logoSection: some View {
        VStack(spacing: 14) {
            Image("SecondarySoulace")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)

            VStack(spacing: 5) {
                Text("SOULACE")
                    .font(.custom("Georgia-Bold", size: 28))
                    .tracking(5)
                    .foregroundColor(colorDark)

                Text("Yoga together")
                    .font(.system(size: 14))
                    .foregroundColor(colorDark.opacity(0.5))
            }
        }
    }

    // MARK: - Tagline
    private var taglineSection: some View {
        VStack(spacing: 10) {
            Text("Everyday counts,\non the Mat")
                .font(.custom("Georgia", size: 26))
                .multilineTextAlignment(.center)
                .foregroundColor(colorDark)

            Text("Create, join and grow together")
                .font(.system(size: 14))
                .foregroundColor(colorDark.opacity(0.5))
        }
    }

    // MARK: - Auth Buttons
    private var authButtons: some View {
        VStack(spacing: 14) {

            // ── Apple Sign In ──
            SignInWithAppleButton(
                .signIn,
                onRequest:    { vm.handleAppleRequest($0) },
                onCompletion: { vm.handleAppleCompletion($0) }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)

            // ── Divider ──
            HStack(spacing: 12) {
                Rectangle()
                    .fill(colorDark.opacity(0.15))
                    .frame(height: 1)
                Text("or")
                    .font(.system(size: 13))
                    .foregroundColor(colorDark.opacity(0.4))
                Rectangle()
                    .fill(colorDark.opacity(0.15))
                    .frame(height: 1)
            }

            // ── Google Sign In ──
            Button(action: { vm.signInWithGoogle() }) {
                HStack(spacing: 10) {
                    Image("google_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    Text("Sign in with Google")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                )
            }
            .buttonStyle(SoulaceScaleButtonStyle())

            // ── Loading indicator ──
            if vm.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(colorAccent)
                    Text("Signing in...")
                        .font(.system(size: 14))
                        .foregroundColor(colorDark.opacity(0.6))
                }
                .padding(.top, 4)
            }

            // ── Error ──
            if let error = vm.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            // ── Terms ──
            Text("By continuing, you agree to our Terms & Privacy Policy")
                .font(.system(size: 11))
                .foregroundColor(colorDark.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }
}
