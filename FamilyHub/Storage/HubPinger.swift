import Foundation
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
                body: "If you got this, pings are working."
            )
        }
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
        guard prefs.anyOn, prefs.channel.usesText, prefs.textReady else { return }
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
        if prefs.channel.usesText {
            let numbers = phones(in: store)
            if numbers.isEmpty {
                lastError = "No phone numbers. Add one on a profile, or an extra number in Settings."
            } else if !prefs.textReady {
                lastError = "Texts need a Twilio Account SID, token, and From number."
            } else {
                for number in numbers {
                    do {
                        try await sendSMS(prefs: prefs, to: number, body: "\(title) — \(body)")
                    } catch {
                        lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func phones(in store: HubStore) -> [String] {
        let prefs = store.notifyPrefs
        var raw: [String] = []
        switch prefs.who {
        case .me:
            raw.append(store.signedInMember()?.phone ?? "")
        case .owner:
            raw.append(store.members.first(where: { $0.id == store.ownerID })?.phone ?? "")
        case .everyone:
            raw.append(contentsOf: store.members.map(\.phone))
        }
        raw.append(prefs.extraPhone)
        return Array(Set(raw.compactMap(Self.e164))).sorted()
    }

    static func e164(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        if digits.count == 10 { return "+1\(digits)" }
        if digits.count == 11, digits.hasPrefix("1") { return "+\(digits)" }
        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("+"), digits.count >= 10 { return "+\(digits)" }
        return nil
    }

    private func sendSMS(prefs: HubNotifyPrefs, to: String, body: String) async throws {
        let sid = prefs.twilioSID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://api.twilio.com/2010-04-01/Accounts/\(sid)/Messages.json") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let token = "\(sid):\(prefs.twilioToken)"
        let auth = Data(token.utf8).base64EncodedString()
        request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let from = prefs.twilioFrom.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? prefs.twilioFrom
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        request.httpBody = "To=\(to)&From=\(from)&Body=\(encodedBody)".data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code >= 300 {
            let text = String(data: data, encoding: .utf8) ?? "SMS failed"
            throw NSError(domain: "HUB", code: code, userInfo: [NSLocalizedDescriptionKey: text])
        }
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
