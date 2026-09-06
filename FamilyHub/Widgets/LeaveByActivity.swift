import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct LeaveByAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var leaveAt: Date
        var eventStart: Date
    }

    var eventID: String
}

enum LeaveByLive {
    static func publish(title: String, eventID: String, startAt: Date, travelMinutes: Int = 20) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let leave = startAt.addingTimeInterval(TimeInterval(-travelMinutes * 60))
        guard leave.timeIntervalSinceNow > -5 * 60, startAt.timeIntervalSinceNow < 4 * 3600 else { return }
        let state = LeaveByAttributes.ContentState(title: title, leaveAt: leave, eventStart: startAt)
        let attrs = LeaveByAttributes(eventID: eventID)
        Task {
            let existing = Activity<LeaveByAttributes>.activities
            if let current = existing.first(where: { $0.attributes.eventID == eventID }) {
                await current.update(ActivityContent(state: state, staleDate: startAt))
                return
            }
            for old in existing { await old.end(nil, dismissalPolicy: .immediate) }
            _ = try? Activity.request(attributes: attrs, content: ActivityContent(state: state, staleDate: startAt), pushType: nil)
        }
    }
}
#endif
