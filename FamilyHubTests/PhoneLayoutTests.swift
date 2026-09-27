import XCTest
@testable import FamilyHub

@MainActor
final class PhoneLayoutTests: XCTestCase {
    func testPhoneTabsKeepChoresOneTapAway() {
        XCTAssertEqual(HubSection.phoneTabs, [.today, .calendar, .chores, .meals, .more])
        XCTAssertTrue(HubSection.phoneTabs.contains(.chores))
        XCTAssertTrue(HubSection.moreItems.contains(.shopping))
        XCTAssertFalse(HubSection.phoneTabs.contains(.shopping))
    }

    func testCardTitlesDropTheHubPrefix() {
        XCTAssertEqual(HubTileTitle.text(lead: "HUB", title: "Shopping"), "Shopping")
        XCTAssertEqual(HubTileTitle.text(lead: "What's For", title: "Dinner"), "Dinner")
        XCTAssertEqual(HubTileTitle.text(lead: "HUB", title: "  "), "Circle")
        XCTAssertEqual(HubTileTitle.text(lead: "Flights", title: ""), "Flights")
        XCTAssertFalse(HubTileTitle.text(lead: "HUB", title: "Jobs").contains("|"))
        XCTAssertFalse(HubTileTitle.text(lead: "HUB", title: "Streaks").contains("HUB"))
    }

    func testLandingPageScrollsAndDoesNotPinFamily() {
        XCTAssertTrue(LandingLayout.scrollsAsOnePage)
        XCTAssertFalse(LandingLayout.familyIsPinned)
    }

    func testWarmPaperAndCharcoalClearContrast() {
        XCTAssertEqual(HubPalette.lightBackground, "F7F2EA")
        XCTAssertEqual(HubPalette.lightCard, "FFFFFF")
        XCTAssertEqual(HubPalette.darkBackground, "2E3338")
        XCTAssertEqual(HubPalette.darkCard, "3C4248")
        XCTAssertEqual(HubPalette.brand, "0C5F78")
        XCTAssertGreaterThanOrEqual(contrast("FFFFFF", HubPalette.brand), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.celebrateInkLight, HubPalette.celebrateFillLight), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.celebrateInkDark, HubPalette.celebrateFillDark), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.labelLight, HubPalette.lightBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.labelDark, HubPalette.darkBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.secondaryDark, HubPalette.darkCard), 4.5)
    }

    func testLayoutSourcesUseOneScrollAndPlainTitles() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let today = try String(contentsOf: root.appendingPathComponent("FamilyHub/Views/TodayView.swift"), encoding: .utf8)
        let chrome = try String(contentsOf: root.appendingPathComponent("FamilyHub/Views/SharedViews.swift"), encoding: .utf8)
        let chores = try String(contentsOf: root.appendingPathComponent("FamilyHub/Views/ChoresView.swift"), encoding: .utf8)
        let theme = try String(contentsOf: root.appendingPathComponent("FamilyHub/AppTheme.swift"), encoding: .utf8)
        XCTAssertTrue(today.contains("LandingLayout"))
        XCTAssertTrue(today.contains("ScrollView"))
        XCTAssertFalse(today.contains("familyStripHeight"))
        XCTAssertFalse(today.contains("func dayPager"))
        XCTAssertTrue(chrome.contains("hubUsesTabBar"))
        XCTAssertTrue(chrome.contains("HubTileTitle"))
        XCTAssertTrue(chores.contains(".navigationBarTitleDisplayMode(.large)"))
        XCTAssertTrue(theme.contains("HubPalette.lightBackground"))
        XCTAssertTrue(theme.contains("HubPalette.darkBackground"))
        XCTAssertFalse(theme.contains("0B1220"))
    }

    private func contrast(_ foreground: String, _ background: String) -> Double {
        func linear(_ channel: Double) -> Double {
            let c = channel / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func luminance(_ hex: String) -> Double {
            let value = UInt64(hex, radix: 16) ?? 0
            let r = Double((value >> 16) & 0xFF)
            let g = Double((value >> 8) & 0xFF)
            let b = Double(value & 0xFF)
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }
}
