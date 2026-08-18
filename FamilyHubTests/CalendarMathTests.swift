import XCTest
@testable import FamilyHub

final class CalendarMathTests: XCTestCase {
    func testFamilyFilterIncludesEveryone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!
        let alex = UUID()
        let events = [
            CalendarEvent.make(title: "Family dinner", startAt: day),
            CalendarEvent.make(title: "Soccer", startAt: day, memberID: alex),
        ]
        XCTAssertEqual(CalendarMath.events(events, on: day, filter: .family, calendar: calendar).count, 2)
        XCTAssertEqual(CalendarMath.events(events, on: day, filter: .member(alex), calendar: calendar).count, 2)
        XCTAssertEqual(CalendarMath.events(events, on: day, filter: .member(UUID()), calendar: calendar).count, 1)
    }

    func testMonthGridAlwaysFortyTwoDays() {
        let date = Date(timeIntervalSince1970: 1_787_000_000)
        XCTAssertEqual(CalendarMath.monthDays(containing: date).count, 42)
    }

    func testPersonStyleMapsLegacySymbolsToEmoji() {
        XCTAssertEqual(PersonStyle.emoji(fromStored: "figure.run"), "🏃")
        XCTAssertEqual(PersonStyle.emoji(fromStored: "⚽️"), "⚽️")
        XCTAssertTrue(PersonStyle.colors.count >= 24)
        XCTAssertTrue(PersonStyle.emojis.count >= 24)
    }

    func testWeatherIconMapsClearAndStorm() {
        XCTAssertEqual(WeatherIcon.symbol(for: 0), "sun.max.fill")
        XCTAssertEqual(WeatherIcon.symbol(for: 95), "cloud.bolt.rain.fill")
        XCTAssertEqual(WeatherIcon.condition(for: 0), "Clear")
        XCTAssertEqual(WeatherIcon.condition(for: 3), "Cloudy")
    }

    func testDefaultHubWidgetsStartWithCamerasWeatherAndSnapshot() {
        XCTAssertEqual(HubWidget.defaultSet.map(\.kind), [.cameras, .weather, .snapshot])
    }

    func testCalendarBrandInfersMajorProviders() {
        XCTAssertEqual(CalendarBrand.infer(sourceTitle: "iCloud", typeName: "caldav"), .icloud)
        XCTAssertEqual(CalendarBrand.infer(sourceTitle: "Gmail", typeName: "caldav"), .google)
        XCTAssertEqual(CalendarBrand.infer(sourceTitle: "Outlook", typeName: "caldav"), .outlook)
        XCTAssertEqual(CalendarBrand.infer(sourceTitle: "Work", typeName: "exchange"), .exchange)
    }

    func testICSParserReadsEventAndWeeklyRule() {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:soccer-1
        SUMMARY:Soccer practice
        DTSTART:20260817T163000
        DTEND:20260817T180000
        LOCATION:Lincoln Park
        RRULE:FREQ=WEEKLY;COUNT=4
        END:VEVENT
        END:VCALENDAR
        """
        let source = UUID()
        let parsed = ICSParser.parse(ics, sourceID: source, now: Date(timeIntervalSince1970: 1_787_000_000))
        XCTAssertGreaterThanOrEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.title, "Soccer practice")
        XCTAssertEqual(parsed.first?.location, "Lincoln Park")
        XCTAssertEqual(parsed.first?.sourceID, source)
        XCTAssertTrue(parsed.allSatisfy(\.isImported))
    }

    func testICSParserAllDayDate() {
        let parsed = ICSParser.parseDate("DTSTART;VALUE=DATE:20260817")
        XCTAssertEqual(parsed?.allDay, true)
        XCTAssertNotNil(parsed?.date)
    }

    @MainActor
    func testReplaceImportedLeavesLocalEvents() {
        let store = HubStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let local = CalendarEvent.make(title: "Family dinner", startAt: Date())
        store.addEvent(local)
        let source = UUID()
        store.replaceImportedEvents(sourceID: source, with: [
            CalendarEvent.make(title: "Imported", startAt: Date(), sourceID: source, externalID: "abc"),
        ])
        XCTAssertTrue(store.events.contains(where: { $0.title == "Family dinner" && !$0.isImported }))
        XCTAssertTrue(store.events.contains(where: { $0.title == "Imported" && $0.isImported }))
        store.replaceImportedEvents(sourceID: source, with: [])
        XCTAssertTrue(store.events.contains(where: { $0.title == "Family dinner" }))
        XCTAssertFalse(store.events.contains(where: { $0.title == "Imported" }))
    }

    @MainActor
    func testDinnerPlanUsesRecipeName() {
        let store = HubStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let recipe = Recipe.make(name: "Tacos", kind: .recipe)
        store.addRecipe(recipe)
        let day = Date()
        store.setDinner(on: day, recipeID: recipe.id)
        XCTAssertEqual(store.dinnerTitle(on: day), "Tacos")
        store.clearDinner(on: day)
        XCTAssertNil(store.dinnerTitle(on: day))
    }
}
