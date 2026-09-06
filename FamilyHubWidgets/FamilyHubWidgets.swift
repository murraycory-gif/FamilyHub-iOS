import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), snap: WidgetBridge.read()) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snap: WidgetBridge.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: Date(), snap: WidgetBridge.read())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snap: WidgetBridge.Snapshot
}

struct AgendaWidgetView: View {
    var entry: Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT'S ON TODAY'S")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white.opacity(0.7))
            Text(entry.snap.agendaTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(entry.snap.agendaWhen)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
            Text(entry.snap.household)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(red: 0.02, green: 0.06, blue: 0.11)
        }
    }
}

struct DinnerWidgetView: View {
    var entry: Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT'S FOR")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white.opacity(0.7))
            Text(entry.snap.dinnerName)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            if entry.snap.dinnerSide.isEmpty == false {
                Text(entry.snap.dinnerSide)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            Text("Dinner")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color(red: 0.07, green: 0.27, blue: 0.63)
        }
    }
}

struct LeaveLockView: View {
    var entry: Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LEAVE BY")
                .font(.caption2.weight(.heavy))
            if let leave = entry.snap.leaveAt {
                Text(leave, style: .timer)
                    .font(.headline.monospacedDigit().weight(.bold))
                Text(entry.snap.leaveTitle)
                    .font(.caption2)
                    .lineLimit(1)
            } else {
                Text("Nothing soon")
                    .font(.caption.weight(.bold))
            }
        }
    }
}

struct AgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HubAgendaWidget", provider: Provider()) { entry in
            AgendaWidgetView(entry: entry)
        }
        .configurationDisplayName("What's On Today's Agenda")
        .description("Next event for the house.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct DinnerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HubDinnerWidget", provider: Provider()) { entry in
            DinnerWidgetView(entry: entry)
        }
        .configurationDisplayName("What's For Dinner")
        .description("Tonight’s meal.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct LeaveLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HubLeaveWidget", provider: Provider()) { entry in
            LeaveLockView(entry: entry)
        }
        .configurationDisplayName("Leave By")
        .description("Countdown to walk out the door.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#if canImport(ActivityKit)
struct LeaveByLiveView: View {
    let context: ActivityViewContext<LeaveByAttributes>
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Leave by")
                    .font(.caption2.weight(.heavy))
                Text(context.state.title)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer()
            Text(context.state.leaveAt, style: .timer)
                .font(.title3.monospacedDigit().weight(.bold))
        }
        .padding(.horizontal, 12)
    }
}

struct LeaveByLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LeaveByAttributes.self) { context in
            LeaveByLiveView(context: context)
                .activityBackgroundTint(Color(red: 0.02, green: 0.06, blue: 0.11))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leave")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.leaveAt, style: .timer)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.title).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "figure.walk.departure")
            } compactTrailing: {
                Text(context.state.leaveAt, style: .timer)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.walk.departure")
            }
        }
    }
}
#endif

@main
struct FamilyHubWidgets: WidgetBundle {
    var body: some Widget {
        AgendaWidget()
        DinnerWidget()
        LeaveLockWidget()
        #if canImport(ActivityKit)
        LeaveByLiveWidget()
        #endif
    }
}
