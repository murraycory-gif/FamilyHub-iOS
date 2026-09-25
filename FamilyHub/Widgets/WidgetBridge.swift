import Foundation

enum WidgetBridge {
    static let suite = "group.com.corymurray.FamilyHub"
    static let key = "widget.snapshot"

    struct Snapshot: Codable, Hashable {
        var household: String
        var agendaTitle: String
        var agendaWhen: String
        var dinnerName: String
        var dinnerSide: String
        var leaveTitle: String
        var leaveAt: Date?
        var eventStart: Date?
        var updatedAt: Date
    }

    static func defaults() -> UserDefaults {
        UserDefaults(suiteName: suite) ?? .standard
    }

    static func write(_ snap: Snapshot) {
        if let data = try? JSONEncoder().encode(snap) {
            defaults().set(data, forKey: key)
        }
    }

    /// Next widget refresh. Event boundaries can be sooner; otherwise wait an hour
    /// so Home Screen widgets stay inside the system refresh budget.
    static func nextRefresh(after now: Date = Date(), snap: Snapshot, calendar: Calendar = .current) -> Date {
        var refresh = now.addingTimeInterval(60 * 60)
        if let leave = snap.leaveAt, leave > now {
            refresh = min(refresh, leave)
        }
        if let start = snap.eventStart, start > now {
            refresh = min(refresh, start.addingTimeInterval(60))
        }
        if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime) {
            refresh = min(refresh, midnight)
        }
        return refresh
    }

    static func sameContent(_ lhs: Snapshot, _ rhs: Snapshot) -> Bool {
        lhs.household == rhs.household
            && lhs.agendaTitle == rhs.agendaTitle
            && lhs.agendaWhen == rhs.agendaWhen
            && lhs.dinnerName == rhs.dinnerName
            && lhs.dinnerSide == rhs.dinnerSide
            && lhs.leaveTitle == rhs.leaveTitle
            && lhs.leaveAt == rhs.leaveAt
            && lhs.eventStart == rhs.eventStart
    }

    static func read() -> Snapshot {
        guard let data = defaults().data(forKey: key),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data)
        else {
            return Snapshot(
                household: "HUB Circle",
                agendaTitle: "Nothing on the calendar",
                agendaWhen: "Today",
                dinnerName: "Nothing planned",
                dinnerSide: "",
                leaveTitle: "",
                leaveAt: nil,
                eventStart: nil,
                updatedAt: Date()
            )
        }
        return snap
    }
}
