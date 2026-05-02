//
//  CallView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI
import AgoraRtcKit

struct CallView: View {
    @StateObject private var vm: CallViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: YogaSession, currentUser: SoulaceUser, video: VideoContent? = nil) {
        _vm = StateObject(wrappedValue: CallViewModel(
            session: session,
            currentUser: currentUser,
            video: video
        ))
    }

    var body: some View {
        ZStack {
            Color(hex: "111D19").ignoresSafeArea()

            VStack(spacing: 0) {
                callTopBar
                participantGrid
                    .padding(.horizontal, 3)
                    .padding(.top, 3)
                sessionInfoBar
                CallControlsView(
                    isMuted:     vm.isMuted,
                    isCameraOff: vm.isCameraOff,
                    onMic:       { vm.toggleMic() },
                    onCamera:    { vm.toggleCamera() },
                    onSwitch:    { vm.switchCamera() },
                    onVideo:     { vm.showVideoPlayer.toggle() },
                    onEnd:       { vm.leaveCall() }
                )
            }

            // Admit/Decline overlay
            if vm.showAdmitSheet, let entry = vm.pendingEntry {
                AdmitDeclineView(entry: entry,
                                 onAdmit:   { vm.admitParticipant(entry) },
                                 onDecline: { vm.declineParticipant(entry) })
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.joinCall() }
        .onDisappear { AgoraService.shared.leaveChannel() }
        .fullScreenCover(isPresented: $vm.isSessionEnded) {
            SessionSummaryView(summary: vm.buildSummary())
        }
        .sheet(isPresented: $vm.showVideoPlayer) {
            if let video = vm.selectedVideo {
                VideoPlayerView(video: video)
            }
        }
    }

    // MARK: - Top Bar
    private var callTopBar: some View {
        HStack {
            Button(action: { vm.leaveCall() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            VStack(spacing: 3) {
                Text(vm.session.groupName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Live · \(vm.participantCount) people")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // Waiting room badge
            Button(action: {}) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                    if !vm.waitingEntries.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 4, y: -4)
                    }
                }
                .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Participant Grid
    private var participantGrid: some View {
        let allParticipants = vm.participants
        let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]

        return LazyVGrid(columns: columns, spacing: 3) {
            // Local user tile
            LocalVideoTile(
                user: vm.currentUser,
                isMuted: vm.isMuted,
                isCameraOff: vm.isCameraOff,
                showShareButton: vm.isHost && vm.selectedVideo == nil,
                onShareTap: { vm.showVideoPlayer = true }
            )
            .aspectRatio(0.75, contentMode: .fit)

            // Remote participants (max 7)
            ForEach(allParticipants.prefix(AppConstants.Agora.maxParticipants - 1)) { participant in
                RemoteVideoTile(participant: participant)
                    .aspectRatio(0.75, contentMode: .fit)
            }

            // If too many — swipe indicator
            if vm.participantCount > 4 {
                TooManyParticipantsIndicator(count: vm.participantCount - 4)
                    .aspectRatio(0.75, contentMode: .fit)
            }
        }
    }

    // MARK: - Session Info Bar
    private var sessionInfoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.elapsedFormatted)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("\(vm.session.durationMinutes - (vm.sessionElapsed / 60)) min remaining")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Timer ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 36, height: 36)

                let progress = vm.durationSeconds > 0
                    ? Double(vm.sessionElapsed) / Double(vm.durationSeconds)
                    : 0

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.soulaceMint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))

                Text(vm.remainingFormatted)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Local Video Tile (UIViewRepresentable for Agora)
struct LocalVideoTile: View {
    let user: SoulaceUser
    let isMuted: Bool
    let isCameraOff: Bool
    var showShareButton: Bool = false
    var onShareTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))

            if isCameraOff {
                avatarView
            } else {
                AgoraLocalVideoView()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Overlays
            VStack {
                if showShareButton {
                    HStack {
                        Spacer()
                        Button(action: { onShareTap?() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 11))
                                Text("Share Video")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Color.soulaceDark)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.soulaceMint))
                        }
                        .padding(8)
                    }
                }
                Spacer()
                HStack {
                    nameTag(name: "You", isMuted: isMuted)
                    Spacer()
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var avatarView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.soulaceAccent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Text(user.initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.soulaceAccent)
            }
        }
    }
}

// MARK: - Remote Video Tile
struct RemoteVideoTile: View {
    let participant: CallParticipant

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))

            if participant.isCameraOff {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.soulaceMint.opacity(0.25))
                            .frame(width: 50, height: 50)
                        Text(participant.initials)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.soulaceMint)
                    }
                }
            } else {
                AgoraRemoteVideoView(uid: participant.agoraUID)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack {
                Spacer()
                HStack {
                    nameTag(name: participant.name, isMuted: participant.isMuted)
                    Spacer()
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Shared name tag
func nameTag(name: String, isMuted: Bool) -> some View {
    HStack(spacing: 4) {
        if isMuted {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 9))
                .foregroundColor(.white)
        }
        Text(name.components(separatedBy: " ").first ?? name)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Capsule().fill(Color.black.opacity(0.4)))
}

// MARK: - Too Many Participants Indicator
struct TooManyParticipantsIndicator: View {
    let count: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
            VStack(spacing: 6) {
                Text("+\(count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Text("Swipe to see more")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Agora Local Video UIViewRepresentable
struct AgoraLocalVideoView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(Color(hex: "1A2621"))
        AgoraService.shared.setupLocalVideo(view: view)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Agora Remote Video UIViewRepresentable
struct AgoraRemoteVideoView: UIViewRepresentable {
    let uid: UInt
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(Color(hex: "1A2621"))
        AgoraService.shared.setupRemoteVideo(uid: uid, view: view)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
