import SwiftUI
import UIKit
import UserNotifications

final class HubAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        MainActor.assumeIsolated {
            center.delegate = ChoreReviewCenter.shared
            ChoreReviewCenter.registerCategories()
        }
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        NotificationCenter.default.post(name: .hubCloudChanged, object: nil)
        return .newData
    }
}

@main
struct FamilyHubApp: App {
    @UIApplicationDelegateAdaptor(HubAppDelegate.self) private var appDelegate
    @StateObject private var store = HubStore()
    @StateObject private var ingest = CalendarIngestor()

    private let launchUI = UIColor { trait in
        let hex = trait.userInterfaceStyle == .dark ? HubPalette.darkBackground : HubPalette.lightBackground
        return UIColor(Color(hex: hex))
    }
    private let launchInk = UIColor { trait in
        let hex = trait.userInterfaceStyle == .dark ? HubPalette.labelDark : HubPalette.labelLight
        return UIColor(Color(hex: hex))
    }

    init() {
        UIWindow.appearance().backgroundColor = launchUI
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = launchUI
        nav.largeTitleTextAttributes = [
            .foregroundColor: launchInk,
        ]
        nav.titleTextAttributes = [
            .foregroundColor: launchInk,
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(Color(hex: HubPalette.brand))
        LaunchTiming.mark("app init")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppTheme.bg.ignoresSafeArea()
                RootView()
                    .environmentObject(store)
                    .environmentObject(ingest)
                    .onAppear {
                        ingest.attach(store)
                        HubPinger.shared.refresh(store)
                    }
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .preferredColorScheme(store.appearance.colorScheme)
            .onAppear {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .forEach { $0.backgroundColor = launchUI }
            }
        }
    }
}
