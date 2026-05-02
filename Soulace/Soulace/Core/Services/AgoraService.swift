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
/// Manages Agora RTC video call — join, leave, participant events
final class AgoraService: NSObject, ObservableObject {
    static let shared = AgoraService()

    @Published var localUserID: UInt = 0
    @Published var remoteParticipants: [CallParticipant] = []
    @Published var isJoined: Bool = false
    @Published var isMuted: Bool = false
    @Published var isCameraOff: Bool = false
    @Published var error: String? = nil

    private var agoraKit: AgoraRtcEngineKit?
    private var currentChannel: String?

    override init() {
        super.init()
        setupEngine()
    }

    // MARK: - Setup Engine
    private func setupEngine() {
        let config = AgoraRtcEngineConfig()
        config.appId = AppConstants.Agora.appID
        config.channelProfile = .liveBroadcasting
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit?.setClientRole(.broadcaster)
        agoraKit?.enableVideo()
        agoraKit?.enableAudio()
    }

    // MARK: - Join Channel
    func joinChannel(_ channelName: String, userID: UInt = 0) {
        currentChannel = channelName

        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.channelProfile  = .liveBroadcasting
        options.publishCameraTrack = true
        options.publishMicrophoneTrack = true
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true

        // Token generation: for MVP use nil (test mode)
        // In production, fetch token from your backend
        let result = agoraKit?.joinChannel(
            byToken: nil,
            channelId: channelName,
            uid: userID,
            mediaOptions: options
        )

        if result != 0 {
            DispatchQueue.main.async {
                self.error = "Failed to join channel: \(result ?? -1)"
            }
        }
    }

    // MARK: - Leave Channel
    func leaveChannel() {
        agoraKit?.leaveChannel { _ in }
        DispatchQueue.main.async {
            self.isJoined = false
            self.remoteParticipants = []
            self.currentChannel = nil
        }
    }

    // MARK: - Toggle Mic
    func toggleMic() {
        isMuted.toggle()
        agoraKit?.muteLocalAudioStream(isMuted)
    }

    // MARK: - Toggle Camera
    func toggleCamera() {
        isCameraOff.toggle()
        agoraKit?.muteLocalVideoStream(isCameraOff)
    }

    // MARK: - Switch Camera
    func switchCamera() {
        agoraKit?.switchCamera()
    }

    // MARK: - Setup Local Video
    func setupLocalVideo(view: UIView) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = 0
        canvas.view = view
        canvas.renderMode = .hidden
        agoraKit?.setupLocalVideo(canvas)
        agoraKit?.startPreview()
    }

    // MARK: - Setup Remote Video
    func setupRemoteVideo(uid: UInt, view: UIView) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.view = view
        canvas.renderMode = .hidden
        agoraKit?.setupRemoteVideo(canvas)
    }

    // MARK: - Cleanup
    func destroy() {
        leaveChannel()
        AgoraRtcEngineKit.destroy()
        agoraKit = nil
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgoraService: AgoraRtcEngineDelegate {

    // Local user joined
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            self.localUserID = uid
            self.isJoined = true
        }
    }

    // Remote user joined
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        let participant = CallParticipant(
            id: "\(uid)",
            agoraUID: uid,
            name: "Participant",
            initials: "P"
        )
        DispatchQueue.main.async {
            if !self.remoteParticipants.contains(where: { $0.agoraUID == uid }) {
                self.remoteParticipants.append(participant)
            }
        }
    }

    // Remote user left
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async {
            self.remoteParticipants.removeAll { $0.agoraUID == uid }
        }
    }

    // Remote user muted audio
    func rtcEngine(_ engine: AgoraRtcEngineKit, didAudioMuted muted: Bool, byUid uid: UInt) {
        DispatchQueue.main.async {
            if let index = self.remoteParticipants.firstIndex(where: { $0.agoraUID == uid }) {
                self.remoteParticipants[index].isMuted = muted
            }
        }
    }

    // Remote user muted video
    func rtcEngine(_ engine: AgoraRtcEngineKit, didVideoMuted muted: Bool, byUid uid: UInt) {
        DispatchQueue.main.async {
            if let index = self.remoteParticipants.firstIndex(where: { $0.agoraUID == uid }) {
                self.remoteParticipants[index].isCameraOff = muted
            }
        }
    }

    // Connection error
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        DispatchQueue.main.async {
            self.error = "Agora error: \(errorCode.rawValue)"
        }
    }
}
