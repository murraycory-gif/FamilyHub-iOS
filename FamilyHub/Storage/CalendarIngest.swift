import EventKit
import Foundation
import UIKit

struct DiscoveredCalendar: Identifiable, Hashable {
    var id: String { eventKitID }
    var eventKitID: String
    var title: String
    var account: String
    var brand: CalendarBrand
    var colorHex: String
}

@MainActor
final class CalendarIngestor: ObservableObject {
    @Published var authorization: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var available: [DiscoveredCalendar] = []
    @Published var isSyncing = false
    @Published var message: String?

    private let ekStore = EKEventStore()
    private var observer: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var pendingSync: Task<Void, Never>?
    private weak var hub: HubStore?

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorization == .fullAccess || authorization == .authorized
        }
        return authorization == .authorized
    }

    func refreshStatus() {
        authorization = EKEventStore.authorizationStatus(for: .event)
        if isAuthorized {
            available = EventKitBridge.list(store: ekStore)
        }
    }

    func requestAccess() async {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await ekStore.requestFullAccessToEvents()
            } else {
                granted = try await ekStore.requestAccess(to: .event)
            }
            authorization = EKEventStore.authorizationStatus(for: .event)
            if granted {
                available = EventKitBridge.list(store: ekStore)
                message = available.isEmpty
                    ? "No calendars on this iPad yet. Add iCloud, Google, or Outlook in Settings → Calendar → Accounts."
                    : "Found \(available.count) calendars on this iPad."
            } else {
                message = "Calendar access is off. Turn it on in Settings to pull in iCloud, Google, and Outlook."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
    }

    func attach(_ hub: HubStore) {
        self.hub = hub
        refreshStatus()
        startWatching()
        if isAuthorized {
            hub.upsertCalendarSources(available)
            scheduleSync(quiet: true)
        }
    }

    func startWatching() {
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: ekStore,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.scheduleSync(quiet: true)
                }
            }
        }
        if foregroundObserver == nil {
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshStatus()
                    self?.scheduleSync(quiet: true)
                }
            }
        }
    }

    func scheduleSync(quiet: Bool = true) {
        pendingSync?.cancel()
        pendingSync = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let hub else { return }
            await sync(into: hub, quiet: quiet)
        }
    }

    func writableCalendars() -> [DiscoveredCalendar] {
        EventKitBridge.writable(store: ekStore)
    }

    func saveToDevice(
        calendarID: String,
        title: String,
        start: Date,
        end: Date?,
        allDay: Bool,
        location: String,
        notes: String
    ) throws -> String {
        try EventKitBridge.save(
            store: ekStore,
            calendarID: calendarID,
            title: title,
            start: start,
            end: end,
            allDay: allDay,
            location: location,
            notes: notes
        )
    }

    func sync(into hub: HubStore, quiet: Bool = false) async {
        isSyncing = true
        defer { isSyncing = false }
        var imported = 0
        for source in hub.calendarSources where source.isEnabled {
            do {
                let events: [CalendarEvent]
                if let eventKitID = source.eventKitID {
                    events = EventKitBridge.events(
                        store: ekStore,
                        calendarID: eventKitID,
                        sourceID: source.id,
                        memberID: source.memberID
                    )
                } else if let urlString = source.icsURL, let url = URL(string: urlString) {
                    let data = try await URLSession.shared.data(from: url).0
                    let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
                    events = ICSParser.parse(text, sourceID: source.id, memberID: source.memberID)
                } else {
                    continue
                }
                hub.replaceImportedEvents(sourceID: source.id, with: events)
                hub.markSourceSynced(source.id)
                imported += events.count
            } catch {
                if !quiet { message = "Could not sync \(source.title)." }
            }
        }
        if !quiet {
            message = imported == 0 ? "No events in the open window." : "Brought in \(imported) events."
        }
    }
}

