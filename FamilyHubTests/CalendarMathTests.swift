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
    }

    func testDefaultHubWidgetsStartWithCamerasWeatherAndSnapshot() {
        XCTAssertEqual(HubWidget.defaultSet.map(\.kind), [.cameras, .weather, .snapshot])
    }
}
