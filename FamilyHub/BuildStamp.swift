import Foundation
import os

enum BuildStamp {
    static let string = "HUB-0906.7"
}

enum LaunchTiming {
    static let start = CFAbsoluteTimeGetCurrent()
    private static let log = Logger(subsystem: "com.corymurray.FamilyHub", category: "launch")

    static func mark(_ name: String) {
        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        log.info("\(name, privacy: .public) \(ms, privacy: .public) ms")
    }
}
