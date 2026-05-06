//
//  InvitationView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 06/05/26.
//


import SwiftUI
import Combine
import FirebaseCore

// MARK: - InvitationsView
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
                    VStack(spacing: 14) {
                        Image(systemName: "envelope.open")
                            .font(.system(size: 44))
                            .foregroundColor(Color.soulaceAccent.opacity(0.25))
                        Text("No pending invitations")
                            .font(.system(size: 15))
                            .foregroundColor(Color.soulaceDark.opacity(0.4))
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(vm.invitations) { invite in
                                InvitationCard(
                                    invite:    invite,
                                    isLoading: vm.loadingID == invite.id,
                                    onAccept:  { vm.accept(invite) },
                                    onDecline: { vm.decline(invite) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Accept Invitations\(vm.invitations.isEmpty ? "" : " (\(vm.invitations.count))")")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "2F453B"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                }
            }
        }
    }
}

// MARK: - InvitationCard
struct InvitationCard: View {
    let invite:    GroupInvitation
    let isLoading: Bool
    let onAccept:  () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Top: invited by + from name ──
            HStack(spacing: 8) {
                Text(invite.createdAt.dateValue().shortDateString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.soulaceDark.opacity(0.5))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.soulaceDark.opacity(0.07)))

                Text("Invited by \(invite.fromName.components(separatedBy: " ").first ?? invite.fromName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.soulaceDark.opacity(0.5))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.soulaceDark.opacity(0.07)))

                Spacer()
            }

            // ── Group name ──
            Text(invite.groupName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.soulaceDark)

            // ── Starting in ──
            VStack(alignment: .leading, spacing: 2) {
                Text("Group invitation")
                    .font(.system(size: 12))
                    .foregroundColor(Color.soulaceDark.opacity(0.4))
                Text("Join \(invite.groupName) to practice together")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.soulaceAccent)
            }

            // ── Buttons ──
            if isLoading {
                HStack { Spacer(); ProgressView().tint(Color.soulaceAccent); Spacer() }
                    .padding(.vertical, 4)
            } else {
                HStack(spacing: 10) {
                    Button(action: onDecline) {
                        Text("Reject")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "E05C5C"))
                            )
                    }
                    .buttonStyle(SoulaceScaleButtonStyle())

                    Button(action: onAccept) {
                        Text("Accept")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.soulaceAccent)
                            )
                    }
                    .buttonStyle(SoulaceScaleButtonStyle())
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}

// MARK: - InvitationsViewModel
final class InvitationsViewModel: ObservableObject {
    @Published var invitations: [GroupInvitation] = []
    @Published var loadingID:   String?           = nil

    private let service      = GroupInvitationService.shared
    private var cancellables = Set<AnyCancellable>()

    init(userID: String) {
        service.observeInvitations(userID: userID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] in self?.invitations = $0 })
            .store(in: &cancellables)
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
