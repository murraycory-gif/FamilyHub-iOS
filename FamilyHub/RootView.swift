import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HubStore
    @AppStorage("familyhub.onboarding.completed.v1") private var onboardingCompleted = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if showSplash {
                LaunchSplashView()
                    .zIndex(3)
            } else if !onboardingCompleted {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        onboardingCompleted = true
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            } else {
                MainHubView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(.light)
        .tint(AppTheme.blue)
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}

struct LaunchSplashView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 22) {
                Image("HubMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .scaleEffect(appear ? 1 : 0.92)
                .opacity(appear ? 1 : 0.85)

                VStack(spacing: 6) {
                    Text("HUB")
                        .font(.system(size: 34, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(AppTheme.text)
                    Text("Household command")
                        .font(.subheadline.weight(.medium))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appear = true
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(HubStore())
}
