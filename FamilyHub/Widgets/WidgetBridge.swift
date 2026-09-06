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
