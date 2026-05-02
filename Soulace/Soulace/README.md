
# Soulace – SwiftUI Frontend

## File Structure

```
Soulace/
├── SoulaceApp.swift          # App entry, Models, ViewModel
├── ContentView.swift          # Router between screens
├── HomeView.swift             # Homepage (greeting + CTA cards)
├── VideoCallView.swift        # Video call grid + controls + admit sheet
├── SharePlayView.swift        # Active SharePlay session view
├── SessionCompleteView.swift  # End-of-session summary
└── SharePlayActivity.swift    # GroupActivity definition + integration notes
```

## Screens Implemented

| Screen | Description |
|--------|-------------|
| **HomeView** | Greeting, "Create a Video Call", "Join Yoga" with code field |
| **VideoCallView** | 2x2 participant grid, "Share Yoga Video" button, call controls |
| **ShareOptionsSheet** | Bottom sheet to choose SharePlay |
| **SharePlayView** | Video player (black) + participants grid + timer + fullscreen |
| **AdmitRequestSheet** | Admit/Reject overlay for non-contact join requests |
| **SessionCompleteView** | Session summary with per-participant status |

## SharePlay Integration

1. Add `GroupActivities` framework to your Xcode target
2. Enable **Group Activities** capability in Signing & Capabilities
3. Add `NSCameraUsageDescription`, `NSMicrophoneUsageDescription` to Info.plist
4. Use `YogaVideoActivity` defined in `SharePlayActivity.swift`
5. Pair `AVPlayer` with `playbackCoordinator` for synchronized playback

## Admit Flow Logic

- **Synced contacts** → auto-approved OR shown approval sheet
- **Non-contacts** → always shown Admit/Reject sheet  
  (controlled via `vm.isSynced` + `vm.showAdmitSheet`)

## Colors / Design Tokens

The app uses a minimal black/white/gray palette with:
- Accent: `Color("BrandBrown")` – add a custom color asset `#5C3A1E` or similar
- Status colors: `.green` (completed), `.orange` (partial), `.red` (missed)

## Requirements

- iOS 16+
- Xcode 15+
- Swift 5.9+
- GroupActivities framework for SharePlay
