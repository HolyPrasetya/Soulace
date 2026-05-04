//
//  CallView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI
import AVKit
import AgoraRtcKit

struct CallView: View {
    @StateObject private var vm: CallViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showParticipants = false

    init(session: YogaSession, currentUser: SoulaceUser, video: VideoContent? = nil) {
        _vm = StateObject(wrappedValue: CallViewModel(
            session: session,
            currentUser: currentUser,
            video: video
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "111D19").ignoresSafeArea()

            VStack(spacing: 0) {
                // Sticky navbar
                stickyNavBar.zIndex(10)

                // Timer bar
                timerBar.zIndex(9)

                // ── Bug 3 Fix: Video embedded at top when selected ──
                if let video = vm.selectedVideo {
                    embeddedVideoPlayer(video: video)
                        .frame(height: UIScreen.main.bounds.height * 0.28)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Participant camera grid
                ScrollView(showsIndicators: false) {
                    participantGrid
                        .padding(.horizontal, 3)
                        .padding(.top, 3)
                }

                Spacer(minLength: 0)

                // Controls
                CallControlsView(
                    isMuted:        vm.isMuted,
                    isCameraOff:    vm.isCameraOff,
                    onMic:          { vm.toggleMic() },
                    onCamera:       { vm.toggleCamera() },
                    onSwitch:       { vm.switchCamera() },
                    onVideo:        { vm.showVideoPlayer = true },
                    onParticipants: { showParticipants = true },
                    onEnd:          { vm.leaveCall() }
                )
            }

            // Admit overlay
            if vm.showAdmitSheet, let entry = vm.pendingEntry {
                AdmitDeclineView(
                    entry:     entry,
                    onAdmit:   { vm.admitParticipant(entry) },
                    onDecline: { vm.declineParticipant(entry) }
                )
                .zIndex(20)
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.joinCall() }
        .onDisappear {
            if vm.isSessionEnded { AgoraService.shared.destroy() }
        }
        .onChange(of: vm.navigateHome) { goHome in
            if goHome { dismiss() }
        }
        .fullScreenCover(isPresented: $vm.isSessionEnded) {
            SessionSummaryView(summary: vm.buildSummary())
        }
        // ── Bug 3 Fix: Video library as sheet to PICK video, then embedded ──
        .sheet(isPresented: $vm.showVideoPlayer) {
            VideoLibraryView { video in
                vm.selectedVideo = video
                vm.showVideoPlayer = false
            }
        }
        .sheet(isPresented: $showParticipants) {
            ParticipantsPanelView(
                localUser:    vm.currentUser,
                participants: vm.participants,
                isHost:       vm.isHost
            )
            .presentationDetents([.medium, .large])
        }
        .animation(.easeInOut(duration: 0.3), value: vm.selectedVideo?.id)
    }

    // MARK: ── Sticky Navbar ──
    private var stickyNavBar: some View {
        HStack(spacing: 12) {
            Button(action: { vm.goHome() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
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
                        .fill(vm.isTimerRunning ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(vm.isTimerRunning ? "Live" : "Paused")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(vm.isTimerRunning ? .green : .orange)
                    Text("· \(vm.participantCount) people")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Button(action: { showParticipants = true }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                    if !vm.waitingEntries.isEmpty {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "111D19"))
    }

    // MARK: ── Timer Bar ──
    private var timerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(Color.soulaceMint.opacity(0.8))
                Text(vm.elapsedFormatted)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Text("/")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))

            Text(vm.remainingFormatted)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.soulaceMint)
                        .frame(width: vm.durationSeconds > 0
                               ? geo.size.width * CGFloat(vm.sessionElapsed) / CGFloat(vm.durationSeconds)
                               : 0)
                }
            }
            .frame(width: 80, height: 5)

            Button(action: { vm.toggleTimer() }) {
                ZStack {
                    Circle()
                        .fill(vm.isTimerRunning ? Color.orange.opacity(0.2) : Color.soulaceAccent.opacity(0.3))
                        .frame(width: 30, height: 30)
                    Image(systemName: vm.isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(vm.isTimerRunning ? .orange : Color.soulaceMint)
                }
            }
            .buttonStyle(SoulaceScaleButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "0F1A16"))
    }

