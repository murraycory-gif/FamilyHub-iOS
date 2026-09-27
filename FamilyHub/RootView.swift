import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("familyhub.onboarding.completed.v4") private var onboardingCompleted = false
    @State private var showSplash = true

    private var launchScreen: HubLaunchScreen {
        HubLaunchScreen.restored(
            splash: showSplash,
            loadFailed: store.loadFailed,
            hasLocalCircle: CircleLaunch.hasLocalCircle(setupCompleted: store.setupCompleted, memberCount: store.members.count),
            phase: store.circlePhase
        )
    }

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            switch launchScreen {
            case .splash:
                LaunchSplashView()
                    .zIndex(3)
            case .finding:
                FindingFamilyView(failed: store.circlePhase == .failed) {
                    Task { await store.discoverExistingCircle() }
                }
                .transition(.opacity)
                .zIndex(3)
            case .noICloud:
                NoICloudFamilyView(
                    onRetry: { Task { await store.discoverExistingCircle() } },
                    onCreate: { store.circlePhase = .empty }
                )
                .transition(.opacity)
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
        .onChange(of: store.setupCompleted) { _, done in
            if done { onboardingCompleted = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active || phase == .background {
                HubPinger.shared.refresh(store)
            }
            if phase == .active {
                Task { await refreshChoresFromCloud() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hubCloudChanged)) { _ in
            Task { await refreshChoresFromCloud() }
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
            ChoreReviewCenter.shared.handler = { action, id in
                if action == ChoreReview.approveAction {
                    store.approveAssignment(id)
                } else if action == ChoreReview.sendBackAction {
                    store.sendBackAssignment(id, reason: "")
                }
            }
            Task { await refreshChoresFromCloud() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }

    private func refreshChoresFromCloud() async {
        await store.ensureChoreSubscription()
        await store.pullHousehold()
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
                Task { note = await store.restoreNewestBackup() }
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

struct FindingFamilyView: View {
    var failed: Bool
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if failed == false {
                ProgressView()
                    .controlSize(.large)
            }
            Text(failed ? "iCloud did not respond" : "Finding your family...")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(failed
                 ? "Check the connection, then try again. HUB will not ask you to create a new Circle until it knows this iCloud account has none."
                 : "Looking in your iCloud for a Circle you already created on another device.")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if failed {
                Button("Try again", action: onRetry)
                    .buttonStyle(PrimaryButtonStyle())
            }
            CloudEnvironmentNote()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

struct NoICloudFamilyView: View {
    var onRetry: () -> Void
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in to iCloud")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("HUB looks in this Apple ID’s iCloud for the Circle already on your iPad or another iPhone. Open Settings, sign in to iCloud, then try again.")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try again", action: onRetry)
                .buttonStyle(PrimaryButtonStyle())
            Button("Create a Circle on this iPhone", action: onCreate)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
            CloudEnvironmentNote()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

struct CloudEnvironmentNote: View {
    var body: some View {
        #if DEBUG
        Text("This Xcode install looks in iCloud Development. TestFlight and the App Store look in iCloud Production. A family saved in one does not appear in the other.")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        #else
        EmptyView()
        #endif
    }
}

struct LaunchSplashView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var appear = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            HStack(spacing: 18) {
                HubOrbitMark(size: 120, animated: true)
                HubWordmark(onDark: false, hubSize: 44, circleSize: 24)
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
