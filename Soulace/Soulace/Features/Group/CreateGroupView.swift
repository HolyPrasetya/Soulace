//
//  CreateGroupView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI

struct CreateGroupView: View {
    @StateObject private var vm = CreateGroupViewModel()
    @Environment(\.dismiss) private var dismiss
    var onCreated: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5F8F6").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if vm.isCreated, let group = vm.createdGroup {
                            GroupCreatedSuccessView(group: group) {
                                onCreated?()
                                dismiss()
                            }
                        } else {
                            formContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Create a Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                        .font(.system(size: 15))
                }
            }
        }
    }

    // MARK: - Form
    private var formContent: some View {
        VStack(spacing: 20) {
            // Group Name
            FormField(label: "Group Name", isRequired: true) {
                TextField("YO-GAnkz", text: $vm.groupName)
                    .font(.system(size: 15))
                    .foregroundColor(Color.soulaceDark)
            }

            // Group Description
            FormField(label: "Group Description") {
                TextField("Yoga Morning Session Guys", text: $vm.groupDescription)
                    .font(.system(size: 15))
                    .foregroundColor(Color.soulaceDark)
            }

            // Add Members
            VStack(alignment: .leading, spacing: 10) {
                Text("Add Members")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.6))

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.soulaceDark.opacity(0.4))
                    TextField("Search Friends", text: $vm.searchQuery)
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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                )

                // Selected members chips
                if !vm.selectedMembers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(vm.selectedMembers) { member in
                                MemberChip(user: member) { vm.toggleMember(member) }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }

                // ── Bug 2 Fix: Contacts sync with feedback ──
                if vm.searchQuery.isBlank && vm.searchResults.isEmpty {
                    VStack(spacing: 10) {
                        // Sync button
                        Button(action: { vm.requestContactsSync() }) {
                            HStack(spacing: 8) {
                                if vm.isSyncingContacts {
                                    ProgressView()
                                        .tint(Color.soulaceAccent)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 15))
                                }
                                Text(vm.isSyncingContacts ? "Syncing..." : "Sync Contacts")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(Color.soulaceAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.soulaceAccent.opacity(0.1))
                            )
                        }
                        .disabled(vm.isSyncingContacts)

                        // Sync result message
                        if let msg = vm.contactSyncMessage {
                            HStack(spacing: 6) {
                                Image(systemName: msg.contains("Found") ? "checkmark.circle.fill" : "info.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(msg.contains("Found") ? Color.soulaceAccent : .orange)
                                Text(msg)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.soulaceDark.opacity(0.65))
                            }
                            .padding(.horizontal, 4)
                        }

                        if vm.contactSyncMessage == nil {
                            Text("Looks like you don't have the friend list")
                                .font(.system(size: 13))
                                .foregroundColor(Color.soulaceDark.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                // Search / Sync results
                if !vm.searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(vm.searchResults) { user in
                            MemberSearchRow(
                                user:       user,
                                isSelected: vm.isSelected(user)
                            ) {
                                vm.toggleMember(user)
                            }
                            if user.id != vm.searchResults.last?.id {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                    )
                }
            }

            // Error
            if let error = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.07)))
            }

            Spacer().frame(height: 8)

            SoulacePrimaryButton(
                title:      "Create Group",
                isLoading:  vm.isLoading,
                isDisabled: !vm.canCreate
            ) {
                Task { await vm.createGroup() }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Form Field
struct FormField<Content: View>: View {
    let label: String
    var isRequired: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.6))
                if isRequired {
                    Text("*").foregroundColor(Color.soulaceAccent)
                        .font(.system(size: 13, weight: .bold))
                }
            }
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                )
        }
    }
}

// MARK: - Member Search Row
struct MemberSearchRow: View {
    let user: SoulaceUser
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.soulaceMint)
                        .frame(width: 38, height: 38)
                    Text(user.initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.soulaceDark)
                }
                Text(user.fullName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.soulaceDark)
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.soulaceAccent : Color.gray.opacity(0.15))
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(SoulaceScaleButtonStyle())
    }
}

// MARK: - Member Chip
struct MemberChip: View {
    let user: SoulaceUser
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(user.initials)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.soulaceAccent)
            Text(user.fullName.components(separatedBy: " ").first ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.soulaceDark)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.soulaceDark.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.soulaceAccent.opacity(0.1)))
    }
}

// MARK: - Group Created Success
struct GroupCreatedSuccessView: View {
    let group: YogaGroup
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.soulaceAccent.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.soulaceAccent)
            }
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Successfully Created")
                    .font(.system(size: 14))
                    .foregroundColor(Color.soulaceDark.opacity(0.5))
                Text(group.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Color.soulaceDark)
                Text("\(group.memberCount) Members")
                    .font(.system(size: 14))
                    .foregroundColor(Color.soulaceDark.opacity(0.55))
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            // Invite code card
            VStack(spacing: 6) {
                Text("Invite Code")
                    .font(.system(size: 12))
                    .foregroundColor(Color.soulaceDark.opacity(0.4))
                Text(group.inviteCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.soulaceAccent)
                    .tracking(4)
                Button(action: {
                    UIPasteboard.general.string = group.inviteCode
                }) {
                    Label("Copy Code", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.soulaceAccent)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.soulaceAccent.opacity(0.08))
            )
            .opacity(appeared ? 1 : 0)

            Spacer()

            SoulacePrimaryButton(title: "Schedule a Session") { onDone() }

            Button("Maybe Later") { onDone() }
                .font(.system(size: 14))
                .foregroundColor(Color.soulaceDark.opacity(0.4))
        }
        .padding(.top, 20)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}
