import Foundation
import UIKit
import UserNotifications

@MainActor
final class HubPinger {
    static let shared = HubPinger()
    private let sentKey = "familyhub.notify.sent.v1"
    var lastError: String?

    func refresh(_ store: HubStore) {
        Task { await schedule(store) }
        Task { await fireDue(store) }
    }

    func sendTest(_ store: HubStore) {
        Task {
            await deliver(
                store,
                title: "HUB test",
                body: "If you got this, pings are working.",
                device: true
            )
        }
    }

    func startConnect(_ store: HubStore) {
        lastError = nil
        let numbers = phones(in: store)
        guard !numbers.isEmpty else {
            lastError = "Enter a phone number first."
            return
        }
        let code = String(Int.random(in: 1000...9999))
        var prefs = store.notifyPrefs
        prefs.pendingCode = code
        prefs.phoneVerified = false
        store.setNotifyPrefs(prefs)
        openMessages(
            to: numbers,
            body: "HUB code \(code). Open HUB and type YES or \(code) to confirm this number."
        )
    }

    func confirmConnect(_ store: HubStore, reply: String) -> Bool {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let code = store.notifyPrefs.pendingCode.uppercased()
        guard !text.isEmpty, text == "YES" || text == "Y" || (!code.isEmpty && text == code) else {
            lastError = "Type YES or the 4-digit code from the text."
            return false
        }
        var prefs = store.notifyPrefs
        prefs.phoneVerified = true
        prefs.pendingCode = ""
        store.setNotifyPrefs(prefs)
        lastError = nil
        return true
    }

