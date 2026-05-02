//
//  Extensions.swift
//  Soulace
//
//  Created by Ignasius Holy Prasetya on 02/05/26.
//

import SwiftUI

// MARK: - Color: Hex initializer
extension Color {
    /// Create a Color from a hex string e.g. "4A7C6F" or "#4A7C6F"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Brand Colors
extension Color {
    static let soulaceMint   = Color(hex: "D1E3E3")
    static let soulaceSage   = Color(hex: "EEF4D0")
    static let soulacePeach  = Color(hex: "FFEEE0")
    static let soulaceDark   = Color(hex: "2C3E35")
    static let soulaceAccent = Color(hex: "4A7C6F")
    static let soulaceMuted  = Color(hex: "7A9E97")
    static let soulaceCard   = Color(hex: "F7FAF8")
}

// MARK: - Date Helpers
extension Date {
    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: self)
    }

    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: self)
    }

    var shortDateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }

    var isToday: Bool    { Calendar.current.isDateInToday(self) }
    var isTomorrow: Bool { Calendar.current.isDateInTomorrow(self) }

    var relativeLabel: String {
        if isToday    { return "Today" }
        if isTomorrow { return "Tomorrow" }
        return shortDateString
    }
}

// MARK: - String Helpers
extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool   { trimmed.isEmpty }
}

// MARK: - Array: Safe subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - View Modifier: Soulace Card
struct SoulaceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func soulaceCard() -> some View {
        modifier(SoulaceCardModifier())
    }
}

// MARK: - Button Style: Scale on press
struct SoulaceScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Reusable Primary Button
struct SoulacePrimaryButton: View {
    let title:      String
    var icon:       String?  = nil
    var isLoading:  Bool     = false
    var isDisabled: Bool     = false
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isDisabled
                          ? Color.soulaceAccent.opacity(0.4)
                          : Color.soulaceAccent)
                    .shadow(
                        color: isDisabled ? .clear : Color.soulaceAccent.opacity(0.35),
                        radius: 10, x: 0, y: 5
                    )
            )
        }
        .disabled(isLoading || isDisabled)
        .buttonStyle(SoulaceScaleButtonStyle())
    }
}
