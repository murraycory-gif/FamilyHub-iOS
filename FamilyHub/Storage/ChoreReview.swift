import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let hubCloudChanged = Notification.Name("hub.cloud.changed")
}

/// Who the chores screen is drawn for. A child always sees their own board. A grown-up can step into one kid.
enum ChoreDesk {
    static let doneButtonMinHeight: CGFloat = 60
    /// White on this fill clears WCAG AA 4.5:1 (about 10:1).
    static let actionFill = "0A3E86"
    static let actionInk = "FFFFFF"
    static let noteInkLight = "0A3E86"
    static let noteInkDark = "9CC4FF"

    enum Mode: Equatable {
        case kid(UUID)
        case parent
    }

    static func mode(role: MemberRole?, memberID: UUID?, focusedKidID: UUID?) -> Mode {
        if role == .child, let memberID {
            return .kid(memberID)
        }
        if let focusedKidID {
            return .kid(focusedKidID)
        }
        return .parent
    }

    static func waiting(_ assignments: [ChoreAssignment]) -> [ChoreAssignment] {
        assignments.filter { $0.status == .done }
    }

    /// Kid cards stay on the work that still matters, plus a paid chore from the last day so “Great job!” does not vanish immediately.
    static func kidCards(_ rows: [ChoreAssignment], now: Date) -> [ChoreAssignment] {
        rows.filter { row in
            switch row.status {
            case .paid:
                guard let at = row.approvedAt ?? row.completedAt else { return false }
                return now.timeIntervalSince(at) < 86_400
            case .pending, .done, .approved:
                return true
            }
        }
    }

    static func symbolIcon(_ icon: String) -> Bool {
        !icon.isEmpty && icon.unicodeScalars.allSatisfy(\.isASCII)
    }
}

enum ChoreReview {
    static let categoryID = "hub.chore.review"
    static let approveAction = "hub.chore.approve"
    static let sendBackAction = "hub.chore.notYet"
    static let assignmentKey = "assignmentID"
    static let undoWindow: TimeInterval = 5

    struct Draft: Equatable {
        var identifier: String
        var title: String
        var body: String
        var assignmentID: UUID
    }

    static func identifier(for assignmentID: UUID) -> String {
        "hub.chore.review.\(assignmentID.uuidString)"
    }

    static func title(kid: String, chore: String) -> String {
        "\(kid) finished \(chore)"
    }

    static func offersUndo(status: AssignmentStatus, completedAt: Date?, now: Date, window: TimeInterval = undoWindow) -> Bool {
        guard status == .done, let completedAt else { return false }
        let elapsed = now.timeIntervalSince(completedAt)
        return elapsed >= 0 && elapsed <= window
    }

    /// Completions that became “waiting” since the last snapshot, for a grown-up’s device.
    static func incomingDone(
        before: [ChoreAssignment],
        after: [ChoreAssignment],
        members: [FamilyMember],
        chores: [Chore],
        viewerIsChild: Bool
    ) -> [Draft] {
        guard !viewerIsChild else { return [] }
        let alreadyWaiting = Set(before.filter {
            $0.status == .done || $0.status == .approved || $0.status == .paid
        }.map(\.id))
        return after.compactMap { row in
            guard row.status == .done, !alreadyWaiting.contains(row.id) else { return nil }
            let kid = members.first { $0.id == row.memberID }?.name ?? "Someone"
            let chore = chores.first { $0.id == row.choreID }?.title ?? "a chore"
            return Draft(
                identifier: identifier(for: row.id),
                title: title(kid: kid, chore: chore),
                body: "Needs your OK.",
                assignmentID: row.id
            )
        }
    }
}

enum ChoreProofStore {
    static func folder() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = root.appendingPathComponent("chore-proofs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let name = "\(UUID().uuidString).jpg"
        let url = folder().appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> Data? {
        let cleaned = (name as NSString).lastPathComponent
        guard cleaned == name, !cleaned.isEmpty else { return nil }
        return try? Data(contentsOf: folder().appendingPathComponent(cleaned))
    }
}

@MainActor
final class ChoreReviewCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ChoreReviewCenter()

    var handler: ((String, UUID) -> Void)? {
        didSet { flush() }
    }

    private var pending: (String, UUID)?

    func flush() {
        guard let pending, let handler else { return }
        self.pending = nil
        handler(pending.0, pending.1)
    }

    static func registerCategories() {
        let approve = UNNotificationAction(identifier: ChoreReview.approveAction, title: "Approve", options: [])
        let notYet = UNNotificationAction(identifier: ChoreReview.sendBackAction, title: "Not yet", options: [])
        let category = UNNotificationCategory(
            identifier: ChoreReview.categoryID,
            actions: [approve, notYet],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func post(_ drafts: [ChoreReview.Draft]) async {
        guard !drafts.isEmpty else { return }
        registerCategories()
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        for draft in drafts {
            let content = UNMutableNotificationContent()
            content.title = draft.title
            content.body = draft.body
            content.sound = .default
            content.categoryIdentifier = ChoreReview.categoryID
            content.userInfo = [ChoreReview.assignmentKey: draft.assignmentID.uuidString]
            let request = UNNotificationRequest(
                identifier: draft.identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            try? await center.add(request)
        }
    }

    static func withdraw(_ id: UUID) {
        let identifier = ChoreReview.identifier(for: id)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        guard action == ChoreReview.approveAction || action == ChoreReview.sendBackAction else { return }
        guard let raw = response.notification.request.content.userInfo[ChoreReview.assignmentKey] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run {
            let review = ChoreReviewCenter.shared
            if let handler = review.handler {
                handler(action, id)
            } else {
                review.pending = (action, id)
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
