//
//  VideoPlayerViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import AVKit
import Combine

// MARK: - VideoPlayerViewModel
final class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?          = nil
    @Published var isPlaying: Bool            = false
    @Published var isLoading: Bool            = true
    @Published var errorMessage: String?      = nil
    @Published var currentTime: Double        = 0
    @Published var duration: Double           = 0

    let video: VideoContent
    private var timeObserver: Any?

    init(video: VideoContent) {
        self.video = video
    }

    // MARK: - Setup Player
    func setupPlayer() {
        guard let url = URL(string: video.streamURL) else {
            errorMessage = "Invalid video URL"
            return
        }

        let item   = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player

        // Observe duration
        Task {
            do {
                let duration = try await item.asset.load(.duration)
                await MainActor.run {
                    self.duration  = CMTimeGetSeconds(duration)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }

        // Observe playback time every 0.5s
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
        }

        player.play()
        isPlaying = true
    }

    // MARK: - Controls
    func togglePlayPause() {
        guard let player else { return }
        
        isPlaying ? player.pause() : player.play()
        isPlaying.toggle()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
    }

    // MARK: - Cleanup
    func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
    }

    // MARK: - Progress
    var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var currentTimeFormatted: String { formatTime(currentTime) }
    var durationFormatted: String    { formatTime(duration) }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
