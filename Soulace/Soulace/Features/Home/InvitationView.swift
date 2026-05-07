//
//  InvitationView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 06/05/26.
//

import SwiftUI
import Combine

// MARK: - Invitations View
struct InvitationsView: View {
    @StateObject private var vm: InvitationsViewModel
    @Environment(\.dismiss) private var dismiss

    init(userID: String) {
        _vm = StateObject(wrappedValue: InvitationsViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5F8F6").ignoresSafeArea()
                
                if vm.invitations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No invitations")
                            .foregroundColor(.gray.opacity(0.6))
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(vm.invitations) { invite in
                                InvitationCard(
                                    invite: invite,
                                    isExpanded: vm.expandedID == invite.id,
                                    loadingID: vm.loadingID,
                                    onToggle: { vm.toggle(invite) },
                                    onAccept: { vm.accept(invite) },
                                    onDecline: { vm.decline(invite) }
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            // ✅ CUSTOM TITLE (warna beda)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Text("Accept Invitations")
                            .foregroundColor(.black)

                        Text("(\(vm.invitations.count))")
                            .foregroundColor(Color(hex: "2F453B"))
                    }
                    .font(.system(size: 17, weight: .semibold))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                }
            }

            // navbar styling biar clean putih
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
}

// MARK: - Invitation Card
struct InvitationCard: View {
    let invite: GroupInvitation
    let isExpanded: Bool
    let loadingID: String?

    let onToggle: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 12) {

            // HEADER
            Button(action: onToggle) {
                HStack {
                    Text(invite.groupName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            // DIVIDER
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1)

            // CONTENT
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }

    // MARK: - Collapsed
    private var collapsedContent: some View {
        HStack {
            Text("Members")
                .font(.system(size: 13))
                .foregroundColor(.gray)

            Spacer()

            avatarStack

            Spacer()

            actionButtons
        }
    }

    // MARK: - Expanded
    private var expandedContent: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Members")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                memberRow(name: invite.fromName)
            }

            actionButtons
        }
    }

    // MARK: - Avatar
    private var avatarStack: some View {
        HStack(spacing: -10) {
            Circle()
                .fill(Color.soulaceAccent.opacity(0.15))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(initials(from: invite.fromName))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.soulaceAccent)
                )
        }
    }

    // MARK: - Member Row
    private func memberRow(name: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.soulaceAccent.opacity(0.15))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(initials(from: name))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.soulaceAccent)
                )

            Text(name)
                .font(.system(size: 14))
                .foregroundColor(.black)

            Spacer()
        }
    }

    // MARK: - Buttons
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: onDecline) {
                Text("Reject")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .clipShape(Capsule())
            }

            Button(action: onAccept) {
                Text("Accept")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "2F453B"))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Helpers
    private func initials(from name: String) -> String {
        name
            .components(separatedBy: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map { String($0) }
            .joined()
    }
}

// MARK: - ViewModel
final class InvitationsViewModel: ObservableObject {
    @Published var invitations: [GroupInvitation] = []
    @Published var expandedID: String? = nil
    @Published var loadingID: String? = nil

    private let service = GroupInvitationService.shared
    private var cancellables = Set<AnyCancellable>()

    init(userID: String) {
        service.observeInvitations(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] in self?.invitations = $0 })
            .store(in: &cancellables)
    }

    func toggle(_ invite: GroupInvitation) {
        if expandedID == invite.id {
            expandedID = nil
        } else {
            expandedID = invite.id
        }
    }

    func accept(_ invite: GroupInvitation) {
        loadingID = invite.id
        Task {
            try? await service.accept(invite)
            await MainActor.run { self.loadingID = nil }
        }
    }

    func decline(_ invite: GroupInvitation) {
        loadingID = invite.id
        Task {
            try? await service.decline(invite)
            await MainActor.run { self.loadingID = nil }
        }
    }
}
