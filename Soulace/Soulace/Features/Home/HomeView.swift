import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Int = 0
    @State private var appeared = false
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    stops: [
                        .init(color: .soulacePeach, location: 0.0),
                        .init(color: .soulaceSage,  location: 0.45),
                        .init(color: .soulaceMint,  location: 1.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Blobs
                Circle()
                    .fill(Color.soulaceMint.opacity(0.4))
                    .frame(width: 250, height: 250)
                    .blur(radius: 55)
                    .offset(x: -100, y: -200)
                    .allowsHitTesting(false)

                Circle()
                    .fill(Color.soulacePeach.opacity(0.45))
                    .frame(width: 180, height: 180)
                    .blur(radius: 45)
                    .offset(x: 130, y: 220)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 16)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -12)

                        // Upcoming sessions strip
                        if !vm.upcomingSessions.isEmpty {
                            upcomingSection
                                .padding(.top, 24)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                        }

                        // Quick actions
                        quickActionsSection
                            .padding(.top, 24)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)

                        // Groups section
                        groupsSection
                            .padding(.top, 28)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $vm.showCreateGroup) {
                CreateGroupView { vm.fetchGroups() }
            }
            .sheet(isPresented: $vm.showJoinSession) {
                JoinSessionView()
            }
            .sheet(isPresented: $vm.showInvitations) {
                if let userID = vm.currentUser?.id {
                    InvitationsView(userID: userID)
                }
            }
            .confirmationDialog(
                vm.currentUser?.fullName ?? "Account",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) { vm.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {

            // ── Kiri: Avatar + nama ──
            Button(action: { showLogoutConfirm = true }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 42, height: 42)
                        Text(vm.currentUser?.initials ?? "?")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.soulaceAccent)
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.currentUser?.fullName.components(separatedBy: " ").first ?? "Friend")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.soulaceDark)
                        Text(vm.greetingText)
                            .font(.system(size: 11))
                            .foregroundColor(Color.soulaceDark.opacity(0.5))
                    }
                }
            }
            .buttonStyle(SoulaceScaleButtonStyle())

            Spacer()

//            // ── Tengah: Logo Soulace ──
//            HStack(spacing: 6) {
//                Image("SecondarySoulace")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 26, height: 26)
//                    .clipShape(RoundedRectangle(cornerRadius: 7))
//                Text("Soulace")
//                    .font(.custom("Georgia", size: 17))
//                    .fontWeight(.semibold)
//                    .foregroundColor(Color.soulaceDark)
//            }
//
//            Spacer()

            // ── Kanan: Bell invitation ──
            Button(action: { vm.showInvitations = true }) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 42, height: 42)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.soulaceDark.opacity(0.65))
                    }
                    .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))

                    if !vm.pendingInvitations.isEmpty {
                        ZStack {
                            Circle().fill(Color.red).frame(width: 17, height: 17)
                            Text("\(vm.pendingInvitations.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: 3, y: -3)
                    }
                }
            }
            .buttonStyle(SoulaceScaleButtonStyle())
        }
    }

    // MARK: - Upcoming Sessions
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.soulaceDark.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.upcomingSessions.prefix(5)) { session in
                        UpcomingSessionCard(session: session)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            // Create Video Call
            NavigationLink(destination: CreateSessionView(groups: vm.groups)) {
                QuickActionCard(
                    gradient: [Color.soulaceDark, Color(hex: "3D6059")],
                    icon: "video.fill",
                    iconColor: .white,
                    iconBg: Color.white.opacity(0.15),
                    title: "Create a Video Call",
                    subtitle: "Start an instant yoga session",
                    titleColor: .white,
                    subtitleColor: .white.opacity(0.65),
                    chevronColor: .white.opacity(0.5)
                )
            }
            .buttonStyle(SoulaceScaleButtonStyle())

            // Join Yoga
            Button(action: { vm.showJoinSession = true }) {
                QuickActionCard(
                    gradient: [Color.white.opacity(0.75), Color.white.opacity(0.55)],
                    icon: "person.2.fill",
                    iconColor: Color.soulaceAccent,
                    iconBg: Color.soulaceAccent.opacity(0.12),
                    title: "Join Yoga",
                    subtitle: "Join a live yoga session",
                    titleColor: Color.soulaceDark,
                    subtitleColor: Color.soulaceDark.opacity(0.5),
                    chevronColor: Color.soulaceAccent.opacity(0.5),
                    showCodeField: true
                )
            }
            .buttonStyle(SoulaceScaleButtonStyle())
        }
    }

    // MARK: - Groups
    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Yoga Session")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.soulaceDark)

                Spacer()

                Button(action: { vm.showCreateGroup = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New Group")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.soulaceAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.soulaceAccent.opacity(0.12))
                    )
                }
            }

            if vm.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(Color.soulaceAccent)
                    Spacer()
                }
                .padding(.vertical, 30)
            } else if vm.groups.isEmpty {
                EmptyGroupsView { vm.showCreateGroup = true }
            } else {
                VStack(spacing: 12) {
                    ForEach(vm.groups) { group in
                        NavigationLink(destination: GroupDetailView(group: group)) {
                            GroupRowCard(group: group,
                                        session: vm.upcomingSessions.first { $0.groupID == group.id })
                        }
                        .buttonStyle(SoulaceScaleButtonStyle())
                    }
                }
            }
        }
    }
}

