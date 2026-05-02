//
//  SessionSummaryView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI

// MARK: - SessionSummaryView
struct SessionSummaryView: View {
    @StateObject private var vm: SessionSummaryViewModel
    @State private var appeared = false
    @State private var showHome = false

    init(summary: SessionSummary) {
        _vm = StateObject(wrappedValue: SessionSummaryViewModel(summary: summary))
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "1A2621"), Color(hex: "0F1A16")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    headerSection
                    statsCard
                    sessionInfoCard
                    if !vm.sortedDurations.isEmpty { timeTogether }
                    quoteCard
                    backButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 50)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showHome) {
            HomeView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.8).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Great session! 🎉")
                .font(.custom("Georgia-Bold", size: 26))
                .foregroundColor(.white)
            Text("You showed up for yourself and your friends.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -20)
    }

    // MARK: - Stats Card
    private var statsCard: some View {
        HStack(spacing: 0) {
            StatBox(
                value: "\(vm.totalMinutes)",
                label: "You stayed",
                unit: "minutes"
            )

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 52)

            StatBox(
                value: vm.longestParticipantName,
                label: "Longest",
                unit: vm.longestParticipantMinutes > 0
                    ? "\(vm.longestParticipantMinutes) min"
                    : ""
            )

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1, height: 52)

            StatBox(
                value: "\(vm.participantCount)",
                label: "Participants",
                unit: ""
            )
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Session Info Card
    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Summary")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 10) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(Color.soulaceMint)
                    .frame(width: 18)
                Text(vm.groupName)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(Color.soulaceMint)
                    .frame(width: 18)
                Text(vm.formattedDate)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
            }

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .foregroundColor(Color.soulaceMint)
                    .frame(width: 18)
                Text("\(vm.durationMinutes) min session · \(vm.participantCount) people")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Time Together Section
    private var timeTogether: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Time Together")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.8)

            let maxMinutes = vm.sortedDurations.map(\.minutes).max() ?? 1

            VStack(spacing: 10) {
                ForEach(Array(vm.sortedDurations.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 72, alignment: .leading)
                            .lineLimit(1)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.soulaceMint, Color.soulaceAccent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: appeared
                                            ? geo.size.width * CGFloat(item.minutes) / CGFloat(maxMinutes)
                                            : 0
                                    )
                                    .animation(
                                        .spring(response: 0.6, dampingFraction: 0.8)
                                            .delay(0.4 + Double(index) * 0.07),
                                        value: appeared
                                    )
                            }
                        }
                        .frame(height: 8)

                        Text("\(item.minutes) min")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Quote Card
    private var quoteCard: some View {
        VStack(spacing: 8) {
            Text("\"\(vm.motivationalQuote)\"")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .italic()
            Text("— Your yoga friends 💚")
                .font(.system(size: 12))
                .foregroundColor(Color.soulaceMint.opacity(0.7))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Back Button
    private var backButton: some View {
        Button {
            showHome = true
        } label: {
            Text("Back to Home")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.soulaceDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.soulaceMint)
                )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            if !unit.isEmpty {
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(Color.soulaceMint.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
