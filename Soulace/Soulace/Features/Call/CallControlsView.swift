//
//  CallControlsView.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI
import Combine

// MARK: - Call Controls Bar
struct CallControlsView: View {
    let isMuted:     Bool
    let isCameraOff: Bool
    let onMic:       () -> Void
    let onCamera:    () -> Void
    let onSwitch:    () -> Void
    let onVideo:     () -> Void
    let onEnd:       () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            // Mic
            CallControlButton(
                icon:    isMuted ? "mic.slash.fill" : "mic.fill",
                label:   isMuted ? "Mic Off" : "Mic On",
                tint:    isMuted ? .red : .white,
                action:  onMic
            )

            Spacer()

            // Camera
            CallControlButton(
                icon:    isCameraOff ? "video.slash.fill" : "video.fill",
                label:   isCameraOff ? "Cam Off" : "Cam On",
                tint:    isCameraOff ? .red : .white,
                action:  onCamera
            )

            Spacer()

            // End call
            Button(action: onEnd) {
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 54, height: 54)
                            .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    Text("End")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(SoulaceScaleButtonStyle())

            Spacer()

            // Share Video
            CallControlButton(
                icon:   "play.rectangle.fill",
                label:  "Participants",
                tint:   Color.soulaceMint,
                action: onVideo
            )

            Spacer()

            // Switch Camera
            CallControlButton(
                icon:   "camera.rotate.fill",
                label:  "More",
                tint:   .white,
                action: onSwitch
            )

            Spacer()
        }
        .padding(.vertical, 18)
        .background(
            Color(hex: "0F1A16")
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Single Control Button
struct CallControlButton: View {
    let icon:   String
    let label:  String
    let tint:   Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(tint)
                }
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .buttonStyle(SoulaceScaleButtonStyle())
    }
}

// MARK: - Admit / Decline Overlay
struct AdmitDeclineView: View {
    let entry:     WaitingEntry
    let onAdmit:   () -> Void
    let onDecline: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    // Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 40, height: 5)

                    Text("Someone wants to join")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.soulaceDark)

                    // User info
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.soulaceMint.opacity(0.4))
                                .frame(width: 64, height: 64)
                            Text(entry.userInitials)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.soulaceAccent)
                        }

                        Text(entry.userName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.soulaceDark)
                    }

                    // Buttons
                    HStack(spacing: 14) {
                        Button(action: onDecline) {
                            Text("Decline")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.soulaceDark.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.soulaceDark.opacity(0.08))
                                )
                        }
                        .buttonStyle(SoulaceScaleButtonStyle())

                        Button(action: onAdmit) {
                            Text("Admit")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.soulaceAccent)
                                        .shadow(color: Color.soulaceAccent.opacity(0.35),
                                                radius: 8, x: 0, y: 4)
                                )
                        }
                        .buttonStyle(SoulaceScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.soulacePeach, Color.soulaceSage.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -8)
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 36)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Waiting Room View (for non-host who is waiting)
struct WaitingRoomView: View {
    let session: YogaSession
    let entryID: String
    @StateObject private var vm: WaitingRoomViewModel

    init(session: YogaSession, entryID: String) {
        self.session = session
        self.entryID = entryID
        _vm = StateObject(wrappedValue: WaitingRoomViewModel(entryID: entryID))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.soulacePeach, Color.soulaceSage, Color.soulaceMint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Animated waiting indicator
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.soulaceAccent.opacity(0.2 - Double(i) * 0.05),
                                    lineWidth: 1.5)
                            .frame(width: CGFloat(80 + i * 40), height: CGFloat(80 + i * 40))
                            .scaleEffect(vm.pulseScale)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever()
                                .delay(Double(i) * 0.3),
                                value: vm.pulseScale
                            )
                    }

                    ZStack {
                        Circle()
                            .fill(Color.soulaceAccent.opacity(0.12))
                            .frame(width: 72, height: 72)
                        Image(systemName: "hourglass")
                            .font(.system(size: 28))
                            .foregroundColor(Color.soulaceAccent)
                    }
                }

                VStack(spacing: 8) {
                    Text("Awaiting Approval")
                        .font(.custom("Georgia-Bold", size: 22))
                        .foregroundColor(Color.soulaceDark)
                    Text("The host will let you in soon")
                        .font(.system(size: 14))
                        .foregroundColor(Color.soulaceDark.opacity(0.5))
                }

                if vm.isDeclined {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.red)
                        Text("You were not admitted to this session")
                            .font(.system(size: 14))
                            .foregroundColor(Color.soulaceDark.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.6))
                    )
                }

                Spacer()
            }
            .padding(.horizontal, 30)
        }
        .onAppear { vm.startObserving() }
    }
}

// MARK: - WaitingRoomViewModel
final class WaitingRoomViewModel: ObservableObject {
    @Published var isAdmitted: Bool  = false
    @Published var isDeclined: Bool  = false
    @Published var pulseScale: CGFloat = 1.0

    private let entryID: String
    private var cancellables = Set<AnyCancellable>()

    init(entryID: String) { self.entryID = entryID }

    func startObserving() {
        pulseScale = 1.08
        FirestoreService.shared.observeMyWaitingStatus(entryID: entryID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] entry in
                      guard let self, let entry else { return }
                      switch entry.status {
                      case .admitted: self.isAdmitted = true
                      case .declined: self.isDeclined = true
                      case .pending:  break
                      }
                  })
            .store(in: &cancellables)
    }
}
