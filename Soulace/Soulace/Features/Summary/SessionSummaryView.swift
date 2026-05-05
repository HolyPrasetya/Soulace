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
    @State private var appeared  = false
    @State private var showHome  = false

    init(summary: SessionSummary) {
        _vm = StateObject(wrappedValue: SessionSummaryViewModel(summary: summary))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A2621"), Color(hex: "0F1A16")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

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
        .fullScreenCover(isPresented: $showHome) { HomeView() }
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
            StatBox(value: "\(vm.totalMinutes)", label: "You stayed", unit: "minutes")
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 52)
            StatBox(
                value: vm.longestParticipantName,
                label: "Longest",
                unit: vm.longestParticipantMinutes > 0 ? "\(vm.longestParticipantMinutes) min" : ""
            )
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1, height: 52)
            StatBox(value: "\(vm.participantCount)", label: "Participants", unit: "")
        }
        .padding(.vertical, 20)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.08)))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Session Info Card
    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Summary")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase).tracking(0.8)

            HStack(spacing: 10) {
                Image(systemName: "person.2.fill").foregroundColor(Color.soulaceMint).frame(width: 18)
                Text(vm.groupName).font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
            }
            HStack(spacing: 10) {
                Image(systemName: "calendar").foregroundColor(Color.soulaceMint).frame(width: 18)
                Text(vm.formattedDate).font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
            }
            HStack(spacing: 10) {
                Image(systemName: "clock.fill").foregroundColor(Color.soulaceMint).frame(width: 18)
                Text("\(vm.durationMinutes) min session · \(vm.participantCount) people")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.07)))
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Time Together
    // ✅ Bug 3: durasi individual beda-beda + warna gradasi hijau makin terang = makin lama
    private var timeTogether: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Time Together")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase).tracking(0.8)

            let maxMinutes = vm.sortedDurations.map(\.minutes).max() ?? 1

            VStack(spacing: 12) {
                ForEach(Array(vm.sortedDurations.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 10) {
                        // Nama
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)

                        // Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.08))

                                // ✅ Warna gradasi: makin lama = lebih hijau terang
                                // ratio = persentase dari max duration (0.0 - 1.0)
                                let ratio  = maxMinutes > 0 ? Double(item.minutes) / Double(maxMinutes) : 0
                                let startC = durationColor(ratio: ratio, brighten: false)
                                let endC   = durationColor(ratio: ratio, brighten: true)

                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(
                                            colors: [startC, endC],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: appeared
                                            ? geo.size.width * CGFloat(ratio)
                                            : 0
                                    )
                                    .animation(
                                        .spring(response: 0.6, dampingFraction: 0.75)
                                            .delay(0.3 + Double(index) * 0.08),
                                        value: appeared
                                    )
                            }
                        }
                        .frame(height: 10)

                        // Menit
                        Text("\(item.minutes)m")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                legendDot(color: Color(hex: "3D5A3E"), label: "Shorter stay")
                legendDot(color: Color.soulaceMint, label: "Full session")
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.07)))
        .opacity(appeared ? 1 : 0)
    }

    // ✅ Warna bar: ratio rendah = hijau gelap, ratio tinggi = mint terang
    private func durationColor(ratio: Double, brighten: Bool) -> Color {
        let r = max(0, min(1, ratio))
        // Dari hijau gelap (0,0.22,0.15) ke mint terang (0.82,0.89,0.89)
        let dark  = (red: 0.15, green: 0.30, blue: 0.22)
        let light = (red: 0.75, green: 0.89, blue: 0.82)
        let boost = brighten ? 0.15 : 0.0
        return Color(
            red:   dark.red   + (light.red   - dark.red)   * r + boost,
            green: dark.green + (light.green - dark.green) * r + boost,
            blue:  dark.blue  + (light.blue  - dark.blue)  * r + boost
        )
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 8)
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
        }
    }

    // MARK: - Quote Card
    private var quoteCard: some View {
        VStack(spacing: 8) {
            Text("\"\(vm.motivationalQuote)\"")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .italic()
            Text("— YO-GAnkz 💚")
                .font(.system(size: 12))
                .foregroundColor(Color.soulaceMint.opacity(0.7))
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.05)))
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Back Button
    private var backButton: some View {
        Button { showHome = true } label: {
            Text("Back to Home")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.soulaceDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.soulaceMint))
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
    let unit:  String

    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            if !unit.isEmpty {
                Text(unit).font(.system(size: 11)).foregroundColor(Color.soulaceMint.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

