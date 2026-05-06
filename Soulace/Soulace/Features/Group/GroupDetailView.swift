//
//  GroupDetailView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI
import Combine

// MARK: - GroupDetailView
struct GroupDetailView: View {
    @StateObject private var vm: GroupDetailViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

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
                    groupActionButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // Invite copied toast
            if vm.showInviteCopied {
                inviteCopiedToast
            }
        }
        .navigationTitle(vm.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // ── Invite Member button (semua member bisa invite) ──
                    Button(action: { vm.showInviteMember = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 12, weight: .bold))
                            Text("Invite")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color.soulaceAccent)
                    }

                    // Add Session button
                    Button(action: { vm.showCreateSession = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                            Text("Session").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color.soulaceAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showCreateSession, onDismiss: { vm.fetchSessions() }) {
            CreateSessionView(groups: [vm.group])
        }
        // ── Invite Member sheet ──
        .sheet(isPresented: $vm.showInviteMember) {
            InviteMemberView(group: vm.group)
        }
        .alert("Delete Group", isPresented: $vm.showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await vm.deleteGroup() } }
        } message: {
            Text("This will permanently delete \"\(vm.group.name)\" and all its sessions. This cannot be undone.")
        }
        .alert("Leave Group", isPresented: $vm.showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) { Task { await vm.leaveGroup() } }
        } message: {
            Text("You will no longer have access to \"\(vm.group.name)\".")
        }
        .onChange(of: vm.groupDeleted) { deleted in
            if deleted { dismiss() }
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Group Header
    private var inviteCopiedToast: some View {
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
            .background(inviteCopiedToastBackground)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 32)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.showInviteCopied)
    }

    private var inviteCopiedToastBackground: some View {
        Capsule()
            .fill(Color.soulaceAccent)
            .shadow(color: Color.soulaceAccent.opacity(0.4), radius: 10, x: 0, y: 4)
    }

    // MARK: - Group Header
    private var groupHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.soulaceMint, Color.soulaceSage],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 74, height: 74)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 28)).foregroundColor(Color.soulaceAccent)
            }
            VStack(spacing: 5) {
                Text(vm.group.name)
                    .font(.system(size: 22, weight: .bold)).foregroundColor(Color.soulaceDark)
                if !vm.group.description.isBlank {
                    Text(vm.group.description)
                        .font(.system(size: 14)).foregroundColor(Color.soulaceDark.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                Text(vm.memberLabel)
                    .font(.system(size: 13, weight: .medium)).foregroundColor(Color.soulaceAccent)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(Color.soulaceAccent.opacity(0.1)))
            }
        }
        .frame(maxWidth: .infinity).padding(22)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4))
    }

    // MARK: - Invite Code Card
    private var inviteCodeCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Invite Code")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.4))
                    .textCase(.uppercase).tracking(0.6)
                Text(vm.group.inviteCode)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.soulaceAccent).tracking(3)
            }
            Spacer()
            Button(action: { vm.copyInviteCode() }) {
                Label("Copy", systemImage: "doc.on.doc.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.soulaceAccent)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(Color.soulaceAccent.opacity(0.1)))
            }
            .buttonStyle(SoulaceScaleButtonStyle())
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2))
    }

    // MARK: - Sessions Section
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Upcoming Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.45))
                    .textCase(.uppercase).tracking(0.6)
                Spacer()
                Text("\(vm.sessions.count)")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Color.soulaceAccent)
            }
            if vm.isLoading {
                HStack { Spacer(); ProgressView().tint(Color.soulaceAccent); Spacer() }
                    .padding(.vertical, 28)
            } else if vm.sessions.isEmpty {
                emptySessionsView
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.sessions) { session in SessionRowCard(session: session) }
                }
            }
        }
    }

    private var emptySessionsView: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 38)).foregroundColor(Color.soulaceAccent.opacity(0.35))
            Text("No upcoming sessions")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(Color.soulaceDark.opacity(0.55))
            Text("Schedule a session so your group\ncan practice together")
                .font(.system(size: 13)).foregroundColor(Color.soulaceDark.opacity(0.4))
                .multilineTextAlignment(.center)
            Button(action: { vm.showCreateSession = true }) {
                Text("Schedule a Session")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 11)
                    .background(Capsule().fill(Color.soulaceAccent)
                        .shadow(color: Color.soulaceAccent.opacity(0.3), radius: 6, x: 0, y: 3))
            }
            .buttonStyle(SoulaceScaleButtonStyle())
        }
        .frame(maxWidth: .infinity).padding(28)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.7)))
    }

    // MARK: - Delete / Leave Button
    private var groupActionButton: some View {
        Button(action: {
            if vm.isCreator { vm.showDeleteConfirm = true }
            else            { vm.showLeaveConfirm  = true }
        }) {
            HStack(spacing: 10) {
                if vm.isDeleting {
                    ProgressView().tint(.red).scaleEffect(0.85)
                } else {
                    Image(systemName: vm.groupActionIcon).font(.system(size: 15))
                }
                Text(vm.isDeleting ? "Please wait..." : vm.groupActionLabel)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.red.opacity(0.07)))
        }
        .buttonStyle(SoulaceScaleButtonStyle())
        .disabled(vm.isDeleting)
    }
}

