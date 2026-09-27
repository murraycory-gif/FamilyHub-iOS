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

    private let launchUI = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
    private let launch = Color(red: 0.96, green: 0.97, blue: 0.99)

    init() {
        UIWindow.appearance().backgroundColor = launchUI
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1)
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1),
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
        ]
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1),
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(red: 0, green: 61 / 255, blue: 165 / 255, alpha: 1)
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
