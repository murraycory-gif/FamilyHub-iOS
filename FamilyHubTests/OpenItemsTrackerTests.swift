import XCTest

final class OpenItemsTrackerTests: XCTestCase {
    func testOpenItemsFileExists() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = root.appendingPathComponent("OPEN_ITEMS.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path.path), "OPEN_ITEMS.md missing at repo root")
    }
}