// MARK: - Session Row Card
struct SessionRowCard: View {
    let session: YogaSession
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(monthAbbr).font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.soulaceAccent).textCase(.uppercase)
                Text(dayNumber).font(.system(size: 22, weight: .bold)).foregroundColor(Color.soulaceDark)
            }
            .frame(width: 40)
            Rectangle().fill(Color.soulaceMint.opacity(0.6)).frame(width: 1.5, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.groupName)
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(Color.soulaceDark)
                Text(session.timeRangeString)
                    .font(.system(size: 12)).foregroundColor(Color.soulaceDark.opacity(0.5))
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 10))
                    Text("\(session.durationMinutes) min").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color.soulaceAccent.opacity(0.8))
            }
            Spacer()
            if let user = appState.currentUser {
                NavigationLink(destination: CallView(session: session, currentUser: user)) {
                    Text("Join")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Capsule().fill(Color.soulaceAccent)
                            .shadow(color: Color.soulaceAccent.opacity(0.3), radius: 5, x: 0, y: 3))
                }
                .buttonStyle(SoulaceScaleButtonStyle())
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2))
    }

    private var monthAbbr: String { let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: session.scheduledDate) }
    private var dayNumber: String  { let f = DateFormatter(); f.dateFormat = "d";   return f.string(from: session.scheduledDate) }
}

// MARK: - InviteMemberView  ← BARU
// Sheet untuk search & invite user ke grup
struct InviteMemberView: View {
    let group: YogaGroup
    @StateObject private var vm: InviteMemberViewModel
    @Environment(\.dismiss) private var dismiss

    init(group: YogaGroup) {
        self.group = group
        _vm = StateObject(wrappedValue: InviteMemberViewModel(group: group))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5F8F6").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    ZStack(alignment: .leading) {
                        if vm.searchQuery.isEmpty {
                            Text("Search by name...")
                                .foregroundColor(Color.gray.opacity(0.5)) // abu samar
                                .font(.system(size: 15))
                        }

                        TextField("", text: $vm.searchQuery)
                            .font(.system(size: 15))
                            .foregroundColor(Color.soulaceDark)
                            .onChange(of: vm.searchQuery) { _ in
                                Task { await vm.searchUsers() }
                            }
                        
                        if !vm.searchQuery.isEmpty {
                            Button(action: { vm.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.soulaceDark.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2))
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)

                    // Results
                    if vm.isSearching {
                        Spacer()
                        ProgressView().tint(Color.soulaceAccent)
                        Spacer()
                    } else if vm.searchResults.isEmpty && !vm.searchQuery.isBlank {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 32)).foregroundColor(Color.soulaceDark.opacity(0.25))
                            Text("No users found").font(.system(size: 14))
                                .foregroundColor(Color.soulaceDark.opacity(0.4))
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(vm.searchResults) { user in
                                    InviteUserRow(
                                        user:     user,
                                        state:    vm.stateFor(user),
                                        onInvite: { vm.invite(user) }
                                    )
                                    if user.id != vm.searchResults.last?.id {
                                        Divider().padding(.leading, 68)
                                    }
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3))
                            .padding(.horizontal, 20)
                        }
                    }

                    // Success message
                    if let msg = vm.successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.soulaceAccent)
                            Text(msg).font(.system(size: 13)).foregroundColor(Color.soulaceDark.opacity(0.7))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color.soulaceAccent.opacity(0.08)))
                        .padding(.horizontal, 20).padding(.bottom, 12)
                    }
                }
            }
