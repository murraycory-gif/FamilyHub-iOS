import Foundation
import os

enum BuildStamp {
    static let string = "HUB-0906.7"
}

enum LaunchLog {
    static let start = ContinuousClock.now
    private static let log = Logger(subsystem: "com.corymurray.FamilyHub", category: "launch")

    static func milliseconds() -> Int {
        let parts = (ContinuousClock.now - start).components
        return parts.seconds * 1000 + Int(parts.attoseconds / 1_000_000_000_000_000)
    }

    static func mark(_ label: String) {
        let ms = milliseconds()
        log.notice("\(label, privacy: .public) \(ms, privacy: .public)ms")
    }
}
