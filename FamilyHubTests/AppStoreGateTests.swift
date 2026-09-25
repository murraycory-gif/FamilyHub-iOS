import XCTest
@testable import FamilyHub

@MainActor
final class AppStoreGateTests: XCTestCase {
    func testNewJoinCodeIsLongAndLegacyCodesStillWork() {
        let code = HubJoinCode.make()
        XCTAssertEqual(code.count, HubJoinCode.length)
        XCTAssertTrue(HubJoinCode.isAcceptable(code))
        XCTAssertNotEqual(HubJoinCode.make(), code)
        XCTAssertTrue(HubJoinCode.isAcceptable("AB12CD"))
        XCTAssertFalse(HubJoinCode.isAcceptable("ABC"))
        XCTAssertFalse(HubJoinCode.isAcceptable("AB12C0"))
    }

    func testJoinCodeRefreshIsRateLimited() {
        UserDefaults.standard.removeObject(forKey: HubStore.issueTimesKey)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = HubStore(rootURL: root)
        store.refreshJoinCode()
        for _ in 0..<4 { store.refreshJoinCode() }
        let held = store.joinCode
        store.refreshJoinCode()
        XCTAssertEqual(store.joinCode, held)
        XCTAssertEqual(store.errorMessage, "Too many new codes this hour. Try again later.")
        UserDefaults.standard.removeObject(forKey: HubStore.issueTimesKey)
    }

    func testExistingSixCharacterHouseholdCodeIsKept() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var snapshot = HubStore.emptySnapshot()
        snapshot.householdName = "Murray"
        snapshot.joinCode = "AB12CD"
        snapshot.issuedJoinCodes = ["AB12CD"]
        snapshot.schemaVersion = HubSnapshot.currentSchema
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: root.appendingPathComponent("hub.json"))
        let store = HubStore(rootURL: root)
        XCTAssertEqual(store.joinCode, "AB12CD")
    }

    func testHTTPSOnlyLinksAndBackupExclusion() throws {
        XCTAssertEqual(ICSLink.normalize("http://school.example/cal.ics"), "https://school.example/cal.ics")
        XCTAssertEqual(ICSLink.httpsURL(from: "webcal://school.example/cal.ics")?.scheme, "https")
        XCTAssertNil(ICSLink.httpsURL(from: "ftp://school.example/cal.ics"))
        XCTAssertNil(RecipeThumbs.owned("http://cdn.example/a.jpg"))
        XCTAssertEqual(RecipeThumbs.owned("https://cdn.example/a.jpg")?.scheme, "https")

        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try Data("{}".utf8).write(to: file)
        HubFilePrivacy.excludeFromBackup(file)
        let values = try file.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)

        let plist = try String(contentsOf: sourceRoot().appendingPathComponent("FamilyHub/Info.plist"), encoding: .utf8)
        XCTAssertTrue(plist.contains("<key>NSAllowsArbitraryLoads</key>"))
        XCTAssertTrue(plist.contains("<false/>"))
        XCTAssertFalse(plist.contains("NSLocationAlwaysAndWhenInUseUsageDescription"))
        XCTAssertTrue(plist.contains("does not track location in the background"))
        XCTAssertFalse(plist.contains("http://maps.apple.com"))
        let places = try String(contentsOf: sourceRoot().appendingPathComponent("FamilyHub/Storage/PlaceImages.swift"), encoding: .utf8)
        XCTAssertFalse(places.lowercased().contains("bing"))
        XCTAssertFalse(places.lowercased().contains("duckduckgo"))
        XCTAssertTrue(places.contains("MKLookAroundSceneRequest"))
        let maps = try String(contentsOf: sourceRoot().appendingPathComponent("FamilyHub/Views/PlaceDetailView.swift"), encoding: .utf8)
        XCTAssertFalse(maps.contains("http://maps.apple.com"))
        XCTAssertTrue(maps.contains("https://maps.apple.com"))
    }

    private func sourceRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