    func schedule(_ store: HubStore) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let prefs = store.notifyPrefs
        guard prefs.anyOn, prefs.channel.usesDevice else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        var requests: [UNNotificationRequest] = []
        if prefs.morningBrief {
            requests.append(daily("hub.morning", hour: 7, minute: 0, title: "Sunrise brief", body: morningBody(store)))
        }
        if prefs.dinnerPing {
            requests.append(daily("hub.dinner", hour: 16, minute: 0, title: "What's for dinner?", body: dinnerBody(store)))
        }
        if prefs.chorePing {
            requests.append(daily("hub.chores", hour: 8, minute: 0, title: "Chore check", body: choreBody(store)))
        }
        if prefs.billsPing {
            requests.append(daily("hub.bills", hour: 8, minute: 15, title: "Bills Due", body: billsBody(store)))
        }
        if prefs.shoppingPing {
            requests.append(daily("hub.shop", hour: 8, minute: 30, title: "Shopping list", body: shopBody(store)))
        }
        if prefs.eventPings {
            let cal = Calendar.current
            let upcoming = store.events
                .filter { $0.startAt > Date() && $0.startAt < Date().addingTimeInterval(60 * 60 * 24 * 7) }
                .prefix(20)
            for event in upcoming {
                let fire = event.startAt.addingTimeInterval(-30 * 60)
                guard fire > Date() else { continue }
                let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = "Starts in 30 minutes."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
                requests.append(UNNotificationRequest(identifier: "hub.event.\(event.id)", content: content, trigger: trigger))
            }
        }
        for request in requests.prefix(60) {
            try? await center.add(request)
        }
    }

    func fireDue(_ store: HubStore) async {
        let prefs = store.notifyPrefs
        guard prefs.anyOn, prefs.channel.usesText, prefs.phoneVerified, !phones(in: store).isEmpty else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        if prefs.morningBrief, (6...9).contains(hour), mark("morning") {
            await deliver(store, title: "Sunrise brief", body: morningBody(store), device: false)
        }
        if prefs.dinnerPing, (15...18).contains(hour), store.dinner(on: Date()) == nil, mark("dinner") {
            await deliver(store, title: "What's for dinner?", body: dinnerBody(store), device: false)
        }
        if prefs.chorePing, (7...9).contains(hour), mark("chores") {
            await deliver(store, title: "Chore check", body: choreBody(store), device: false)
        }
        if prefs.billsPing, (7...9).contains(hour), mark("bills") {
            await deliver(store, title: "Bills Due", body: billsBody(store), device: false)
        }
        if prefs.shoppingPing, (7...9).contains(hour), store.shoppingItems.contains(where: { !$0.isChecked }), mark("shop") {
            await deliver(store, title: "Shopping list", body: shopBody(store), device: false)
        }
        if prefs.eventPings {
            let soon = store.events.filter {
                $0.startAt > Date() && $0.startAt < Date().addingTimeInterval(35 * 60)
            }
            for event in soon where mark("event.\(event.id.uuidString)") {
                await deliver(store, title: event.title, body: "Starts in 30 minutes.", device: false)
            }
        }
    }

    func deliver(_ store: HubStore, title: String, body: String, device: Bool = true) async {
        lastError = nil
        let prefs = store.notifyPrefs
        if device, prefs.channel.usesDevice {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "hub.now.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
        if prefs.channel.usesText, prefs.phoneVerified {
            let numbers = phones(in: store)
            if numbers.isEmpty {
                lastError = "Add a phone number, then tap Connect text."
            } else {
                openMessages(to: numbers, body: "\(title) — \(body)")
            }
        }
    }

    private func phones(in store: HubStore) -> [String] {
        var raw: [String] = [store.notifyPrefs.extraPhone]
        raw.append(store.signedInMember()?.phone ?? "")
        return Array(Set(raw.compactMap(Self.e164))).sorted()
    }

    static func e164(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        if digits.count == 10 { return "+1\(digits)" }
        if digits.count == 11, digits.hasPrefix("1") { return "+\(digits)" }
        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("+"), digits.count >= 10 { return "+\(digits)" }
        return nil
    }

    private func openMessages(to numbers: [String], body: String) {
        let phone = numbers.first ?? ""
        var parts = URLComponents(string: "sms:\(phone)")
        parts?.queryItems = [URLQueryItem(name: "body", value: body)]
        guard let url = parts?.url else {
            lastError = "Could not open Messages."
            return
        }
        UIApplication.shared.open(url)
    }

    private func daily(_ id: String, hour: Int, minute: Int, title: String, body: String) -> UNNotificationRequest {
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
        )
    }

    private func morningBody(_ store: HubStore) -> String {
        let events = store.events(on: Date(), filter: .family).prefix(3).map(\.title)
        let dinner = store.dinnerTitle(on: Date()) ?? "Dinner not set"
        let lead = events.isEmpty ? "Clear calendar." : events.joined(separator: ", ")
        return "\(lead) \(dinner)."
    }

    private func dinnerBody(_ store: HubStore) -> String {
        store.dinnerTitle(on: Date()) ?? "Nothing is set for tonight yet."
    }

    private func choreBody(_ store: HubStore) -> String {
        let open = store.openAssignments().filter { $0.status == .pending }
        return open.isEmpty ? "Board is clear." : "\(open.count) chore(s) still open."
    }

    private func billsBody(_ store: HubStore) -> String {
        let due = store.reminders.filter {
            $0.isBills && !$0.isCompleted && ($0.dueAt.map { Calendar.current.isDateInToday($0) } ?? false)
        }
        return due.isEmpty ? "No bills due today." : due.map(\.title).prefix(3).joined(separator: ", ")
    }

    private func shopBody(_ store: HubStore) -> String {
        let open = store.shoppingItems.filter { !$0.isChecked }
        return open.isEmpty ? "List is empty." : "\(open.count) item(s) still to get."
    }

    private func mark(_ id: String) -> Bool {
        let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var map = UserDefaults.standard.dictionary(forKey: sentKey) as? [String: Double] ?? [:]
        if map[id] == day { return false }
        map[id] = day
        UserDefaults.standard.set(map, forKey: sentKey)
        return true
    }
}
