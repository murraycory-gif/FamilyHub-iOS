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
        .tint(AppTheme.forest)
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
                ZStack {
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(AppTheme.forest)
                        .frame(width: 112, height: 112)
                    Image(systemName: "house.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(AppTheme.bg)
                }
                .scaleEffect(appear ? 1 : 0.92)
                .opacity(appear ? 1 : 0.85)

                VStack(spacing: 6) {
                    Text("FamilyHub")
                        .font(.system(size: 36, weight: .semibold, design: .serif))
                        .foregroundStyle(AppTheme.text)
                    Text("The household, in one place")
                        .font(.title3)
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