//            .navigationTitle("Invite to \(group.name)")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Done") { dismiss() }.foregroundColor(Color.soulaceAccent)
//                }
//            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Invite to \(group.name)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "2F453B"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - InviteUserRow
enum InviteUserState { case canInvite, sending, invited, alreadyMember }

struct InviteUserRow: View {
    let user:     SoulaceUser
    let state:    InviteUserState
    let onInvite: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.soulaceMint.opacity(0.5)).frame(width: 42, height: 42)
                Text(user.initials)
                    .font(.system(size: 15, weight: .bold)).foregroundColor(Color.soulaceAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.system(size: 15, weight: .medium)).foregroundColor(Color.soulaceDark)
                Text(user.email)
                    .font(.system(size: 12)).foregroundColor(Color.soulaceDark.opacity(0.4)).lineLimit(1)
            }
            Spacer()
            // Action button
            switch state {
            case .canInvite:
                Button(action: onInvite) {
                    Text("Invite")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Color.soulaceAccent)
                            .shadow(color: Color.soulaceAccent.opacity(0.3), radius: 4, x: 0, y: 2))
                }
                .buttonStyle(SoulaceScaleButtonStyle())

            case .sending:
                ProgressView().tint(Color.soulaceAccent).scaleEffect(0.8).frame(width: 50)

            case .invited:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                    Text("Invited").font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color.soulaceAccent)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Color.soulaceAccent.opacity(0.1)))

            case .alreadyMember:
                Text("Member")
                    .font(.system(size: 12)).foregroundColor(Color.soulaceDark.opacity(0.4))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(Color.soulaceDark.opacity(0.06)))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

// MARK: - InviteMemberViewModel
final class InviteMemberViewModel: ObservableObject {
    @Published var searchQuery:   String        = ""
    @Published var searchResults: [SoulaceUser] = []
    @Published var isSearching:   Bool          = false
    @Published var successMessage: String?      = nil

    // Track status per user: nil = canInvite, "sending" = loading, "invited" = done
    @Published private var userStates: [String: InviteUserState] = [:]

    private let group:             YogaGroup
    private let firestoreService  = FirestoreService.shared
    private let authService       = AuthService.shared
    private let invitationService = GroupInvitationService.shared

    init(group: YogaGroup) { self.group = group }

    // MARK: - State helper
    func stateFor(_ user: SoulaceUser) -> InviteUserState {
        guard let id = user.id else { return .canInvite }
        if group.memberIDs.contains(id) { return .alreadyMember }
        return userStates[id] ?? .canInvite
    }

    // MARK: - Search users
    @MainActor
    func searchUsers() async {
        guard !searchQuery.isBlank else { searchResults = []; return }
        isSearching = true
        do {
            let results = try await firestoreService.searchUsers(query: searchQuery)
            // Exclude self
            searchResults = results.filter { $0.id != authService.currentUser?.id }
        } catch { /* ignore */ }
        isSearching = false
    }

    // MARK: - Send invite
    func invite(_ user: SoulaceUser) {
        guard let userID = user.id,
              let currentUser = authService.currentUser else { return }

        userStates[userID] = .sending
        Task {
            do {
                try await invitationService.sendInvitation(
                    group:    group,
                    fromUser: currentUser,
                    toUserID: userID
                )
                await MainActor.run {
                    self.userStates[userID] = .invited
                    self.successMessage     = "Invitation sent to \(user.fullName.components(separatedBy: " ").first ?? user.fullName)!"
                    // Auto-hide success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.successMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.userStates[userID] = .canInvite
                }
            }
        }
    }
}
