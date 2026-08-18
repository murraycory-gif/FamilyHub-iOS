import SwiftUI
import UIKit

@main
struct FamilyHubApp: App {
    @StateObject private var store = HubStore()

    private let launchUI = UIColor(red: 0.031, green: 0.043, blue: 0.063, alpha: 1)
    private let launch = Color(hex: "080B10")

    init() {
        UIWindow.appearance().backgroundColor = launchUI
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(red: 0.031, green: 0.043, blue: 0.063, alpha: 1)
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1),
            .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
        ]
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.93, green: 0.95, blue: 0.96, alpha: 1),
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(red: 0.77, green: 0.80, blue: 0.84, alpha: 1)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                launch.ignoresSafeArea()
                RootView()
                    .environmentObject(store)
            }
            .background(launch.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .onAppear {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .forEach { $0.backgroundColor = launchUI }
            }
        }
    }
}
