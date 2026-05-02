import SwiftUI

// MARK: - JoinSessionView
struct JoinSessionView: View {
    @StateObject private var vm   = JoinSessionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.961, green: 0.973, blue: 0.965).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                        codeInputSection
                        errorSection
                        recentGroupsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Join Yoga")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Join Yoga")
                .font(.custom("Georgia-Bold", size: 26))
                .foregroundColor(Color.soulaceDark)
            Text("Enter the invitation link or code\nfrom your friend")
                .font(.system(size: 14))
                .foregroundColor(Color.soulaceDark.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    // MARK: - Code Input
    private var codeInputSection: some View {
        HStack(spacing: 12) {
            TextField("Paste link or enter code", text: $vm.codeOrLink)
                .font(.system(size: 15))
                .foregroundColor(Color.soulaceDark)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .submitLabel(.go)
                .onSubmit { Task { await vm.joinWithCode() } }

            Button(action: { Task { await vm.joinWithCode() } }) {
                ZStack {
                    Circle()
                        .fill(vm.canJoin ? Color.soulaceAccent : Color.soulaceAccent.opacity(0.35))
                        .frame(width: 42, height: 42)
                        .shadow(
                            color: vm.canJoin ? Color.soulaceAccent.opacity(0.35) : .clear,
                            radius: 6, x: 0, y: 3
                        )

                    if vm.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(!vm.canJoin || vm.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Error
    @ViewBuilder
    private var errorSection: some View {
        if let error = vm.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.85))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.07))
            )
        }
    }

    // MARK: - Recent Groups
    @ViewBuilder
    private var recentGroupsSection: some View {
        if !vm.recentGroups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(0.8)

                VStack(spacing: 0) {
                    ForEach(vm.recentGroups) { group in
                        RecentGroupRow(group: group)
                        if group.id != vm.recentGroups.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
                )
            }
        }
    }
}

// MARK: - Recent Group Row
struct RecentGroupRow: View {
    let group: YogaGroup

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.soulaceMint.opacity(0.6))
                    .frame(width: 42, height: 42)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.soulaceAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.soulaceDark)
                Text(group.inviteCode)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color.soulaceDark.opacity(0.4))
                    .tracking(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color.soulaceDark.opacity(0.2))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
