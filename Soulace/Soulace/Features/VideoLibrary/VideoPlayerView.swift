//
//  VideoPlayerView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI
import AVKit

// MARK: - VideoPlayerView
struct VideoPlayerView: View {
    @StateObject private var vm: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    init(video: VideoContent) {
        _vm = StateObject(wrappedValue: VideoPlayerViewModel(video: video))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player Area
                    playerArea

                    // Info + controls
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            videoInfo
                            Divider().background(Color.soulaceMint.opacity(0.3))
                            descriptionSection
                        }
                        .padding(20)
                    }
                    .background(Color.white)
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                }
            }
            .onAppear  { vm.setupPlayer() }
            .onDisappear { vm.cleanup() }
        }
    }

    // MARK: - Player Area
    private var playerArea: some View {
        ZStack {
            if let player = vm.player {
                VideoPlayer(player: player)
                    .frame(height: 230)
            } else {
                Rectangle()
                    .fill(Color(hex: "1A2621"))
                    .frame(height: 230)
                    .overlay(
                        Group {
                            if vm.isLoading {
                                ProgressView().tint(.white)
                            } else if let error = vm.errorMessage {
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 28))
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                    )
            }
        }
    }

    // MARK: - Video Info
    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vm.video.title)
                .font(.custom("Georgia-Bold", size: 20))
                .foregroundColor(Color.soulaceDark)

            Text(vm.video.instructorName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.soulaceAccent)

            HStack(spacing: 14) {
                Label("\(vm.video.durationMinutes) min", systemImage: "clock")
                Label(vm.video.level.rawValue,           systemImage: "chart.bar.fill")
                Label(vm.video.category.rawValue,        systemImage: "tag.fill")
            }
            .font(.system(size: 12))
            .foregroundColor(Color.soulaceDark.opacity(0.5))

            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.video.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.soulaceAccent.opacity(0.8))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.soulaceAccent.opacity(0.08))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Description
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.soulaceDark.opacity(0.45))
                .textCase(.uppercase)
                .tracking(0.6)

            Text(vm.video.description)
                .font(.system(size: 14))
                .foregroundColor(Color.soulaceDark.opacity(0.65))
                .lineSpacing(5)
        }
    }
}
