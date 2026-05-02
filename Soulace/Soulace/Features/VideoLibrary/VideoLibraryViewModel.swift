//
//  VideoLibraryViewModel.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import Foundation
import Combine

// MARK: - VideoLibraryViewModel
final class VideoLibraryViewModel: ObservableObject {
    @Published var videos: [VideoContent]                        = []
    @Published var selectedCategory: VideoContent.VideoCategory? = nil
    @Published var searchText: String                            = ""
    @Published var isLoading: Bool                               = false
    @Published var errorMessage: String?                         = nil

    private let firestoreService = FirestoreService.shared
    private var cancellables     = Set<AnyCancellable>()

    init() { fetchVideos() }

    // MARK: - Fetch videos (uses mock for now, swap to Firestore when real data exists)
    func fetchVideos() {
        isLoading = true
        // Using mock data until Firebase Storage/Firestore has real videos
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.videos    = self.firestoreService.getMockVideos()
            self.isLoading = false
        }
    }

    // MARK: - Filtered videos
    var filteredVideos: [VideoContent] {
        videos.filter { video in
            let matchCategory = selectedCategory == nil || video.category == selectedCategory
            let matchSearch   = searchText.isBlank
                || video.title.localizedCaseInsensitiveContains(searchText)
                || video.instructorName.localizedCaseInsensitiveContains(searchText)
                || video.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchCategory && matchSearch
        }
    }

    // MARK: - Category selection
    func selectCategory(_ category: VideoContent.VideoCategory?) {
        selectedCategory = category
    }

    var isEmpty: Bool { filteredVideos.isEmpty && !isLoading }
}
