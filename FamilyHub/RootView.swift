import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HubStore
    @AppStorage("familyhub.onboarding.completed.v4") private var onboardingCompleted = false
    @State private var showSplash = true

    private var needsSetup: Bool {
        if store.setupCompleted || onboardingCompleted { return false }
        if !store.members.isEmpty { return false }
        return true
    }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            if showSplash {
                LaunchSplashView()
                    .zIndex(3)
            } else if needsSetup {
                OnboardingView {
                    store.markSetupComplete()
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
        .preferredColorScheme(store.appearance.colorScheme)
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

            VStack(spacing: 18) {
                Image("HubMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .scaleEffect(appear ? 1 : 0.92)
                    .opacity(appear ? 1 : 0.85)

                Text("HUB Circle")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.text)
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
        .environmentObject(CalendarIngestor())
}