// MARK: - Upcoming Session Card
struct UpcomingSessionCard: View {
    let session: YogaSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.soulaceAccent)
                    .frame(width: 7, height: 7)
                Text(session.scheduledDate.relativeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.soulaceAccent)
            }

            Text(session.groupName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.soulaceDark)
                .lineLimit(1)

            Text(session.timeRangeString)
                .font(.system(size: 12))
                .foregroundColor(Color.soulaceDark.opacity(0.55))

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(Color.soulaceAccent)
                Text("\(session.durationMinutes) min")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.soulaceDark.opacity(0.6))
            }
        }
        .padding(14)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - Quick Action Card
struct QuickActionCard: View {
    let gradient: [Color]
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let subtitle: String
    let titleColor: Color
    let subtitleColor: Color
    let chevronColor: Color
    var showCodeField: Bool = false
    @State private var codeText = ""

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(titleColor)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(subtitleColor)

                if showCodeField {
                    HStack(spacing: 5) {
                        Image(systemName: "number")
                            .font(.system(size: 10))
                            .foregroundColor(subtitleColor)
                        TextField("Enter code or link", text: $codeText)
                            .font(.system(size: 12))
                            .foregroundColor(Color.soulaceDark.opacity(0.7))
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.top, 3)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(chevronColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: gradient.first?.opacity(0.2) ?? .clear, radius: 10, x: 0, y: 5)
    }
}

// MARK: - Group Row Card
struct GroupRowCard: View {
    let group: YogaGroup
    let session: YogaSession?

    var body: some View {
        HStack(spacing: 14) {
            // Avatar stack (placeholder)
            ZStack {
                ForEach(0..<min(group.memberCount, 3), id: \.self) { i in
                    Circle()
                        .fill(avatarColors[i % avatarColors.count])
                        .frame(width: 32, height: 32)
                        .offset(x: CGFloat(i) * 14)
                }
            }
            .frame(width: 60, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.soulaceDark)

                if let session {
                    Text("\(session.scheduledDate.shortDateString) · \(session.timeRangeString)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.soulaceDark.opacity(0.55))
                } else {
                    Text("\(group.memberCount) members · \(group.inviteCode)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.soulaceDark.opacity(0.55))
                }
            }

            Spacer()

            if session != nil {
                Text("Join Now")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.soulaceAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.soulaceAccent.opacity(0.12))
                    )
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(Color.soulaceDark.opacity(0.3))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private let avatarColors: [Color] = [
        Color(hex: "D1E3E3"), Color(hex: "EEF4D0"), Color(hex: "FFEEE0"),
        Color(hex: "4A7C6F"), Color(hex: "7A9E97")
    ]
}

// MARK: - Empty Groups
struct EmptyGroupsView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.soulaceAccent.opacity(0.4))

            Text("No groups yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.soulaceDark)

            Text("Create a group to start practicing with friends")
                .font(.system(size: 13))
                .foregroundColor(Color.soulaceDark.opacity(0.5))
                .multilineTextAlignment(.center)

            Button(action: onCreate) {
                Text("Create a Group")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.soulaceAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color.soulaceAccent.opacity(0.12))
                    )
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.6))
        )
    }
}
