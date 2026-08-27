import SwiftUI

struct HubWidgetPicker: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var slots: [HubWidgetKind] = []
    @State private var setup: WidgetSetup?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Hub", tail: "Widgets") {
                HubHeaderPill(title: "Done") {
                    commit()
                    dismiss()
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap a tile to place it. Done saves it on the Hub. Flights and packages can be set up right after you pick them.")
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(Array(slots.enumerated()), id: \.offset) { index, kind in
                        slotCard(index: index, kind: kind)
                    }
                    Button {
                        commit()
                        dismiss()
                    } label: {
                        Text("Save to Hub")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            let current = store.hubWidgets.map(\.kind).filter { HubWidgetKind.choosable.contains($0) }
            slots = pad(current)
        }
        .sheet(item: $setup) { item in
            Group {
                if item == .flight {
                    AddFlightSheet(day: Date())
                } else {
                    AddPackageSheet()
                }
            }
            .environmentObject(store)
        }
    }

    private func slotCard(index: Int, kind: HubWidgetKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(index == 2 ? "Large tile" : index == 0 ? "Top tile" : "Lower tile")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(HubWidgetKind.choosable) { option in
                    Button {
                        pick(option, at: index)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: option.symbol)
                            Text(option.title)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(kind == option ? .white : AppTheme.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(kind == option ? AppTheme.blue : AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(kind == option ? AppTheme.blue : AppTheme.cardBorder, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }

    private func pick(_ option: HubWidgetKind, at index: Int) {
        if let other = slots.firstIndex(of: option), other != index {
            slots.swapAt(index, other)
        } else {
            slots[index] = option
        }
        commit()
        if option == .flights, store.flights.isEmpty { setup = .flight }
        if option == .packages, store.packages.filter({ !$0.isDelivered }).isEmpty { setup = .package }
    }

    private func commit() {
        store.setHubWidgets(slots)
    }

    private func pad(_ kinds: [HubWidgetKind]) -> [HubWidgetKind] {
        var next = kinds
        for kind in HubWidgetKind.choosable where next.count < 3 && !next.contains(kind) {
            next.append(kind)
        }
        return Array(next.prefix(3))
    }
}

private enum WidgetSetup: String, Identifiable {
    case flight, package
    var id: String { rawValue }
}

struct FlightWidget: View {
    @EnvironmentObject private var store: HubStore
    let day: Date
    var onAdd: () -> Void
    @Environment(\.hubAccent) private var accent
    @Environment(\.openURL) private var openURL

    private var flights: [TrackedFlight] {
        FlightParse.flights(on: day, events: store.events, extra: store.flights)
            .filter { FlightParse.isLive($0) }
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
                    Button {
                        if let url = FlightParse.trackURL(flight) { openURL(url) }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(FlightParse.phase(flight))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(accent, in: Capsule())
                                Spacer()
                                Text(FlightParse.countdown(flight))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(accent)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(flight.origin.isEmpty ? "—" : flight.origin)
                                Image(systemName: "airplane")
                                    .font(.caption.weight(.bold))
                                Text(flight.destination.isEmpty ? "—" : flight.destination)
                            }
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            Text("\(FlightParse.airlineName(flight.airline)) \(flight.code)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(accent)
                            Text(timeLine(flight))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            if flights.count > 1 {
                                Text("+\(flights.count - 1) more today")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onAdd) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No flights this day")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text("HUB reads Flight UA1234 ORD to SFO from the calendar. Tap to add one yourself.")
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
    }

    private func timeLine(_ flight: TrackedFlight) -> String {
        let leave = Date.hubClock(flight.departAt)
        if let land = flight.arriveAt {
            return "\(leave) → \(Date.hubClock(land))"
        }
        return "Departs \(leave)"
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
                    Button {
                        store.addFlight(.make(
                            airline: airline,
                            number: number,
                            origin: origin,
                            destination: destination,
                            departAt: depart,
                            arriveAt: arrive
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