enum EventKitBridge {
    static func list(store: EKEventStore) -> [DiscoveredCalendar] {
        store.calendars(for: .event)
            .filter { $0.type != .birthday }
            .compactMap { calendar -> DiscoveredCalendar? in
                guard let source = calendar.source else { return nil }
                return DiscoveredCalendar(
                    eventKitID: calendar.calendarIdentifier,
                    title: calendar.title,
                    account: source.title,
                    brand: CalendarBrand.infer(
                        sourceTitle: source.title,
                        typeName: sourceTypeName(source.sourceType)
                    ),
                    colorHex: hex(from: calendar.cgColor) ?? "3B82F6"
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func writable(store: EKEventStore) -> [DiscoveredCalendar] {
        list(store: store).filter { discovered in
            store.calendar(withIdentifier: discovered.eventKitID)?.allowsContentModifications == true
        }
    }

    static func save(
        store: EKEventStore,
        calendarID: String,
        title: String,
        start: Date,
        end: Date?,
        allDay: Bool,
        location: String,
        notes: String
    ) throws -> String {
        guard let calendar = store.calendar(withIdentifier: calendarID) else {
            throw CalendarWriteError.missingCalendar
        }
        guard calendar.allowsContentModifications else {
            throw CalendarWriteError.readOnly
        }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.isAllDay = allDay
        event.startDate = start
        if allDay {
            event.endDate = end ?? Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        } else {
            event.endDate = end ?? start.addingTimeInterval(3600)
        }
        event.location = location.isEmpty ? nil : location
        event.notes = notes.isEmpty ? nil : notes
        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    enum CalendarWriteError: LocalizedError {
        case missingCalendar
        case readOnly

        var errorDescription: String? {
            switch self {
            case .missingCalendar: return "That calendar isn’t on this iPad anymore."
            case .readOnly: return "That calendar is read-only."
            }
        }
    }

    private static func sourceTypeName(_ type: EKSourceType) -> String {
        switch type {
        case .exchange: return "exchange"
        case .calDAV: return "caldav"
        case .mobileMe: return "icloud"
        case .subscribed: return "subscribed"
        case .local: return "local"
        case .birthdays: return "birthdays"
        @unknown default: return "other"
        }
    }

    static func events(store: EKEventStore, calendarID: String, sourceID: UUID, memberID: UUID?) -> [CalendarEvent] {
        guard let calendar = store.calendar(withIdentifier: calendarID) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 180, to: Date()) ?? Date()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        return store.events(matching: predicate).map { event in
            CalendarEvent.make(
                title: event.title ?? "Event",
                startAt: event.startDate,
                endAt: event.endDate,
                allDay: event.isAllDay,
                location: event.location ?? "",
                notes: event.notes ?? "",
                memberID: memberID,
                sourceID: sourceID,
                externalID: event.eventIdentifier
            )
        }
    }

    private static func hex(from color: CGColor?) -> String? {
        guard let comps = color?.components, comps.count >= 3 else { return nil }
        let r = Int((comps[0] * 255).rounded())
        let g = Int((comps[1] * 255).rounded())
        let b = Int((comps[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

enum ICSParser {
    static func parse(_ raw: String, sourceID: UUID, memberID: UUID? = nil, now: Date = Date()) -> [CalendarEvent] {
        let unfolded = unfold(raw)
        var events: [CalendarEvent] = []
        var block: [String: String] = [:]
        var inEvent = false

        for line in unfolded.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "BEGIN:VEVENT" {
                inEvent = true
                block = [:]
                continue
            }
            if line == "END:VEVENT" {
                if let event = event(from: block, sourceID: sourceID, memberID: memberID, now: now) {
                    events.append(contentsOf: event)
                }
                inEvent = false
                continue
            }
            guard inEvent, let colon = line.firstIndex(of: ":") else { continue }
            let keyPart = String(line[..<colon])
            let value = String(line[line.index(after: colon)...])
            let key = keyPart.split(separator: ";").first.map(String.init)?.uppercased() ?? keyPart
            block[key] = value
            if key == "DTSTART" { block["DTSTART_RAW"] = keyPart + ":" + value }
            if key == "DTEND" { block["DTEND_RAW"] = keyPart + ":" + value }
        }
        return events
    }

    static func unfold(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
    }

    static func parseDate(_ raw: String) -> (date: Date, allDay: Bool)? {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        let value = parts.last ?? raw
        let meta = parts.first ?? ""
        let allDay = meta.contains("VALUE=DATE") || (value.count == 8 && !value.contains("T"))
        let cleaned = value.replacingOccurrences(of: "Z", with: "")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = value.hasSuffix("Z") ? TimeZone(secondsFromGMT: 0) : .current
        if allDay {
            formatter.dateFormat = "yyyyMMdd"
        } else if cleaned.count >= 15 {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        } else {
            formatter.dateFormat = "yyyyMMdd'T'HHmm"
        }
        guard let date = formatter.date(from: String(cleaned.prefix(allDay ? 8 : 15))) else { return nil }
        return (date, allDay)
    }

    private static func event(from block: [String: String], sourceID: UUID, memberID: UUID?, now: Date) -> [CalendarEvent]? {
        guard let title = block["SUMMARY"], !title.isEmpty else { return nil }
        let startRaw = block["DTSTART_RAW"] ?? block["DTSTART"] ?? ""
        guard let start = parseDate(startRaw) else { return nil }
        let end = (block["DTEND_RAW"] ?? block["DTEND"]).flatMap(parseDate)
        let uid = block["UID"] ?? title + start.date.description
        let base = CalendarEvent.make(
            title: unescape(title),
            startAt: start.date,
            endAt: end?.date,
            allDay: start.allDay,
            location: unescape(block["LOCATION"] ?? ""),
            notes: unescape(block["DESCRIPTION"] ?? ""),
            memberID: memberID,
            sourceID: sourceID,
            externalID: uid
        )
        guard let rrule = block["RRULE"] else { return [base] }
        return expand(base, rule: rrule, now: now)
    }

    static func expand(_ base: CalendarEvent, rule: String, now: Date, horizonDays: Int = 180) -> [CalendarEvent] {
        let parts = Dictionary(uniqueKeysWithValues: rule.split(separator: ";").compactMap { chunk -> (String, String)? in
            let bits = chunk.split(separator: "=", maxSplits: 1)
            guard bits.count == 2 else { return nil }
            return (bits[0].uppercased(), String(bits[1]))
        })
        let freq = parts["FREQ"] ?? ""
        let interval = Int(parts["INTERVAL"] ?? "1") ?? 1
        let count = Int(parts["COUNT"] ?? "80") ?? 80
        let until = parts["UNTIL"].flatMap { parseDate($0.hasPrefix("UNTIL") ? $0 : "UNTIL:" + $0)?.date }
        let end = Calendar.current.date(byAdding: .day, value: horizonDays, to: now) ?? now
        var component: Calendar.Component?
        switch freq {
        case "DAILY": component = .day
        case "WEEKLY": component = .weekOfYear
        case "MONTHLY": component = .month
        default: return [base]
        }
        var result: [CalendarEvent] = []
        var cursor = base.startAt
        let span = base.endAt.map { $0.timeIntervalSince(base.startAt) } ?? 0
        var made = 0
        while made < min(count, 80), cursor <= end {
            if let until, cursor > until { break }
            if cursor >= Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now {
                var copy = base
                copy.id = UUID()
                copy.startAt = cursor
                if span > 0 { copy.endAt = cursor.addingTimeInterval(span) }
                copy.externalID = (base.externalID ?? "") + "-\(made)"
                result.append(copy)
            }
            guard let next = Calendar.current.date(byAdding: component!, value: interval, to: cursor) else { break }
            cursor = next
            made += 1
        }
        return result.isEmpty ? [base] : result
    }

    static func unescape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
