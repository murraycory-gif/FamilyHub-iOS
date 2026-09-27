import XCTest
@testable import FamilyHub

@MainActor
final class CircleContrastTests: XCTestCase {
    func testGreetingUsesPrimaryLabel() {
        XCTAssertEqual(HubGreeting.lead, "Good")
        XCTAssertEqual(HubGreeting.tail(hour: 8), "Morning")
        XCTAssertEqual(HubGreeting.tail(hour: 14), "Afternoon")
        XCTAssertEqual(HubGreeting.tail(hour: 20), "Evening")
        XCTAssertEqual(HubGreeting.textRole, .label)
    }

    func testAgendaCopyDropsTheUnclearFamilySuffix() {
        XCTAssertEqual(AgendaBanner.lead(isToday: true, dayTitle: "Monday"), "Today")
        XCTAssertEqual(AgendaBanner.lead(isToday: false, dayTitle: "Tomorrow"), "Tomorrow")
        XCTAssertEqual(AgendaBanner.scope("Murray"), "Murray")
        XCTAssertNil(AgendaBanner.scope("   "))
        XCTAssertFalse((AgendaBanner.scope("Murray") ?? "").contains("family"))
    }

    func testDinnerEmptyActionReadsAddDinner() {
        XCTAssertEqual(DinnerEmptyCopy.addButton, "Add dinner")
        XCTAssertEqual(DinnerEmptyCopy.hint, "Tap to plan dinner")
        XCTAssertNotEqual(DinnerEmptyCopy.addButton, "Add one under")
    }

    func testStatusChipsNameWhatTheyCount() {
        XCTAssertEqual(StatusChipAccessibility.label(count: 0, title: "Chores"), "0 Chores")
        XCTAssertEqual(StatusChipAccessibility.label(count: 2, title: "Bills Due"), "2 Bills Due")
        XCTAssertEqual(StatusChipAccessibility.label(count: 1, title: "To-dos"), "1 To-dos")
    }

    func testWeatherUnavailableOnErrorDoesNotInventZero() async {
        let weather = WeatherLoader()
        weather.forecastLoader = { _, _ in
            throw NSError(domain: "WeatherKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "not entitled"])
        }
        await weather.load(place: .chicago)
        XCTAssertEqual(weather.errorMessage, "Weather unavailable")
        XCTAssertNil(weather.now)
        XCTAssertTrue(weather.days.isEmpty)
        XCTAssertFalse(weather.isLoading)
        let readout = WeatherReadout.resolve(
            now: weather.now,
            day: weather.days.first,
            isLoading: weather.isLoading,
            failed: weather.errorMessage != nil
        )
        XCTAssertEqual(readout, .unavailable)
    }

    func testMissingForecastIsUnavailableAndARealZeroStays() {
        XCTAssertEqual(
            WeatherReadout.resolve(now: nil, day: nil, isLoading: false, failed: false),
            .unavailable
        )
        XCTAssertEqual(
            WeatherReadout.resolve(now: nil, day: nil, isLoading: true, failed: false),
            .loading
        )
        let freezing = WeatherNow(temp: 0, feelsLike: -2, code: 0, isDay: true)
        XCTAssertEqual(
            WeatherReadout.resolve(now: freezing, day: nil, isLoading: false, failed: false),
            .ready(WeatherReading(temp: 0, high: 0, low: 0, condition: "Clear"))
        )
    }

    func testSecondaryLabelAndStatusChipsClearBodyContrast() {
        let darkSurfaces = [HubPalette.darkBackground, HubPalette.darkCard, HubPalette.darkTable]
        for surface in darkSurfaces {
            XCTAssertGreaterThanOrEqual(contrast(HubPalette.secondaryDark, surface), 4.5, surface)
            XCTAssertGreaterThanOrEqual(contrast(HubPalette.tertiaryDark, surface), 4.5, surface)
            XCTAssertGreaterThanOrEqual(contrast(HubPalette.labelDark, surface), 4.5, surface)
        }
        for surface in [HubPalette.lightCard, HubPalette.lightBackground] {
            XCTAssertGreaterThanOrEqual(contrast(HubPalette.secondaryLight, surface), 4.5, surface)
            XCTAssertGreaterThanOrEqual(contrast(HubPalette.tertiaryLight, surface), 4.5, surface)
            XCTAssertGreaterThanOrEqual(contrast(HubPalette.labelLight, surface), 4.5, surface)
        }
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.chipChoreInkDark, HubPalette.chipChoreFillDark), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.chipChoreInkLight, HubPalette.chipChoreFillLight), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.chipReminderInkDark, HubPalette.chipReminderFillDark), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.chipReminderInkLight, HubPalette.chipReminderFillLight), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.chipTodoInkDark, HubPalette.chipTodoFillDark), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.chipTodoInkLight, HubPalette.chipTodoFillLight), 4.5)
    }

    func testWordmarkCircleUsesSecondaryInk() {
        XCTAssertEqual(HubWordmarkStyle.circleRole, "secondaryLabel")
        XCTAssertEqual(HubWordmarkStyle.circleHex(onDark: false, interface: .light), HubPalette.secondaryLight)
        XCTAssertEqual(HubWordmarkStyle.circleHex(onDark: false, interface: .dark), HubPalette.secondaryDark)
        XCTAssertEqual(HubWordmarkStyle.circleHex(onDark: true, interface: .light), HubPalette.secondaryDark)
        let setupNavy = "06101C"
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.secondaryDark, setupNavy), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.secondaryDark, HubPalette.darkBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(HubPalette.secondaryLight, HubPalette.lightCard), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(ChoreDesk.actionInk, ChoreDesk.actionFill), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(ChoreDesk.noteInkLight, HubPalette.lightCard), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(ChoreDesk.noteInkDark, HubPalette.darkCard), 4.5)
    }

    func testCircleSourcesKeepOneNavControlAndTheCorrectedCopy() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let today = try String(contentsOf: root.appendingPathComponent("FamilyHub/Views/TodayView.swift"), encoding: .utf8)
        let chrome = try String(contentsOf: root.appendingPathComponent("FamilyHub/Views/SharedViews.swift"), encoding: .utf8)
        let hub = try String(contentsOf: root.appendingPathComponent("FamilyHub/MainHubView.swift"), encoding: .utf8)
        XCTAssertFalse(today.contains("Add one under"))
        XCTAssertFalse(today.contains("What's On Today's"))
        XCTAssertFalse(today.contains("householdName) family"))
        XCTAssertTrue(today.contains("DinnerEmptyCopy.addButton"))
        XCTAssertTrue(today.contains("HubGreeting.textRole == .label"))
        XCTAssertFalse(chrome.contains("toolbar(removing: .sidebarToggle)"))
        XCTAssertTrue(chrome.contains("showsCustomMenu"))
        XCTAssertTrue(chrome.contains("hubUsesSystemSidebar"))
        XCTAssertTrue(hub.contains("hubUsesSystemSidebar"))
        let brand = try String(contentsOf: root.appendingPathComponent("FamilyHub/Views/HubBrand.swift"), encoding: .utf8)
        XCTAssertFalse(brand.contains("opacity(0.45)"))
        XCTAssertTrue(brand.contains("HubWordmarkStyle"))
        let chores = try String(contentsOf: root.appendingPathComponent("FamilyHub/Views/ChoresView.swift"), encoding: .utf8)
        XCTAssertFalse(chores.contains("HubStickyHeader"))
        XCTAssertFalse(chores.contains("frame(width: 210"))
        XCTAssertTrue(chores.contains("ChoreDesk.doneButtonMinHeight"))
        XCTAssertTrue(chores.contains("Needs your OK"))
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
