import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: HubStore
    @AppStorage("familyhub.onboarding.completed.v4") private var onboardingCompleted = false
    @State private var showSplash = true
    @State private var yesReply = ""
    @State private var showYes = false

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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if !HubPinger.shared.pendingCode.isEmpty { showYes = true }
        }
        .onChange(of: showSplash) { _, showing in
            if !showing, !HubPinger.shared.pendingCode.isEmpty { showYes = true }
        }
        .overlay {
            if showYes {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    Text("Confirm this number")
                        .font(.title2.weight(.bold))
                    Text("Send the text from Messages, then type YES or the 4-digit code here. Apple will not let HUB send SMS by itself, so you tap Send in Messages.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("YES", text: $yesReply)
                        .textInputAutocapitalization(.characters)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3.weight(.bold))
                    HStack {
                        Button("Not now") { showYes = false }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Button("Confirm") {
                            if HubPinger.shared.confirmConnect(store, reply: yesReply) {
                                showYes = false
                                yesReply = ""
                            }
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.blue, in: Capsule())
                    }
                }
                .padding(22)
                .frame(maxWidth: 420)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 3)
                )
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

                Text("HUB")
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(4)
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
