import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.scenePhase) private var scenePhase
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

            switch HubLaunchScreen.choose(splash: showSplash, loadFailed: store.loadFailed, needsSetup: needsSetup) {
            case .splash:
                LaunchSplashView()
                    .zIndex(3)
            case .corrupt:
                CorruptHouseView()
                    .transition(.opacity)
                    .zIndex(4)
            case .setup:
                OnboardingView {
                    store.markSetupComplete()
                    withAnimation(.easeInOut(duration: 0.35)) {
                        onboardingCompleted = true
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            case .home:
                MainHubView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(store.appearance.colorScheme)
        .tint(AppTheme.blue)
        .background(AppTheme.bg.ignoresSafeArea())
        .onChange(of: scenePhase) { _, phase in
            if phase == .active || phase == .background {
                HubPinger.shared.refresh(store)
            }
        }
        .alert("HUB", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onAppear {
            LaunchTiming.mark("first frame")
                HubPinger.shared.refresh(store)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }
}

struct CorruptHouseView: View {
    @EnvironmentObject private var store: HubStore
    @State private var note: String?
    @State private var confirmErase = false
    @State private var eraseError: String?
    @State private var showRetry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This HUB could not be read")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text(store.loadFailureDetail ?? "The saved file is still on this device. It was not replaced with an empty house.")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Button("Restore from backup") {
                note = store.restoreNewestBackup()
            }
            .buttonStyle(.borderedProminent)
            if let note {
                Text(note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.chore)
            }
            Button("Erase") { confirmErase = true }
                .foregroundStyle(AppTheme.chore)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.bg.ignoresSafeArea())
        .alert("This destroys the only copy", isPresented: $confirmErase) {
            Button("Erase the only copy", role: .destructive) {
                Task { await runErase() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Erase deletes the iCloud share and then removes the unreadable file and its backup. If this file is the only copy, it cannot be brought back.")
        }
        .alert("Erase did not finish", isPresented: $showRetry) {
            Button("Retry") { Task { await runErase() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(eraseError ?? "iCloud did not confirm the delete. This HUB is still on this device.")
        }
    }

    private func runErase() async {
        if let error = await store.eraseHousehold() {
            eraseError = error
            showRetry = true
        }
    }
}

struct LaunchSplashView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false

    var body: some View {
        ZStack {
            AppTheme.space.ignoresSafeArea()

            HStack(spacing: 18) {
                HubOrbitMark(size: 120, animated: true)
                HubWordmark(onDark: true, hubSize: 44, circleSize: 24)
            }
            .padding(.horizontal, 28)
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
