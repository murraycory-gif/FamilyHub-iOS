import Foundation
import UIKit
import UserNotifications

@MainActor
final class HubPinger: ObservableObject {
    static let shared = HubPinger()
    private let sentKey = "familyhub.notify.sent.v1"
    private let verifiedKey = "familyhub.notify.phoneVerified"
    var lastError: String?
    @Published var phoneVerified: Bool
    @Published var sending = false

    private init() {
        phoneVerified = UserDefaults.standard.bool(forKey: verifiedKey)
    }

    func refresh(_ store: HubStore) {
        Task { await schedule(store) }
        Task { await fireDue(store) }
    }

    func sendTest(_ store: HubStore) {
        Task {
            await deliver(store, title: "HUB test", body: "If you got this, pings are working.", device: true)
        }
    }

    func sendTestText(_ store: HubStore) async {
        await sendRemoteSMS(store, body: "HUB: this is a test. If you got this, texts are working.")
    }

    func markConnected() {
        phoneVerified = true
        UserDefaults.standard.set(true, forKey: verifiedKey)
        lastError = nil
    }

    func clearPhoneLink() {
        phoneVerified = false
        UserDefaults.standard.set(false, forKey: verifiedKey)
    }

    func sendRemoteSMS(_ store: HubStore, body: String) async {
        lastError = nil
        sending = true
        defer { sending = false }
        let prefs = store.notifyPrefs
        guard prefs.textReady else {
            lastError = "HUB needs its own sender number once. Apple will not let this iPad text you as HUB."
            return
        }
        guard let to = phones(in: store).first else {
            lastError = "Enter a 10-digit US phone number."
            return
        }
        guard let from = Self.e164(prefs.twilioFrom) else {
            lastError = "HUB’s sender number isn’t valid."
            return
        }
        let sid = prefs.twilioSID.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = prefs.twilioToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://api.twilio.com/2010-04-01/Accounts/\(sid)/Messages.json") else {
            lastError = "Could not reach the text service."
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let login = Data("\(sid):\(token)".utf8).base64EncodedString()
        request.setValue("Basic \(login)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form([
            "To": to,
            "From": from,
            "Body": body
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(code) {
                markConnected()
                return
            }
            lastError = twilioMessage(data) ?? "Text did not send (\(code))."
        } catch {
            lastError = "Could not send. Check the network and sender setup."
        }
    }

    func schedule(_ store: HubStore) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let prefs = store.notifyPrefs
        guard prefs.anyOn else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        var requests: [UNNotificationRequest] = []
        if prefs.morningBrief {
            requests.append(daily("hub.morning", hour: prefs.morningAt / 60, minute: prefs.morningAt % 60, title: "Sunrise brief", body: morningBody(store)))
        }
        if prefs.dinnerPing {
            requests.append(daily("hub.dinner", hour: prefs.dinnerAt / 60, minute: prefs.dinnerAt % 60, title: "What's for dinner?", body: dinnerBody(store)))
        }
        if prefs.chorePing {
            requests.append(daily("hub.chores", hour: prefs.choreAt / 60, minute: prefs.choreAt % 60, title: "Chore check", body: choreBody(store)))
        }
        if prefs.billsPing {
            requests.append(daily("hub.bills", hour: prefs.billsAt / 60, minute: prefs.billsAt % 60, title: "Bills Due", body: billsBody(store)))
        }
        if prefs.shoppingPing {
            requests.append(daily("hub.shop", hour: prefs.shoppingAt / 60, minute: prefs.shoppingAt % 60, title: "Shopping list", body: shopBody(store)))
        }
        if prefs.eventPings {
            let cal = Calendar.current
            let lead = TimeInterval(max(5, prefs.eventLeadMinutes) * 60)
            let upcoming = store.events
                .filter { $0.startAt > Date() && $0.startAt < Date().addingTimeInterval(60 * 60 * 24 * 7) }
                .prefix(20)
            for event in upcoming {
                let fire = event.startAt.addingTimeInterval(-lead)
                guard fire > Date() else { continue }
                let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body = "Starts in \(prefs.eventLeadMinutes) minutes."
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
        guard prefs.anyOn else { return }
        if prefs.morningBrief, around(prefs.morningAt), mark("morning") {
            await deliver(store, title: "Sunrise brief", body: morningBody(store), device: true)
        }
        if prefs.dinnerPing, around(prefs.dinnerAt), store.dinner(on: Date()) == nil, mark("dinner") {
            await deliver(store, title: "What's for dinner?", body: dinnerBody(store), device: true)
        }
        if prefs.chorePing, around(prefs.choreAt), mark("chores") {
            await deliver(store, title: "Chore check", body: choreBody(store), device: true)
        }
        if prefs.billsPing, around(prefs.billsAt), mark("bills") {
            await deliver(store, title: "Bills Due", body: billsBody(store), device: true)
        }
        if prefs.shoppingPing, around(prefs.shoppingAt), store.shoppingItems.contains(where: { !$0.isChecked }), mark("shop") {
            await deliver(store, title: "Shopping list", body: shopBody(store), device: true)
        }
        if prefs.eventPings {
            let lead = TimeInterval(max(5, prefs.eventLeadMinutes) * 60)
            let soon = store.events.filter {
                $0.startAt > Date() && $0.startAt < Date().addingTimeInterval(lead + 5 * 60)
            }
            for event in soon where mark("event.\(event.id.uuidString)") {
                await deliver(store, title: event.title, body: "Starts in \(prefs.eventLeadMinutes) minutes.", device: true)
            }
        }
    }

    func deliver(_ store: HubStore, title: String, body: String, device: Bool = true) async {
        lastError = nil
        if device {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "hub.now.\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                lastError = "Allow notifications for HUB in iPad Settings."
            }
        }
    }

    func phones(in store: HubStore) -> [String] {
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

    static func prettyPhone(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if digits.count == 11, digits.hasPrefix("1") { digits = String(digits.dropFirst()) }
        let clipped = String(digits.prefix(10))
        if clipped.count < 4 { return clipped }
        if clipped.count < 7 { return "(\(clipped.prefix(3))) \(clipped.dropFirst(3))" }
        return "(\(clipped.prefix(3))) \(clipped.dropFirst(3).prefix(3))-\(clipped.suffix(4))"
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

    private func around(_ minutes: Int, window: Int = 20) -> Bool {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let current = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        return abs(current - minutes) <= window
    }

    private func mark(_ id: String) -> Bool {
        let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var map = UserDefaults.standard.dictionary(forKey: sentKey) as? [String: Double] ?? [:]
        if map[id] == day { return false }
        map[id] = day
        UserDefaults.standard.set(map, forKey: sentKey)
        return true
    }

    private func form(_ pairs: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let query = pairs.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
        return Data(query.utf8)
    }

    private func twilioMessage(_ data: Data) -> String? {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let raw = json?["message"] as? String
        let code = json?["code"] as? Int
        if code == 21608 || code == 21610 {
            return "Trial accounts can only text numbers you verify with the text service."
        }
        if code == 21211 {
            return "That phone number isn’t valid."
        }
        return raw
    }
}
