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

    @Published var localUserID: UInt            = 0
    @Published var remoteParticipants: [CallParticipant] = []
    @Published var isJoined: Bool               = false
    @Published var isMuted: Bool                = false
    @Published var isCameraOff: Bool            = false
    @Published var error: String?               = nil

    private var agoraKit: AgoraRtcEngineKit?
    private var currentChannel: String?

    override init() {
        super.init()
        // ⚠️ TIDAK setup engine di sini — tunggu sampai benar-benar join call
        // Ini fix SIGKILL: Agora engine berat, jangan init saat app launch
    }

    // MARK: - Setup Engine (lazy — hanya dipanggil saat joinChannel)
    private func setupEngineIfNeeded() {
        guard agoraKit == nil else { return }

        let config = AgoraRtcEngineConfig()
        config.appId           = AppConstants.Agora.appID
        config.channelProfile  = .liveBroadcasting
        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        agoraKit?.setClientRole(.broadcaster)
        agoraKit?.enableVideo()
        agoraKit?.enableAudio()
    }

    // MARK: - Join Channel
    func joinChannel(_ channelName: String, userID: UInt = 0) {
        // Setup engine sekarang, bukan saat launch
        setupEngineIfNeeded()

        currentChannel = channelName

        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType         = .broadcaster
        options.channelProfile         = .liveBroadcasting
        options.publishCameraTrack     = true
        options.publishMicrophoneTrack = true
        options.autoSubscribeAudio     = true
        options.autoSubscribeVideo     = true

        let result = agoraKit?.joinChannel(
            byToken:      nil,
            channelId:    channelName,
            uid:          userID,
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
            self.isJoined           = false
            self.remoteParticipants = []
            self.currentChannel     = nil
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
        setupEngineIfNeeded()
        let canvas        = AgoraRtcVideoCanvas()
        canvas.uid        = 0
        canvas.view       = view
        canvas.renderMode = .hidden
        agoraKit?.setupLocalVideo(canvas)
        agoraKit?.startPreview()
    }

    // MARK: - Setup Remote Video
    func setupRemoteVideo(uid: UInt, view: UIView) {
        let canvas        = AgoraRtcVideoCanvas()
        canvas.uid        = uid
        canvas.view       = view
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

    func rtcEngine(_ engine: AgoraRtcEngineKit,
                   didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            self.localUserID = uid
            self.isJoined    = true
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        let participant = CallParticipant(
            id: "\(uid)", agoraUID: uid,
            name: "Participant", initials: "P"
        )
        DispatchQueue.main.async {
            if !self.remoteParticipants.contains(where: { $0.agoraUID == uid }) {
                self.remoteParticipants.append(participant)
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit,
                   didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async {
            self.remoteParticipants.removeAll { $0.agoraUID == uid }
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
        DispatchQueue.main.async {
            self.error = "Agora error: \(errorCode.rawValue)"
        }
    }
}
