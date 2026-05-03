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
    @EnvironmentObject var appState: AppState

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
                sessionInfoBar      // Bug 4: includes play/pause timer button
                CallControlsView(
                    isMuted:     vm.isMuted,
                    isCameraOff: vm.isCameraOff,
                    onMic:       { vm.toggleMic() },
                    onCamera:    { vm.toggleCamera() },
                    onSwitch:    { vm.switchCamera() },
                    onVideo:     { vm.showVideoPlayer.toggle() },
                    onParticipants: { vm.showParticipantsPanel.toggle() },  // Bug 3
                    onEnd:       { vm.leaveCall() }
                )
            }

            // Bug 3: Participants panel overlay
            if vm.showParticipantsPanel {
                participantsPanel
            }

            // Admit/Decline overlay
            if vm.showAdmitSheet, let entry = vm.pendingEntry {
                AdmitDeclineView(entry: entry,
                                 onAdmit:   { vm.admitParticipant(entry) },
                                 onDecline: { vm.declineParticipant(entry) })
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            vm.joinCall()
            // Bug 4: Jika Agora belum join (testing/simulasi), start timer manual setelah delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if !vm.isTimerRunning { vm.startTimer() }
            }
        }
        .onDisappear {
            // Bug 5: Hanya cleanup jika memang session ended, bukan saat back
            if vm.isSessionEnded {
                AgoraService.shared.leaveChannel()
            }
        }
        // Bug 5: Back to home = dismiss saja tanpa end call
        .onChange(of: vm.navigateHome) { goHome in
            if goHome { dismiss() }
        }
        .fullScreenCover(isPresented: $vm.isSessionEnded) {
            SessionSummaryView(summary: vm.buildSummary())
        }
        .sheet(isPresented: $vm.showVideoPlayer) {
            if let video = vm.selectedVideo {
                VideoPlayerView(video: video)
            } else {
                // Jika belum ada video terpilih, tampilkan video library untuk pilih
                VideoLibraryView { video in
                    vm.selectedVideo = video
                    vm.showVideoPlayer = false
                }
            }
        }
    }

    // MARK: - Top Bar
    // Bug 5: Back button sekarang pakai vm.goHome() bukan vm.leaveCall()
    private var callTopBar: some View {
        HStack {
            Button(action: { vm.goHome() }) {            // ← Bug 5 fix
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
                        .fill(vm.isTimerRunning ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(vm.isTimerRunning
                         ? "Live · \(vm.participantCount) people"
                         : "Paused · \(vm.participantCount) people")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // Waiting room badge
            Button(action: { vm.showParticipantsPanel.toggle() }) {
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
            LocalVideoTile(
                user: vm.currentUser,
                isMuted: vm.isMuted,
                isCameraOff: vm.isCameraOff,
                showShareButton: vm.isHost && vm.selectedVideo == nil,
                onShareTap: { vm.showVideoPlayer = true }
            )
            .aspectRatio(0.75, contentMode: .fit)

            ForEach(allParticipants.prefix(AppConstants.Agora.maxParticipants - 1)) { participant in
                RemoteVideoTile(participant: participant)
                    .aspectRatio(0.75, contentMode: .fit)
            }

            if vm.participantCount > 4 {
                TooManyParticipantsIndicator(count: vm.participantCount - 4)
                    .aspectRatio(0.75, contentMode: .fit)
            }
        }
    }

    // MARK: - Session Info Bar
    // Bug 4: Tambah tombol play/pause timer
    private var sessionInfoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.elapsedFormatted)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("\(max(0, vm.session.durationMinutes - (vm.sessionElapsed / 60))) min remaining")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Bug 4: Play/Pause timer button
            Button(action: { vm.toggleTimer() }) {
                HStack(spacing: 5) {
                    Image(systemName: vm.isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(vm.isTimerRunning ? "Pause" : "Start")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(vm.isTimerRunning ? Color.soulaceMint : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
            }

            // Timer ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                    .frame(width: 36, height: 36)

                let progress = vm.durationSeconds > 0
                    ? Double(vm.sessionElapsed) / Double(vm.durationSeconds)
                    : 0

                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
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

    // MARK: - Bug 3: Participants Panel
    private var participantsPanel: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { vm.showParticipantsPanel = false }

            VStack {
                Spacer()

                VStack(spacing: 0) {
                    // Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    HStack {
                        Text("Participants")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.soulaceDark)
                        Spacer()
                        Text("\(vm.participantCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.soulaceAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.soulaceAccent.opacity(0.1)))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    Divider()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // Local user
                            ParticipantRow(
                                initials: vm.currentUser.initials,
                                name:     "\(vm.currentUser.fullName) (You)",
                                isMuted:  vm.isMuted,
                                isHost:   vm.isHost
                            )
                            Divider().padding(.leading, 56)

                            // Remote participants
                            ForEach(vm.participants) { p in
                                ParticipantRow(
                                    initials: p.initials,
                                    name:     p.name,
                                    isMuted:  p.isMuted,
                                    isHost:   p.isHost
                                )
                                if p.id != vm.participants.last?.id {
                                    Divider().padding(.leading, 56)
                                }
                            }

                            if vm.participants.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "person.2")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color.soulaceAccent.opacity(0.3))
                                    Text("No other participants yet")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.soulaceDark.opacity(0.4))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                            }
                        }
                    }
                    .frame(maxHeight: 300)

                    Spacer().frame(height: 34)
                }
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.soulacePeach, Color.soulaceSage.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 24, x: 0, y: -8)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 0)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.showParticipantsPanel)
    }
}

// MARK: - Participant Row (for panel)
struct ParticipantRow: View {
    let initials: String
    let name: String
    let isMuted: Bool
    let isHost: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.soulaceMint.opacity(0.5))
                    .frame(width: 40, height: 40)
                Text(initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.soulaceDark)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.soulaceDark)
                    if isHost {
                        Text("Host")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.soulaceAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.soulaceAccent.opacity(0.12)))
                    }
                }
            }

            Spacer()

            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                .font(.system(size: 14))
                .foregroundColor(isMuted ? .red.opacity(0.7) : Color.soulaceAccent.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Local Video Tile
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
                Text("More participants")
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
