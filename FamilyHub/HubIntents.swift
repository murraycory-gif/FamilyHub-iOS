import AppIntents
import Foundation

@MainActor
enum HubAccess {
    static weak var store: HubStore?

    static func live() -> HubStore {
        if let store { return store }
        let created = HubStore()
        store = created
        return created
    }
}

struct WhatsOnTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "What's on today"
    static var description = IntentDescription("Read today's family agenda from HUB Circle.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { HubAccess.agenda(on: Date()) }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct NextEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Next event"
    static var description = IntentDescription("The next thing on the HUB Circle calendar.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = await MainActor.run { HubAccess.nextEvent() }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct AddGroceryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to grocery list"
    static var description = IntentDescription("Add an item to the HUB Circle shopping list.")
    static var openAppWhenRun = false

    @Parameter(title: "Item")
    var item: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return .result(dialog: "Say what to add.")
        }
        await MainActor.run { HubAccess.live().addShoppingItem(name) }
        return .result(dialog: IntentDialog(stringLiteral: "Added \(name) to the grocery list."))
    }
}

struct HubShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WhatsOnTodayIntent(), phrases: ["What's on today in \(.applicationName)", "What's on today's agenda in \(.applicationName)"], shortTitle: "What's on today", systemImageName: "calendar")
        AppShortcut(intent: NextEventIntent(), phrases: ["Next event in \(.applicationName)", "What's next in \(.applicationName)"], shortTitle: "Next event", systemImageName: "clock")
        AppShortcut(intent: AddGroceryIntent(), phrases: ["Add to the grocery list in \(.applicationName)"], shortTitle: "Add grocery item", systemImageName: "cart")
    }
}

extension HubAccess {
    static func agenda(on day: Date) -> String {
        let store = live()
        let events = store.events(on: day, filter: .family)
        let dinner = store.dinnerTitle(on: day) ?? "Dinner not set"
        if events.isEmpty { return "Nothing on the calendar. \(dinner)." }
        let lines = events.prefix(5).map { event in
            event.allDay ? event.title : "\(Date.hubClock(event.startAt)) \(event.title)"
        }
        return lines.joined(separator: ", ") + ". \(dinner)."
    }

    static func nextEvent() -> String {
        let store = live()
        guard let next = store.events.filter({ $0.startAt > Date() }).sorted(by: { $0.startAt < $1.startAt }).first else {
            return "Nothing else on the calendar."
        }
        let when = next.allDay ? "All day" : Date.hubClock(next.startAt)
        return "\(next.title), \(when)."
    }
}
