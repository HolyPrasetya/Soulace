//
//  VideoLibraryView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI

// MARK: - VideoLibraryView
struct VideoLibraryView: View {
    @StateObject private var vm = VideoLibraryViewModel()
    var onSelect: ((VideoContent) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideo: VideoContent? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5F8F6").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Category filter
                    categoryFilter

                    // Search bar
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    // Content
                    if vm.isLoading {
                        Spacer()
                        ProgressView().tint(Color.soulaceAccent)
                        Spacer()

                    } else if vm.isEmpty {
                        emptyState

                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.filteredVideos) { video in
                                    VideoCard(video: video) {
                                        if let onSelect {
                                            onSelect(video)
                                        } else {
                                            selectedVideo = video
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Yoga Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.soulaceAccent)
                }
            }
            .sheet(item: $selectedVideo) { video in
                VideoPlayerView(video: video)
            }
        }
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", isSelected: vm.selectedCategory == nil) {
                    vm.selectCategory(nil)
                }
                ForEach(VideoContent.VideoCategory.allCases, id: \.self) { cat in
                    CategoryChip(title: cat.rawValue, isSelected: vm.selectedCategory == cat) {
                        vm.selectCategory(cat)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.soulaceDark.opacity(0.35))
            TextField("Search videos, instructors...", text: $vm.searchText)
                .font(.system(size: 14))
                .foregroundColor(Color.soulaceDark)
            if !vm.searchText.isEmpty {
                Button(action: { vm.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.soulaceDark.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "video.slash")
                .font(.system(size: 40))
                .foregroundColor(Color.soulaceAccent.opacity(0.3))
            Text("No videos found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.soulaceDark.opacity(0.5))
            if !vm.searchText.isEmpty {
                Button("Clear search") { vm.searchText = "" }
                    .foregroundColor(Color.soulaceAccent)
            }
            Spacer()
        }
    }
}

// MARK: - Video Card
struct VideoCard: View {
    let video: VideoContent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.soulaceMint.opacity(0.5), Color.soulaceSage.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 62)
                    Image(systemName: "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.soulaceAccent)
                }

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.soulaceDark)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(video.instructorName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.soulaceDark.opacity(0.5))

                    HStack(spacing: 8) {
                        Label("\(video.durationMinutes) min", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(Color.soulaceDark.opacity(0.45))

                        Text(video.level.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: video.levelColor))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color(hex: video.levelColor).opacity(0.12))
                            )
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.soulaceDark.opacity(0.2))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(SoulaceScaleButtonStyle())
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title:      String
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.soulaceDark.opacity(0.55))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.soulaceAccent : Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(SoulaceScaleButtonStyle())
    }
}
