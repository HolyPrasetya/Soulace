//
//  GroupDetailView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI

// MARK: - GroupDetailView
struct GroupDetailView: View {
    @StateObject private var vm: GroupDetailViewModel
    @EnvironmentObject var appState: AppState

    init(group: YogaGroup) {
        _vm = StateObject(wrappedValue: GroupDetailViewModel(group: group))
    }

    var body: some View {
        ZStack {
            Color(hex: "F5F8F6").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    groupHeader
                    inviteCodeCard
                    sessionsSection
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // Copied toast
            if vm.showInviteCopied {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("Invite code copied!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.soulaceAccent)
                            .shadow(color: Color.soulaceAccent.opacity(0.4), radius: 10, x: 0, y: 4)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.showInviteCopied)
            }
        }
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { vm.showCreateSession = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Session")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color.soulaceAccent)
                }
            }
        }
        .sheet(isPresented: $vm.showCreateSession, onDismiss: { vm.fetchSessions() }) {
            CreateSessionView(groups: [vm.group])
        }
    }

    // MARK: - Group Header
    private var groupHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.soulaceMint, Color.soulaceSage],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 74, height: 74)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.soulaceAccent)
            }

            VStack(spacing: 5) {
                Text(vm.group.name)
                    .font(.custom("Georgia-Bold", size: 22))
                    .foregroundColor(Color.soulaceDark)

                if !vm.group.description.isBlank {
                    Text(vm.group.description)
                        .font(.system(size: 14))
                        .foregroundColor(Color.soulaceDark.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                Text(vm.memberLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.soulaceAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.soulaceAccent.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Invite Code Card
    private var inviteCodeCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Invite Code")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(vm.group.inviteCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.soulaceAccent)
                    .tracking(3)
            }

            Spacer()

            Button(action: { vm.copyInviteCode() }) {
                Label("Copy", systemImage: "doc.on.doc.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.soulaceAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(Color.soulaceAccent.opacity(0.1))
                    )
            }
            .buttonStyle(SoulaceScaleButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Sessions Section
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Upcoming Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text("\(vm.sessions.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.soulaceAccent)
            }

            if vm.isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(Color.soulaceAccent)
                    Spacer()
                }
                .padding(.vertical, 28)

            } else if vm.sessions.isEmpty {
                emptySessionsView

            } else {
                VStack(spacing: 10) {
                    ForEach(vm.sessions) { session in
                        SessionRowCard(session: session)
                    }
                }
            }
        }
    }

    // MARK: - Empty Sessions
    private var emptySessionsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 38))
                .foregroundColor(Color.soulaceAccent.opacity(0.35))

            Text("No upcoming sessions")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.soulaceDark.opacity(0.55))

            Text("Schedule a session so your group\ncan practice together")
                .font(.system(size: 13))
                .foregroundColor(Color.soulaceDark.opacity(0.4))
                .multilineTextAlignment(.center)

            Button(action: { vm.showCreateSession = true }) {
                Text("Schedule a Session")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(Color.soulaceAccent)
                            .shadow(color: Color.soulaceAccent.opacity(0.3), radius: 6, x: 0, y: 3)
                    )
            }
            .buttonStyle(SoulaceScaleButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
    }
}

// MARK: - Session Row Card
struct SessionRowCard: View {
    let session: YogaSession
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 14) {
            // Date block
            VStack(spacing: 1) {
                Text(monthAbbr)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.soulaceAccent)
                    .textCase(.uppercase)
                Text(dayNumber)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.soulaceDark)
            }
            .frame(width: 40)

            Rectangle()
                .fill(Color.soulaceMint.opacity(0.6))
                .frame(width: 1.5, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.groupName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.soulaceDark)
                Text(session.timeRangeString)
                    .font(.system(size: 12))
                    .foregroundColor(Color.soulaceDark.opacity(0.5))
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(session.durationMinutes) min")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color.soulaceAccent.opacity(0.8))
            }

            Spacer()

            // Join button
            if let user = appState.currentUser {
                NavigationLink(destination: CallView(session: session, currentUser: user)) {
                    Text("Join")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.soulaceAccent)
                                .shadow(color: Color.soulaceAccent.opacity(0.3),
                                        radius: 5, x: 0, y: 3)
                        )
                }
                .buttonStyle(SoulaceScaleButtonStyle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }

    private var monthAbbr: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: session.scheduledDate)
    }

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: session.scheduledDate)
    }
}
