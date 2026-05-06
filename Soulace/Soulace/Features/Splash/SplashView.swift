import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var logoScale: CGFloat   = 0.4
    @State private var logoOpacity: Double  = 0
    @State private var logoRotation: Double = -15
    @State private var textOpacity: Double  = 0
    @State private var textOffset: CGFloat  = 14
    @State private var glowOpacity: Double  = 0
    @State private var ringScale: CGFloat   = 0.5
    @State private var ringOpacity: Double  = 0

    // Brand colors defined inline to avoid dependency issues at launch
    private let mint  = Color(red: 0.820, green: 0.890, blue: 0.890) // #D1E3E3
    private let sage  = Color(red: 0.933, green: 0.957, blue: 0.816) // #EEF4D0
    private let peach = Color(red: 1.000, green: 0.933, blue: 0.878) // #FFEEE0
    private let dark  = Color(red: 0.173, green: 0.243, blue: 0.208) // #2C3E35
    private let accent = Color(red: 0.290, green: 0.486, blue: 0.435) // #4A7C6F

    var body: some View {
        ZStack {
            // Background gradient — inline stops syntax
            LinearGradient(
                colors: [peach, sage, mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative blobs
            Circle()
                .fill(mint.opacity(0.55))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -90, y: -180)

            Circle()
                .fill(peach.opacity(0.55))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: 110, y: 190)

            // Pulse rings
            Circle()
                .stroke(accent.opacity(0.2), lineWidth: 1.5)
                .frame(width: 190, height: 190)
                .scaleEffect(ringScale)
                .opacity(ringOpacity)

            Circle()
                .stroke(accent.opacity(0.1), lineWidth: 1)
                .frame(width: 240, height: 240)
                .scaleEffect(ringScale * 0.92)
                .opacity(ringOpacity * 0.6)

            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.65), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 75
                    )
                )
                .frame(width: 150, height: 150)
                .opacity(glowOpacity)
                .blur(radius: 18)

            // Logo + wordmark
            VStack(spacing: 0) {
                Image("SecondarySoulace")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: Color.black.opacity(0.14), radius: 24, x: 0, y: 12)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .rotationEffect(.degrees(logoRotation))

                VStack(spacing: 6) {
                    Text("SOULACE")
                        .font(.custom("Georgia-Bold", size: 26))
                        .tracking(6)
                        .foregroundColor(dark)

                    Text("Let's do Yoga together")
                        .font(.system(size: 13, weight: .regular))
                        .tracking(2)
                        .foregroundColor(dark.opacity(0.5))
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
                .padding(.top, 26)
            }
        }
        .onAppear { runAnimations() }
    }

    private func runAnimations() {
        // Ring pulse
        withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
            ringScale   = 2.0
            ringOpacity = 0.9
        }
        withAnimation(.easeIn(duration: 0.4).delay(0.9)) {
            ringOpacity = 0
        }

        // Logo spring in
        withAnimation(.spring(response: 0.65, dampingFraction: 0.62).delay(0.2)) {
            logoScale    = 1.0
            logoOpacity  = 1.0
            logoRotation = 0
        }

        // Glow
        withAnimation(.easeInOut(duration: 0.7).delay(0.4))  { glowOpacity = 1.0 }
        withAnimation(.easeInOut(duration: 0.5).delay(1.0))  { glowOpacity = 0.0 }

        // Text
        withAnimation(.easeOut(duration: 0.55).delay(0.7)) {
            textOpacity = 1.0
            textOffset  = 0
        }

        // Navigate to main app
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            onFinished()
        }
    }
}
