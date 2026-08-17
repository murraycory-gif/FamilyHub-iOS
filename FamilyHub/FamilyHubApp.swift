import SwiftUI
import UIKit

@main
struct FamilyHubApp: App {
    @StateObject private var store = HubStore()

    private let launchPaperUI = UIColor(red: 0.957, green: 0.937, blue: 0.902, alpha: 1)
    private let launchPaper = Color(red: 0.957, green: 0.937, blue: 0.902)

    init() {
        UIWindow.appearance().backgroundColor = launchPaperUI
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                launchPaper.ignoresSafeArea()
                RootView()
                    .environmentObject(store)
            }
            .background(launchPaper.ignoresSafeArea())
            .onAppear {
                UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows)
                    .forEach { $0.backgroundColor = launchPaperUI }
            }
        }
    }
}
