//
//  CreateSessionView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI

struct CreateSessionView: View {
    @StateObject private var vm: CreateSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    init(groups: [YogaGroup]) {
        _vm = StateObject(wrappedValue: CreateSessionViewModel(groups: groups))
    }

    var body: some View {
        ZStack {
            Color(hex: "F5F8F6").ignoresSafeArea()

            if let session = vm.createdSession {
                SessionCreatedView(session: session) { dismiss() }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Group picker
                        groupPickerSection

                        // Duration picker — 10 / 15 / 20 / 30 min
                        durationSection

                        // Date & Time
                        dateTimeSection

                        // Video picker
                        videoPickerSection

                        // Error
                        if let error = vm.errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        SoulacePrimaryButton(
                            title: "Create Session",
                            icon: "video.fill",
                            isLoading: vm.isLoading,
                            isDisabled: !vm.canCreate
                        ) {
                            Task { await vm.createSession() }
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Create a Video Call")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $vm.showVideoLibrary) {
            VideoLibraryView { video in
                vm.selectedVideo = video
                vm.showVideoLibrary = false
            }
        }
    }

    // MARK: - Group Picker
    private var groupPickerSection: some View {
        SectionCard(title: "Select Group", icon: "person.2.fill") {
            if vm.groups.isEmpty {
                Text("No groups yet — create a group first")
                    .font(.system(size: 14))
                    .foregroundColor(Color.soulaceDark.opacity(0.5))
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.groups) { group in
                            GroupChip(
                                group: group,
                                isSelected: vm.selectedGroup?.id == group.id
                            ) {
                                vm.selectedGroup = group
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    // MARK: - Duration Picker
    private var durationSection: some View {
        SectionCard(title: "Session Duration", icon: "clock.fill") {
            HStack(spacing: 10) {
                ForEach(vm.durationOptions, id: \.self) { duration in
                    DurationChip(
                        duration: duration,
                        isSelected: vm.selectedDuration == duration
                    ) {
                        vm.selectedDuration = duration
                    }
                }
            }
        }
    }

    // MARK: - Date & Time
    private var dateTimeSection: some View {
        SectionCard(title: "Schedule", icon: "calendar") {
            VStack(spacing: 14) {
                HStack {
                    Text("Date")
                        .font(.system(size: 14))
                        .foregroundColor(Color.soulaceDark.opacity(0.55))
                    Spacer()
                    DatePicker("", selection: $vm.scheduledDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.soulaceAccent)
                }

                Divider()

                HStack {
                    Text("Time")
                        .font(.system(size: 14))
                        .foregroundColor(Color.soulaceDark.opacity(0.55))
                    Spacer()
                    DatePicker("", selection: $vm.scheduledTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(Color.soulaceAccent)
                }
            }
        }
    }

    // MARK: - Video Picker
    private var videoPickerSection: some View {
        SectionCard(title: "Yoga Video", icon: "play.rectangle.fill") {
            if let video = vm.selectedVideo {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.soulaceMint.opacity(0.5))
                        .frame(width: 56, height: 42)
                        .overlay(
                            Image(systemName: "play.fill")
                                .foregroundColor(Color.soulaceAccent)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.soulaceDark)
                            .lineLimit(1)
                        Text("\(video.durationMinutes) min · \(video.level.rawValue)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.soulaceDark.opacity(0.5))
                    }

                    Spacer()

                    Button(action: { vm.showVideoLibrary = true }) {
                        Text("Change")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.soulaceAccent)
                    }
                }
            } else {
                Button(action: { vm.showVideoLibrary = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.soulaceAccent)
                        Text("Select a yoga video")
                            .font(.system(size: 14))
                            .foregroundColor(Color.soulaceAccent)
                        Spacer()
                        Text("Optional")
                            .font(.system(size: 11))
                            .foregroundColor(Color.soulaceDark.opacity(0.35))
                    }
                }
                .buttonStyle(SoulaceScaleButtonStyle())
            }
        }
    }
}

// MARK: - Section Card
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(Color.soulaceAccent)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.soulaceDark.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }
}

// MARK: - Duration Chip
struct DurationChip: View {
    let duration: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text("\(duration)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color.soulaceDark)
                Text("min")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : Color.soulaceDark.opacity(0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.soulaceAccent : Color.soulaceAccent.opacity(0.08))
                    .shadow(color: isSelected ? Color.soulaceAccent.opacity(0.35) : .clear,
                            radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(SoulaceScaleButtonStyle())
    }
}

// MARK: - Group Chip
struct GroupChip: View {
    let group: YogaGroup
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(group.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color.soulaceDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.soulaceAccent : Color.soulaceAccent.opacity(0.1))
                )
        }
        .buttonStyle(SoulaceScaleButtonStyle())
    }
}

// MARK: - Session Created Success
struct SessionCreatedView: View {
    let session: YogaSession
    let onDone: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.soulaceAccent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 46))
                    .foregroundColor(Color.soulaceAccent)
            }
            .scaleEffect(appeared ? 1.0 : 0.4)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Session Scheduled!")
                    .font(.custom("Georgia-Bold", size: 24))
                    .foregroundColor(Color.soulaceDark)
                Text("\(session.scheduledDate.dateString)")
                    .font(.system(size: 15))
                    .foregroundColor(Color.soulaceAccent)
                Text("\(session.timeRangeString) · \(session.durationMinutes) min")
                    .font(.system(size: 14))
                    .foregroundColor(Color.soulaceDark.opacity(0.5))
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(Color.soulaceAccent)
                Text("Added to your calendar")
                    .font(.system(size: 13))
                    .foregroundColor(Color.soulaceDark.opacity(0.5))
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            SoulacePrimaryButton(title: "Back to Home") { onDone() }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
        }
    }
}