    // MARK: ── Bug 3: Embedded Video Player (AVPlayer inside call) ──
    @ViewBuilder
    private func embeddedVideoPlayer(video: VideoContent) -> some View {
        ZStack {
            Color.black

            if let url = URL(string: video.streamURL) {
                EmbeddedAVPlayerView(url: url, isPlaying: $vm.isVideoPlaying)
            }

            // Top controls overlay
            VStack {
                HStack {
                    // Video title
                    VStack(alignment: .leading, spacing: 2) {
                        Text(video.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text(video.instructorName)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    // Close video button
                    Button(action: {
                        withAnimation { vm.selectedVideo = nil }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(10)

                Spacer()

                // Play/Pause overlay
                HStack {
                    Button(action: { vm.isVideoPlaying.toggle() }) {
                        Image(systemName: vm.isVideoPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    // MARK: ── Participant Grid ──
    private var participantGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 3),
                    GridItem(.flexible(), spacing: 3)]

        return LazyVGrid(columns: cols, spacing: 3) {
            // Local tile
            LocalVideoTile(
                user:            vm.currentUser,
                isMuted:         vm.isMuted,
                isCameraOff:     vm.isCameraOff,
                showShareButton: vm.isHost && vm.selectedVideo == nil,
                onShareTap:      { vm.showVideoPlayer = true }
            )
            .aspectRatio(0.75, contentMode: .fit)

            // Remote tiles
            ForEach(vm.participants.prefix(AppConstants.Agora.maxParticipants - 1)) { participant in
                RemoteVideoTile(participant: participant)
                    .aspectRatio(0.75, contentMode: .fit)
            }
        }
    }
}

// MARK: ── Bug 3: Embedded AVPlayer (stable, not sheet) ──
struct EmbeddedAVPlayerView: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPlaying: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player     = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player          = player
        controller.showsPlaybackControls = true
        controller.videoGravity    = .resizeAspect
        context.coordinator.player = player
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if isPlaying {
            context.coordinator.player?.play()
        } else {
            context.coordinator.player?.pause()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var player: AVPlayer?
    }
}

// MARK: ── Local Video Tile ──
struct LocalVideoTile: View {
    let user: SoulaceUser
    let isMuted: Bool
    let isCameraOff: Bool
    var showShareButton: Bool = false
    var onShareTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))

            if isCameraOff {
                avatarPlaceholder
            } else {
                AgoraLocalVideoView()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

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
                    callNameTag(name: "You", isMuted: isMuted)
                    Spacer()
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var avatarPlaceholder: some View {
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

// MARK: ── Remote Video Tile ──
// Bug 2 Fix: Stable UIView — tidak dibuat ulang saat SwiftUI re-render
struct RemoteVideoTile: View {
    let participant: CallParticipant

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))

            if participant.isCameraOff {
                avatarView
            } else {
                StableAgoraRemoteView(uid: participant.agoraUID)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack {
                Spacer()
                HStack {
                    callNameTag(name: participant.name, isMuted: participant.isMuted)
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
                    .fill(Color.soulaceMint.opacity(0.25))
                    .frame(width: 50, height: 50)
                Text(participant.initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.soulaceMint)
            }
            Text(participant.name)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: ── Bug 2 Fix: Stable Agora Remote View ──
// Key insight: UIView harus STABLE — tidak boleh dibuat ulang
// Gunakan makeUIView hanya sekali, updateUIView untuk sync
struct StableAgoraRemoteView: UIViewRepresentable {
    let uid: UInt

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(Color(hex: "1A2621"))

        // ── Critical fix: setup AFTER runloop ──
        // Delay memastikan view sudah masuk window hierarchy
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AgoraService.shared.setupRemoteVideo(uid: uid, view: view)
            print("📹 StableRemoteView: setup uid \(uid)")
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Do NOT recreate — only re-setup if uid changed
        if context.coordinator.lastUID != uid {
            context.coordinator.lastUID = uid
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                AgoraService.shared.setupRemoteVideo(uid: uid, view: uiView)
                print("📹 StableRemoteView: re-setup uid \(uid)")
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(uid: uid) }

    class Coordinator: NSObject {
        var lastUID: UInt
        init(uid: UInt) { self.lastUID = uid }
    }
}

// MARK: ── Agora Local Video ──
struct AgoraLocalVideoView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor(Color(hex: "1A2621"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AgoraService.shared.setupLocalVideo(view: view)
        }
        return view
    }
    // Do NOT call setupLocalVideo here — causes re-render loop
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: ── Name Tag ──
func callNameTag(name: String, isMuted: Bool) -> some View {
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

// MARK: ── Participants Panel ──
struct ParticipantsPanelView: View {
    let localUser:    SoulaceUser
    let participants: [CallParticipant]
    let isHost:       Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5F8F6").ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        participantRow(initials: localUser.initials,
                                       name: "\(localUser.fullName) (You)",
                                       isMuted: false, isCameraOff: false, isHost: isHost)
                        ForEach(participants) { p in
                            participantRow(initials: p.initials, name: p.name,
                                           isMuted: p.isMuted, isCameraOff: p.isCameraOff,
                                           isHost: p.isHost)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Participants (\(participants.count + 1))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                }
            }
        }
    }

    private func participantRow(initials: String, name: String,
                                isMuted: Bool, isCameraOff: Bool, isHost: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.soulaceMint.opacity(0.5)).frame(width: 44, height: 44)
                Text(initials).font(.system(size: 15, weight: .bold)).foregroundColor(Color.soulaceAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.system(size: 15, weight: .medium)).foregroundColor(Color.soulaceDark)
                    if isHost {
                        Text("Host").font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.soulaceAccent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.soulaceAccent.opacity(0.12)))
                    }
                }
            }
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isMuted ? .red : Color.soulaceAccent.opacity(0.5))
                Image(systemName: isCameraOff ? "video.slash.fill" : "video.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isCameraOff ? .red : Color.soulaceAccent.opacity(0.5))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
}
