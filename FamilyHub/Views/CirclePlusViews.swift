import SwiftUI

struct CirclePlusView: View {
    @EnvironmentObject private var store: HubStore
    @State private var schoolTitle = ""
    @State private var schoolURL = ""
    @State private var docTitle = ""
    @State private var placeName = "School"
    @State private var houseA = "Mom’s house"
    @State private var houseB = "Dad’s house"
    @State private var recapCaption = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "Circle", tail: "Plus")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    schoolCard
                    placesCard
                    custodyCard
                    documentsCard
                    quietCard
                    recapCard
                    leaveCard
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
    }

    private var schoolCard: some View {
        HubPanel(symbol: "graduationcap.fill", title: "School calendar") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Paste the district ICS link. It lands on the family calendar like iCloud.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("Lincoln Elementary", text: $schoolTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("https://…ics", text: $schoolURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Button("Subscribe") {
                    store.addSchoolCalendar(title: schoolTitle, url: schoolURL)
                    schoolURL = ""
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(schoolURL.isEmpty ? AppTheme.blue.opacity(0.4) : AppTheme.blue, in: Capsule())
                .disabled(schoolURL.isEmpty)
            }
        }
    }

    private var placesCard: some View {
        HubPanel(symbol: "location.fill", title: "Places + geofence") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Save School, Home, Practice. Circle pings when someone arrives or leaves.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("Place name", text: $placeName)
                    .textFieldStyle(.roundedBorder)
                Button("Save as School (uses current weather pin)") {
                    let lat = store.weatherPlace?.latitude ?? 42.2411
                    let lon = store.weatherPlace?.longitude ?? -88.3162
                    store.addCirclePlace(.make(name: placeName.isEmpty ? "School" : placeName, kind: .school, lat: lat, lon: lon, members: store.members.map(\.id)))
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                ForEach(store.circlePlaces) { place in
                    HStack {
                        Image(systemName: place.kind.symbol).foregroundStyle(AppTheme.blue)
                        VStack(alignment: .leading) {
                            Text(place.name).font(.headline)
                            Text(place.kind.label).font(.caption).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Button("Left") {
                            if let kid = store.kids().first {
                                store.recordPlacePing(placeID: place.id, memberID: kid.id, arrived: false)
                            }
                        }
                        .font(.caption.weight(.bold))
                    }
                }
                ForEach(store.placePings.prefix(6)) { ping in
                    Text("\(store.member(id: ping.memberID)?.name ?? "Someone") \(ping.arrived ? "arrived" : "left")")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var custodyCard: some View {
        HubPanel(symbol: "arrow.left.arrow.right", title: "Two-house week") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Color the week by which house the kids are in.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                TextField("House A", text: $houseA).textFieldStyle(.roundedBorder)
                TextField("House B", text: $houseB).textFieldStyle(.roundedBorder)
                Button("Set A = Sun–Wed, B = Thu–Sat") {
                    let kids = store.kids().map(\.id)
                    store.setCustodyHouses([
                        .make(name: houseA, colorHex: "2B7AE8", weekdays: [1, 2, 3, 4], kids: kids),
                        .make(name: houseB, colorHex: "E11D8F", weekdays: [5, 6, 7], kids: kids)
                    ])
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                if let house = store.house(on: Date()) {
                    Text("Today: \(house.name)")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Color(hex: house.colorHex))
                }
            }
        }
    }

    private var documentsCard: some View {
        HubPanel(symbol: "folder.fill", title: "Documents") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Insurance card, sports form…", text: $docTitle)
                    .textFieldStyle(.roundedBorder)
                Button("Add file note") {
                    store.addDocument(.make(title: docTitle, kind: .other))
                    docTitle = ""
                }
                .disabled(docTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                ForEach(store.documents) { doc in
                    HStack {
                        Image(systemName: doc.kind.symbol).foregroundStyle(AppTheme.blue)
                        Text(doc.title)
                        Spacer()
                        Button(role: .destructive) { store.deleteDocument(doc.id) } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }

    private var quietCard: some View {
        HubPanel(symbol: "moon.zzz.fill", title: "Quiet hours") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pings skip a person during their off hours. Duty parent still gets them.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(store.members.filter { $0.role == .parent || $0.role == .child }) { member in
                    HStack {
                        Text(member.name)
                        Spacer()
                        if store.isQuiet(memberID: member.id) {
                            Text("Quiet now").foregroundStyle(AppTheme.reminder)
                        }
                        Button(store.quietHours.contains(where: { $0.memberID == member.id }) ? "On" : "Set 9pm–7am") {
                            var rows = store.quietHours.filter { $0.memberID != member.id }
                            rows.append(.make(memberID: member.id))
                            store.setQuietHours(rows)
                        }
                        .font(.caption.weight(.bold))
                    }
                }
            }
        }
    }

    private var recapCard: some View {
        HubPanel(symbol: "photo.on.rectangle", title: "Week recap") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("This week’s caption", text: $recapCaption)
                    .textFieldStyle(.roundedBorder)
                Button("Save recap note") {
                    let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                    store.addRecap(RecapPhoto(id: UUID(), weekStart: start, memberID: store.signedInMemberID, caption: recapCaption, createdAt: Date()))
                    recapCaption = ""
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.blue)
                ForEach(store.recapPhotos.prefix(6)) { row in
                    Text(row.caption).font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var leaveCard: some View {
        HubPanel(symbol: "figure.walk.departure", title: "Leave-by") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Lock Screen countdown uses the next event plus 20 minutes travel.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                if let next = store.events.filter({ $0.startAt > Date() }).sorted(by: { $0.startAt < $1.startAt }).first,
                   let mins = LeaveBy.minutesUntil(next) {
                    Text("Leave in \(max(0, mins)) min for \(next.title)")
                        .font(.title3.weight(.heavy))
                } else {
                    Text("Nothing to leave for yet.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }
}
