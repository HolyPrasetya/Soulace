//
//  AgoraService.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import AgoraRtcKit
import Combine

// MARK: - AgoraService
final class AgoraService: NSObject, ObservableObject {
    static let shared = AgoraService()

    @Published var localUserID: UInt                     = 0
    @Published var remoteParticipants: [CallParticipant] = []
    @Published var isJoined: Bool                        = false
    @Published var isMuted: Bool                         = false
    @Published var isCameraOff: Bool                     = false
    @Published var error: String?                        = nil

    private var agoraKit: AgoraRtcEngineKit?
    private var currentChannel: String?

    // ── Bug Fix: store remote view references ──
    private var remoteViews: [UInt: UIView] = [:]

    // Callback so CallViewModel can resolve uid → Firestore user name
    var onRemoteUserJoined: ((UInt) -> Void)? = nil

    override init() { super.init() }

    // MARK: - Setup Engine (lazy)
    private func setupEngineIfNeeded() {
        guard agoraKit == nil else { return }
        let config            = AgoraRtcEngineConfig()
        config.appId          = AppConstants.Agora.appID
        config.channelProfile = .liveBroadcasting
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit?.setClientRole(.broadcaster)
        agoraKit?.enableVideo()
        agoraKit?.enableAudio()

        // ── Fix: set video encoding config for better quality ──
        let videoConfig = AgoraVideoEncoderConfiguration(
            size:        CGSize(width: 640, height: 480),
            frameRate:   15,
            bitrate:     AgoraVideoBitrateStandard,
            orientationMode: .adaptative,
            mirrorMode:  .auto
        )
        agoraKit?.setVideoEncoderConfiguration(videoConfig)

        print("✅ Agora: engine initialized")
    }

    // MARK: - Join Channel
    func joinChannel(_ channelName: String, userID: UInt = 0) {
        setupEngineIfNeeded()
        currentChannel = channelName

        let options                        = AgoraRtcChannelMediaOptions()
        options.clientRoleType             = .broadcaster
        options.channelProfile             = .liveBroadcasting
        options.publishCameraTrack         = true
        options.publishMicrophoneTrack     = true
        options.autoSubscribeAudio         = true
        options.autoSubscribeVideo         = true

        let result = agoraKit?.joinChannel(
            byToken:      nil,        // nil = App ID only mode (no token)
            channelId:    channelName,
            uid:          userID,
            mediaOptions: options
        )

        if let result, result != 0 {
            DispatchQueue.main.async {
                self.error = "Failed to join channel (code: \(result))"
            }
            print("❌ Agora joinChannel failed: \(result)")
        } else {
            print("📡 Agora: joining channel \(channelName) as uid \(userID)")
        }
    }

    // MARK: - Leave Channel
    func leaveChannel() {
        agoraKit?.leaveChannel { stats in
            print("📡 Agora: left channel — duration \(stats.duration)s")
        }
        DispatchQueue.main.async {
            self.isJoined           = false
            self.remoteParticipants = []
            self.currentChannel     = nil
            self.remoteViews        = [:]
        }
    }

    // MARK: - Toggle Controls
    func toggleMic() {
        isMuted.toggle()
        agoraKit?.muteLocalAudioStream(isMuted)
        print("🎤 Agora: mic \(isMuted ? "muted" : "unmuted")")
    }

    func toggleCamera() {
        isCameraOff.toggle()
        agoraKit?.muteLocalVideoStream(isCameraOff)
        print("📹 Agora: camera \(isCameraOff ? "off" : "on")")
    }

    func switchCamera() { agoraKit?.switchCamera() }

    // MARK: - Setup Local Video
    func setupLocalVideo(view: UIView) {
        setupEngineIfNeeded()
        let canvas        = AgoraRtcVideoCanvas()
        canvas.uid        = 0
        canvas.view       = view
        canvas.renderMode = .hidden
        agoraKit?.setupLocalVideo(canvas)
        agoraKit?.startPreview()
        print("📹 Agora: local video setup done")
    }

    // MARK: - Setup Remote Video
    // ── Bug Fix: must be called AFTER view is in window hierarchy ──
    func setupRemoteVideo(uid: UInt, view: UIView) {
        remoteViews[uid] = view  // store reference

        let canvas        = AgoraRtcVideoCanvas()
        canvas.uid        = uid
        canvas.view       = view
        canvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(canvas)
        print("📹 Agora: remote video setup for uid \(uid)")
    }

    // ── Re-render remote video when view appears in hierarchy ──
    func rerenderRemoteVideo(uid: UInt, view: UIView) {
        remoteViews[uid] = view
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            let canvas        = AgoraRtcVideoCanvas()
            canvas.uid        = uid
            canvas.view       = view
            canvas.renderMode = .hidden
            self.agoraKit?.setupRemoteVideo(canvas)
            print("🔄 Agora: re-rendered remote video for uid \(uid)")
        }
    }

    // MARK: - Cleanup
    func destroy() {
        leaveChannel()
        AgoraRtcEngineKit.destroy()
        agoraKit    = nil
        remoteViews = [:]
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraService: AgoraRtcEngineDelegate {

    func rtcEngine(_ engine: AgoraRtcEngineKit,
                   didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("✅ Agora: joined channel \(channel) as uid \(uid)")
        DispatchQueue.main.async {
            self.localUserID = uid
            self.isJoined    = true
        }
    }

    // ── Remote user joined ──
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("👤 Agora: remote user joined uid \(uid)")
        let participant = CallParticipant(
            id:       "\(uid)",
            agoraUID: uid,
            name:     "test...",
            initials: "?"
        )
        DispatchQueue.main.async {
            if !self.remoteParticipants.contains(where: { $0.agoraUID == uid }) {
                self.remoteParticipants.append(participant)
                // Trigger name resolution in CallViewModel
                self.onRemoteUserJoined?(uid)
            }
        }
    }

    // ── Remote user left ──
    func rtcEngine(_ engine: AgoraRtcEngineKit,
                   didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("👤 Agora: remote user left uid \(uid)")
        DispatchQueue.main.async {
            self.remoteParticipants.removeAll { $0.agoraUID == uid }
            self.remoteViews.removeValue(forKey: uid)
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        DispatchQueue.main.async {
            if let i = self.remoteParticipants.firstIndex(where: { $0.agoraUID == uid }) {
                self.remoteParticipants[i].isMuted = muted
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid uid: UInt) {
        DispatchQueue.main.async {
            if let i = self.remoteParticipants.firstIndex(where: { $0.agoraUID == uid }) {
                self.remoteParticipants[i].isCameraOff = muted
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("❌ Agora error: \(errorCode.rawValue)")
        DispatchQueue.main.async {
            self.error = "Agora error: \(errorCode.rawValue)"
        }
    }

    // ── First remote video frame received ── trigger re-render ──
    func rtcEngine(_ engine: AgoraRtcEngineKit,
                   firstRemoteVideoDecodedOfUid uid: UInt,
                   size: CGSize, elapsed: Int) {
        print("🎬 Agora: first video frame from uid \(uid)")
        DispatchQueue.main.async {
            // If we have a stored view, re-bind to ensure rendering
            if let view = self.remoteViews[uid] {
                self.rerenderRemoteVideo(uid: uid, view: view)
            }
        }
    }
}
