import MapKit
import SwiftUI
import UIKit

struct HubWidgetPickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubAccent) private var accent
    var current: HubWidgetKind?
    var onPick: (HubWidgetKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Pick", tail: "One") {
                HubHeaderPill(title: "Close") { dismiss() }
            }
            Text("Tap what you want this box to show.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(HubWidgetKind.choosable) { kind in
                        Button {
                            onPick(kind)
                            dismiss()
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: kind.symbol)
                                    .font(.system(size: 34, weight: .bold))
                                Text(kind.title)
                                    .font(.title3.weight(.bold))
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.8)
                                    .lineLimit(2)
                            }
                            .foregroundStyle(current == kind ? .white : AppTheme.text)
                            .frame(maxWidth: .infinity, minHeight: 132)
                            .padding(16)
                            .background(current == kind ? AppTheme.blue : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(current == kind ? AppTheme.blue : AppTheme.cardBorder, lineWidth: current == kind ? 3 : 1)
                            )
                            .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                        }
                        .buttonStyle(HubPressStyle())
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }
}

struct HubWidgetPicker: View {
    @EnvironmentObject private var store: HubStore
    @State private var editIndex: Int?

    var body: some View {
        SettingsPageShell(tail: "Widgets", symbol: "square.grid.2x2.fill", title: "Hub tiles, bills, and weather") {
            VStack(alignment: .leading, spacing: 18) {
                Text("These boxes sit next to Today’s Agenda. Change a box, or add one under the tall box.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(Array(store.hubWidgets.map(\.kind).enumerated()), id: \.offset) { index, kind in
                    HStack(spacing: 14) {
                        Image(systemName: kind.symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title)
                                .font(.title3.weight(.bold))
                            Text(index == 2 && store.hubWidgets.count == 3 ? "Tall box" : "Box \(index + 1)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            editIndex = index
                        } label: {
                            Text("Change")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppTheme.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                }
                if store.hubWidgets.count < 4 {
                    Button {
                        store.addWidgetUnderRight()
                    } label: {
                        Label("Add a box under the tall one", systemImage: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.blueSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        store.makeRightWidgetBigger()
                    } label: {
                        Label("Make the tall box bigger", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.blueSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("Bills Due")
                    .font(.headline.weight(.bold))
                    .padding(.top, 8)
                Text("Pick which calendar is bills. Those items show on the Bills widget.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                BillsCalendarPicker()

                Text("Weather")
                    .font(.headline.weight(.bold))
                    .padding(.top, 8)
                WeatherSettingsForm()
            }
        }
        .sheet(item: editBinding) { kind in
            HubWidgetPickSheet(current: kind) { picked in
                if let index = editIndex {
                    store.setHubWidget(at: index, kind: picked)
                }
                editIndex = nil
            }
        }
    }

    private var editBinding: Binding<HubWidgetKind?> {
        Binding(
            get: {
                guard let index = editIndex, store.hubWidgets.indices.contains(index) else { return nil }
                return store.hubWidgets[index].kind
            },
            set: { if $0 == nil { editIndex = nil } }
        )
    }
}

private enum WidgetSetup: String, Identifiable {
    case flight, package
    var id: String { rawValue }
}

struct BillsWidget: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.hubAccent) private var accent
    let day: Date

    private var bills: [ReminderItem] { store.billsDue(on: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "dollarsign.circle.fill", title: "Bills Due") {
                if bills.isEmpty == false {
                    Text("\(bills.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white, in: Capsule())
                }
            }
            Group {
                if bills.isEmpty {
                    Button {
                        router.open(.lists, list: .reminders)
                    } label: {
                        VStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Text("Nothing due today")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Bills from your bills calendar show here")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                                .multilineTextAlignment(.center)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(HubPressStyle())
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(bills.prefix(8)) { item in
                                Button {
                                    router.open(.lists, list: .reminders)
                                } label: {
                                    HubAgendaCallout(
                                        rail: AppTheme.reminder,
                                        eyebrow: item.dueAt.map(Date.hubClock) ?? "Due",
                                        title: item.title,
                                        badge: "Bills Due",
                                        accent: accent
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.tableFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }
}

struct FlightWidget: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onAdd: () -> Void
    @Environment(\.hubAccent) private var accent
    @State private var opened: TrackedFlight?
    @State private var ping: FlightPing?

    private var flights: [TrackedFlight] {
        FlightParse.flights(on: day, events: store.events, extra: store.flights)
            .sorted { a, b in
                let liveA = FlightParse.isLive(a)
                let liveB = FlightParse.isLive(b)
                if liveA != liveB { return liveA && !liveB }
                return a.departAt < b.departAt
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "airplane", title: "Flight Tracker") {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
            }
            Group {
                if let flight = flights.first {
                    TimelineView(.periodic(from: .now, by: 15)) { timeline in
                        Button { opened = flight } label: {
                            widgetBody(flight, now: timeline.date)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: onAdd) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No flights this day")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Text("HUB reads flights from the calendar. Tap to add one.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Add flight")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(accent, in: Capsule())
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.tableFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: accent)
        .sheet(item: $opened) { flight in
            FlightDetailSheet(flight: flight, others: flights)
                .environmentObject(store)
        }
        .task(id: flights.first?.code) {
            guard let flight = flights.first else { ping = nil; return }
            while !Task.isCancelled {
                ping = await FlightLive.ping(flight)
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    private func widgetBody(_ flight: TrackedFlight, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(FlightParse.phase(flight, now: now))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent, in: Capsule())
                Spacer()
                Text(travelerName(flight))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(travelerColor(flight))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(travelerColor(flight).opacity(0.16), in: Capsule())
            }
            Text(FlightParse.countdown(flight, now: now))
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(flight.origin.isEmpty ? "—" : flight.origin)
                Image(systemName: "airplane")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                    .rotationEffect(.degrees(-10 + 20 * FlightParse.progress(flight, now: now)))
                Text(flight.destination.isEmpty ? "—" : flight.destination)
            }
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(AppTheme.text)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            ProgressView(value: FlightParse.progress(flight, now: now))
                .tint(accent)
            Text("\(FlightParse.airlineName(flight.airline)) \(flight.code)")
                .font(.headline.weight(.bold))
                .foregroundStyle(accent)
            Text(timeLine(flight))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            if let ping {
                Text(liveLine(ping))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }
            if flights.count > 1 {
                Text("+\(flights.count - 1) more today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func timeLine(_ flight: TrackedFlight) -> String {
        let leave = Date.hubClock(flight.departAt)
        if let land = flight.arriveAt {
            return "\(leave) → \(Date.hubClock(land))"
        }
        return "Departs \(leave)"
    }

    private func liveLine(_ ping: FlightPing) -> String {
        var bits: [String] = []
        if ping.onGround { bits.append("On the ground") }
        if let alt = ping.altitudeFt, alt > 0 { bits.append("\(alt.formatted()) ft") }
        if let speed = ping.speedKts, speed > 0 { bits.append("\(speed) kts") }
        return bits.isEmpty ? "Live position" : bits.joined(separator: " · ")
    }

    private func traveler(for flight: TrackedFlight) -> FamilyMember? {
        if let id = flight.memberID { return store.member(id: id) }
        if let eventID = flight.eventID,
           let event = store.events.first(where: { $0.id == eventID }),
           let id = event.memberID {
            return store.member(id: id)
        }
        return nil
    }

    private func travelerName(_ flight: TrackedFlight) -> String {
        traveler(for: flight)?.name ?? "Family"
    }

    private func travelerColor(_ flight: TrackedFlight) -> Color {
        if let member = traveler(for: flight) { return Color(hex: member.colorHex) }
        return AppTheme.blue
    }
}

struct FlightDetailSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let flight: TrackedFlight
    var others: [TrackedFlight] = []
    @State private var ping: FlightPing?
    @State private var watching: TrackedFlight

    init(flight: TrackedFlight, others: [TrackedFlight] = []) {
        self.flight = flight
        self.others = others
        _watching = State(initialValue: flight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "HUB", tail: "Flight") {
                HubHeaderPill(title: "Close") { dismiss() }
            }
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HubPanel(symbol: "airplane", title: "\(FlightParse.airlineName(watching.airline)) \(watching.code)") {
                            detailBody(now: timeline.date)
                        }
                        if let ping {
                            HubPanel(symbol: "location.fill", title: "Live position") {
                                liveMap(ping)
                                Text(liveFacts(ping))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                    .padding(.top, 8)
                            }
                        }
                        HubPanel(symbol: "info.circle.fill", title: "Track") {
                            VStack(alignment: .leading, spacing: 10) {
                                if !watching.notes.isEmpty {
                                    Text(watching.notes)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Button {
                                    if let url = FlightParse.trackURL(watching) { openURL(url) }
                                } label: {
                                    Text("Open live map")
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(AppTheme.blue, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if others.count > 1 {
                            HubPanel(symbol: "list.bullet", title: "Today’s flights") {
                                VStack(spacing: 8) {
                                    ForEach(others) { item in
                                        Button { watching = item } label: {
                                            HStack {
                                                Text("\(item.code)  \(item.origin) → \(item.destination)")
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(AppTheme.text)
                                                Spacer()
                                                Text(travelerName(item))
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(travelerColor(item))
                                                if item.id == watching.id {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(AppTheme.blue)
                                                }
                                            }
                                            .padding(12)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .task(id: watching.code) {
            ping = nil
            while !Task.isCancelled {
                ping = await FlightLive.ping(watching)
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func detailBody(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(FlightParse.phase(watching, now: now))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.blue, in: Capsule())
                Spacer()
                Text(FlightParse.countdown(watching, now: now))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            HStack {
                airport(watching.origin.isEmpty ? "—" : watching.origin, label: "From")
                VStack {
                    Image(systemName: "airplane")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    ProgressView(value: FlightParse.progress(watching, now: now))
                        .tint(AppTheme.blue)
                }
                airport(watching.destination.isEmpty ? "—" : watching.destination, label: "To")
            }
            HStack {
                fact("Departs", Date.hubClock(watching.departAt))
                fact("Arrives", watching.arriveAt.map(Date.hubClock) ?? "—")
                fact("Time in air", FlightParse.duration(watching))
            }
            HStack {
                fact("Who", travelerName(watching))
                fact("Airline", FlightParse.airlineName(watching.airline))
            }
        }
    }

    private func airport(_ code: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(code)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func liveMap(_ ping: FlightPing) -> some View {
        let coord = CLLocationCoordinate2D(latitude: ping.latitude, longitude: ping.longitude)
        Map(position: .constant(.region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
        )))) {
            Annotation(watching.code, coordinate: coord) {
                Image(systemName: "airplane")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(AppTheme.blue, in: Circle())
                    .rotationEffect(.degrees((ping.heading ?? 0) - 90))
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(false)
    }

    private func liveFacts(_ ping: FlightPing) -> String {
        var bits: [String] = []
        if ping.onGround {
            bits.append("On the ground")
        } else if let alt = ping.altitudeFt {
            bits.append("\(alt.formatted()) ft")
        }
        if let speed = ping.speedKts, speed > 0 { bits.append("\(speed) kts") }
        if let heading = ping.heading { bits.append("HDG \(Int(heading))°") }
        return bits.isEmpty ? "Live from ADS-B" : bits.joined(separator: "  ·  ")
    }

    private func traveler(for flight: TrackedFlight) -> FamilyMember? {
        if let id = flight.memberID { return store.member(id: id) }
        if let eventID = flight.eventID,
           let event = store.events.first(where: { $0.id == eventID }),
           let id = event.memberID {
            return store.member(id: id)
        }
        return nil
    }

    private func travelerName(_ flight: TrackedFlight) -> String {
        traveler(for: flight)?.name ?? "Family"
    }

    private func travelerColor(_ flight: TrackedFlight) -> Color {
        if let member = traveler(for: flight) { return Color(hex: member.colorHex) }
        return AppTheme.blue
    }
}

struct PackageWidget: View {
    @EnvironmentObject private var store: HubStore
    var onAdd: () -> Void
    @Environment(\.hubAccent) private var accent
    @Environment(\.openURL) private var openURL

    private var open: [TrackedPackage] {
        store.packages.filter { !$0.isDelivered }.sorted { ($0.eta ?? .distantFuture) < ($1.eta ?? .distantFuture) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "shippingbox.fill", title: "Packages") {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
            }
            Group {
                if open.isEmpty {
                    Button(action: onAdd) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nothing in transit")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text("Tap to add an Amazon or carrier tracking number.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Add package")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(accent, in: Capsule())
                    }
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(open.prefix(4)) { item in
                            Button {
                                if let url = item.carrier.trackURL(item.tracking) { openURL(url) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "shippingbox.fill")
                                        .foregroundStyle(accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(1)
                                        Text("\(item.carrier.title) · \(item.status.title)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    if let eta = item.eta {
                                        Text(eta.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }
}

struct AddFlightSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    var day: Date
    @State private var airline = "UA"
    @State private var number = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var depart = Date()
    @State private var arrive = Date().addingTimeInterval(4 * 3600)
    @State private var memberID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Add", tail: "Flight")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("Airline", text: $airline)
                    field("Flight number", text: $number)
                    field("From (ORD)", text: $origin)
                    field("To (SJC)", text: $destination)
                    DatePicker("Departs", selection: $depart)
                    DatePicker("Arrives", selection: $arrive)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who").font(.caption.weight(.bold)).foregroundStyle(AppTheme.textTertiary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                whoChip("Family", on: memberID == nil) { memberID = nil }
                                ForEach(store.members) { member in
                                    whoChip(member.name, on: memberID == member.id) { memberID = member.id }
                                }
                            }
                        }
                    }
                    Button {
                        store.addFlight(.make(
                            airline: airline,
                            number: number,
                            origin: origin,
                            destination: destination,
                            departAt: depart,
                            arriveAt: arrive,
                            memberID: memberID
                        ))
                        dismiss()
                    } label: {
                        Text("Save flight")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(number.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear { depart = day }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(AppTheme.textTertiary)
            TextField(title, text: text)
                .textInputAutocapitalization(.characters)
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func whoChip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(on ? .white : AppTheme.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(on ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct AddPackageSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var tracking = ""
    @State private var carrier: PackageCarrier = .amazon
    @State private var status: PackageStatus = .shipped
    @State private var hasETA = false
    @State private var eta = Date().addingTimeInterval(2 * 24 * 3600)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Track", tail: "Package")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("What’s coming", text: $name)
                    field("Tracking number", text: $tracking)
                    Text("Paste an Amazon email or just the tracking number. HUB will pick the carrier.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button("Paste from clipboard") {
                        if let text = UIPasteboard.general.string {
                            applyPaste(text)
                        }
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
                    Text("Carrier").font(.caption.weight(.bold)).foregroundStyle(AppTheme.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(PackageCarrier.allCases) { item in
                                Button(item.title) { carrier = item }
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(carrier == item ? .white : AppTheme.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(carrier == item ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                            }
                        }
                    }
                    Text("Status").font(.caption.weight(.bold)).foregroundStyle(AppTheme.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(PackageStatus.allCases) { item in
                                Button(item.title) { status = item }
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(status == item ? .white : AppTheme.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(status == item ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                            }
                        }
                    }
                    Toggle("Has delivery date", isOn: $hasETA)
                        .font(.headline.weight(.bold))
                    if hasETA {
                        DatePicker("ETA", selection: $eta, displayedComponents: .date)
                    }
                    Button {
                        store.addPackage(.make(
                            name: name,
                            tracking: tracking,
                            carrier: carrier,
                            status: status,
                            eta: hasETA ? eta : nil
                        ))
                        dismiss()
                    } label: {
                        Text("Save package")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            if tracking.isEmpty, let text = UIPasteboard.general.string, text.count > 6 {
                applyPaste(text)
            }
        }
    }

    private func applyPaste(_ raw: String) {
        let parsed = PackageParse.read(raw)
        if tracking.trimmingCharacters(in: .whitespaces).isEmpty {
            tracking = parsed.tracking
        }
        carrier = parsed.carrier
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = parsed.name
        }
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(AppTheme.textTertiary)
            TextField(title, text: text)
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

enum PackageParse {
    static func read(_ raw: String) -> (tracking: String, carrier: PackageCarrier, name: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ups = firstMatch(#"\b1Z[0-9A-Z]{16}\b"#, in: text) {
            return (ups, .ups, "UPS package")
        }
        if let fedex = firstMatch(#"\b(\d{12}|\d{14}|\d{15}|\d{20})\b"#, in: text), fedex.count >= 12 {
            return (fedex, .fedex, "FedEx package")
        }
        if let usps = firstMatch(#"\b(94\d{20}|93\d{20}|92\d{20}|91\d{20}|420\d{27})\b"#, in: text) {
            return (usps, .usps, "USPS package")
        }
        if text.uppercased().contains("AMAZON") || text.uppercased().contains("TBA") {
            if let tba = firstMatch(#"\bTBA[0-9A-Z]+\b"#, in: text) {
                return (tba, .amazon, "Amazon package")
            }
            let token = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init).first(where: { $0.count >= 10 }) ?? text
            return (token, .amazon, "Amazon package")
        }
        let token = text.split(whereSeparator: \.isWhitespace).map(String.init).first(where: { $0.count >= 8 }) ?? text
        return (token, .other, "Package")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), let swift = Range(match.range, in: text) else { return nil }
        return String(text[swift])
    }
}

struct LeavingWidget: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.hubAccent) private var accent
    let day: Date

    private var rows: [(event: CalendarEvent, member: FamilyMember?, leaveAt: Date)] {
        let now = Date()
        let start = Calendar.current.startOfDay(for: day)
        return store.events
            .filter { Calendar.current.isDate($0.startAt, inSameDayAs: start) && $0.allDay == false }
            .filter { ($0.endAt ?? $0.startAt.addingTimeInterval(3600)) > now.addingTimeInterval(-15 * 60) }
            .sorted { $0.startAt < $1.startAt }
            .prefix(5)
            .map { event in
                let drive: TimeInterval = event.location.trimmingCharacters(in: .whitespaces).isEmpty ? 10 * 60 : 30 * 60
                return (event, event.memberID.flatMap(store.member(id:)), event.startAt.addingTimeInterval(-drive))
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "car.fill", title: "Who's Out")
            Group {
                if rows.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Everyone’s here")
                            .font(.headline.weight(.bold))
                        Text("Leave-by times show up when someone has a place to be.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(rows, id: \.event.id) { row in
                                Button {
                                    router.openCalendar(filter: row.member.map { .member($0.id) } ?? .family, day: day, eventID: row.event.id)
                                } label: {
                                    HubAgendaCallout(
                                        rail: row.member.map { Color(hex: $0.colorHex) } ?? accent,
                                        eyebrow: leaveLabel(row.leaveAt, start: row.event.startAt),
                                        title: row.event.title,
                                        badge: row.member?.name ?? "Family",
                                        accent: accent
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.tableFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }

    private func leaveLabel(_ leave: Date, start: Date) -> String {
        let now = Date()
        if leave <= now, start > now { return "Leave now" }
        if start <= now { return "Going now" }
        return "Leave \(Date.hubClock(leave))"
    }
}

struct ScoreboardWidget: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @Environment(\.hubAccent) private var accent
    let day: Date

    private var kids: [FamilyMember] {
        let due = store.assignments.filter { Calendar.current.isDate($0.dueOn, inSameDayAs: day) }
        let ids = Set(due.map(\.memberID))
        let listed = store.members.filter { $0.role == .child || ids.contains($0.id) }
        return listed.isEmpty ? store.members.filter { $0.role == .child } : listed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "checkmark.circle.fill", title: "Chore Board")
            Group {
                if kids.isEmpty {
                    Text("Add a kid to start chores.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(kids) { member in
                                let open = store.assignments.filter {
                                    $0.memberID == member.id &&
                                    Calendar.current.isDate($0.dueOn, inSameDayAs: day) &&
                                    $0.status == .pending
                                }.count
                                Button { router.open(.chores) } label: {
                                    HubAgendaCallout(
                                        rail: Color(hex: member.colorHex),
                                        eyebrow: open == 0 ? "All done" : "\(open) open",
                                        title: member.name,
                                        badge: Money.cents(member.allowanceBalanceCents),
                                        accent: accent
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.tableFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }
}

struct WhiteboardWidget: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.hubAccent) private var accent
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                HubTileBanner(symbol: "square.and.pencil", title: "Whiteboard") {
                    Text(store.whiteboardNote.isEmpty ? "Write" : "Edit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white, in: Capsule())
                }
                Text(store.whiteboardNote.isEmpty ? "Tap anywhere to leave a note." : store.whiteboardNote)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(store.whiteboardNote.isEmpty ? AppTheme.textSecondary : AppTheme.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                    .padding(14)
                    .background(AppTheme.tableFill)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hubLift(accent: accent)
    }
}

struct WhiteboardEditor: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubAccent) private var accent
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "House", tail: "Note") {
                HStack(spacing: 8) {
                    HubHeaderPill(title: "Close") { dismiss() }
                    HubHeaderPill(title: "Save") {
                        store.setWhiteboardNote(draft.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Type the note. Everyone on the Hub will see it.")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Soccer bags by the door…")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                            .padding(.horizontal, 18)
                            .padding(.top, 18)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $draft)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .padding(10)
                }
                .frame(minHeight: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent, lineWidth: 2)
                )
                if draft.isEmpty == false {
                    Button {
                        draft = ""
                    } label: {
                        Text("Clear note")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.chore)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            Spacer(minLength: 0)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            draft = store.whiteboardNote
            focused = true
        }
    }
}

struct BirthdayWidget: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.hubAccent) private var accent
    let day: Date

    private var upcoming: [(member: FamilyMember, when: Date, days: Int)] {
        store.members.compactMap { member -> (FamilyMember, Date, Int)? in
            guard let when = member.nextBirthday(from: day) else { return nil }
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: day), to: when).day ?? 0
            return (member, when, days)
        }
        .sorted { $0.1 < $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubTileBanner(symbol: "gift.fill", title: "Birthdays")
            Group {
                if upcoming.isEmpty {
                    Text("Add birthdays in Profiles.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(upcoming.prefix(5), id: \.member.id) { row in
                                HubAgendaCallout(
                                    rail: Color(hex: row.member.colorHex),
                                    eyebrow: row.days == 0 ? "Today" : row.days == 1 ? "Tomorrow" : "In \(row.days) days",
                                    title: row.member.name,
                                    badge: row.when.formatted(.dateTime.month(.abbreviated).day()),
                                    accent: accent,
                                    compact: true
                                )
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.tableFill)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card)
        .hubLift(accent: accent)
    }
}