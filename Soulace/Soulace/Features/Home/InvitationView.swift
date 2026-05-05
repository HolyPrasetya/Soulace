//
//  InvitationView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 06/05/26.
//

import SwiftUI
import Combine

// MARK: - InvitationsView
// Sheet yang muncul dari HomeView saat ada pending invitations
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
                            .foregroundColor(Color.soulaceAccent.opacity(0.3))
                        Text("No pending invitations")
                            .font(.system(size: 15))
                            .foregroundColor(Color.soulaceDark.opacity(0.4))
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(vm.invitations) { invite in
                                InvitationCard(
                                    invite:   invite,
                                    isLoading: vm.loadingID == invite.id,
                                    onAccept: { vm.accept(invite) },
                                    onDecline: { vm.decline(invite) }
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.soulaceMint, Color.soulaceSage],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 46, height: 46)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.soulaceAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(invite.groupName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.soulaceDark)
                    Text("Invited by \(invite.fromName.components(separatedBy: " ").first ?? invite.fromName)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.soulaceDark.opacity(0.5))
                }

                Spacer()
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView().tint(Color.soulaceAccent)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 10) {
                    // Decline
                    Button(action: onDecline) {
                        Text("Decline")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.soulaceDark.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.soulaceDark.opacity(0.07))
                            )
                    }
                    .buttonStyle(SoulaceScaleButtonStyle())

                    // Accept
                    Button(action: onAccept) {
                        Text("Accept")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.soulaceAccent)
                                    .shadow(color: Color.soulaceAccent.opacity(0.3),
                                            radius: 6, x: 0, y: 3)
                            )
                    }
                    .buttonStyle(SoulaceScaleButtonStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - InvitationsViewModel
final class InvitationsViewModel: ObservableObject {
    @Published var invitations: [GroupInvitation] = []
    @Published var loadingID: String?             = nil

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
