import SwiftUI

struct CalendarSourcesView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var ingest: CalendarIngestor
    @State private var showICS = false
    @State private var brandHint: CalendarBrand?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "HUB", tail: "Calendars") {
                HubHeaderPill(title: ingest.isSyncing ? "Syncing" : "Sync") {
                    Task { await ingest.sync(into: store) }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("HUB stays in sync with iCloud, Google, and Outlook calendars already on this iPad. Changes here write back to those calendars. Link-only calendars stay read-only.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    brandRow
                    deviceAccess
                    BillsCalendarPicker()
                        .coachSpot("srcBills")
                    if !store.calendarSources.isEmpty {
                        connected
                            .coachSpot("srcList")
                    }
                    if let message = ingest.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .hubTour("calendars", steps: HubTours.calendars)
        .navigationTitle("")
        .onAppear {
            ingest.refreshStatus()
            if ingest.isAuthorized {
                store.upsertCalendarSources(ingest.available)
            }
        }
        .onChange(of: ingest.available) { _, next in
            store.upsertCalendarSources(next)
        }
        .sheet(isPresented: $showICS) {
            AddICSSheet(brand: brandHint ?? .ics)
        }
    }

    private var brandRow: some View {
        HStack(spacing: 10) {
            ForEach(CalendarBrand.featured) { brand in
                Button {
                    brandHint = brand
                    Task {
                        if !ingest.isAuthorized {
                            await ingest.requestAccess()
                            store.upsertCalendarSources(ingest.available)
                        }
                        if ingest.available.contains(where: { $0.brand == brand }) {
                            ingest.message = "Turn on the \(brand.title) calendars below."
                        } else {
                            showICS = true
                        }
                    }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: brand.symbol)
                            .font(.title2)
                            .foregroundStyle(AppTheme.ice)
                        Text(brand.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var deviceAccess: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("On this iPad")
                    .font(.headline)
                Text(ingest.isAuthorized
                     ? "FamilyHub can read calendars already signed into the Calendar app — iCloud, Google, Outlook, Exchange."
                     : "Allow Calendar access, then any iCloud, Google, or Outlook account on this iPad can be turned on below.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack {
                    Button(ingest.isAuthorized ? "Refresh accounts" : "Allow Calendar access") {
                        Task {
                            if ingest.isAuthorized {
                                ingest.refreshStatus(resetStore: true)
                                await ingest.sync(into: store, quiet: true)
                            } else {
                                await ingest.requestAccess()
                                store.reconcileCalendarSources(ingest.available)
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button("Add link") {
                        brandHint = .ics
                        showICS = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private var connected: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Connected")
            ForEach(store.calendarSources) { source in
                sourceRow(source)
            }
        }
    }

    private func sourceRow(_ source: CalendarSource) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: source.brand.symbol)
                        .foregroundStyle(AppTheme.ice)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title).font(.headline)
                        Text(source.account.isEmpty ? source.brand.title : "\(source.brand.title) · \(source.account)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { source.isEnabled },
                        set: {
                            store.setSourceEnabled(source.id, enabled: $0)
                            ingest.scheduleSync(quiet: true)
                        }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.ice)
                }
                Picker("Show as", selection: Binding(
                    get: { source.use },
                    set: {
                        store.setSourceUse(source.id, use: $0)
                        ingest.scheduleSync(quiet: true)
                    }
                )) {
                    ForEach(CalendarHubUse.allCases) { use in
                        Text(use.label).tag(use)
                    }
                }
                .pickerStyle(.menu)
                if source.use == .familyCalendar {
                    Picker("On whose calendar", selection: Binding(
                        get: { source.memberID },
                        set: { store.setSourceMember(source.id, memberID: $0) }
                    )) {
                        Text("Whole family").tag(UUID?.none)
                        ForEach(store.members) { member in
                            Text(member.name).tag(Optional(member.id))
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    Text("Bills Due reminders — not on family calendars.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if let synced = source.lastSyncedAt {
                    Text("Synced \(synced.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Button(source.icsURL != nil ? "Remove link" : "Remove from HUB", role: .destructive) {
                    store.removeCalendarSource(source.id)
                }
                .font(.caption.weight(.semibold))
            }
        }
    }
}

private struct AddICSSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    var brand: CalendarBrand
    @State private var title = ""
    @State private var url = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $title)
                    TextField("https://…/basic.ics", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } footer: {
                    Text(help)
                }
            }
            .navigationTitle("Add \(brand.title) link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addICSSource(title: title, url: url.trimmingCharacters(in: .whitespacesAndNewlines), brand: brand == .ics ? .ics : brand)
                        dismiss()
                    }
                    .disabled(URL(string: url) == nil || url.count < 10)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var help: String {
        switch brand {
        case .google:
            return "In Google Calendar: Settings → the calendar → Integrate calendar → Secret address in iCal format."
        case .outlook:
            return "In Outlook on the web: Settings → View all → Shared calendars → Publish a calendar → ICS."
        case .icloud:
            return "In Calendar on a Mac: Calendar → Share Calendar → Public Calendar, then copy the webcal link (change webcal to https)."
        default:
            return "Paste any public or secret .ics / webcal link. FamilyHub imports the next six months."
        }
    }
}

struct BillsCalendarPicker: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var ingest: CalendarIngestor
    var compact: Bool = false

    private var selectedID: UUID? {
        store.calendarSources.first(where: { $0.use == .billsDue })?.id
    }

    private var suggested: [CalendarSource] {
        store.calendarSources.filter { CalendarSource.looksLikeBills($0.title) || $0.use == .billsDue }
    }

    private var others: [CalendarSource] {
        store.calendarSources.filter { source in
            !suggested.contains(where: { $0.id == source.id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !compact {
                SectionLabel(title: "Bills Due")
                Text("Pick the calendar that holds your bills. HUB names it Bills Due and keeps it off family calendars.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if store.calendarSources.isEmpty {
                Text("Connect calendars first, then pick the bills one here.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                if !suggested.isEmpty {
                    Text("Looks like bills")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.reminder)
                    ForEach(suggested) { source in
                        pickRow(source, highlight: true)
                    }
                }
                if !others.isEmpty {
                    Text(suggested.isEmpty ? "Pick a calendar" : "Or pick a different one")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(others) { source in
                        pickRow(source, highlight: false)
                    }
                }
                if selectedID != nil {
                    Button("Don’t use a bills calendar") {
                        store.setBillsCalendar(nil)
                        ingest.scheduleSync(quiet: true)
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.reminder)
                }
            }
        }
    }

    private func pickRow(_ source: CalendarSource, highlight: Bool) -> some View {
        let on = source.id == selectedID
        return Button {
            if on {
                store.setBillsCalendar(nil)
            } else {
                store.setBillsCalendar(source.id)
            }
            ingest.scheduleSync(quiet: true)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: highlight || on ? "dollarsign.circle.fill" : source.brand.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(on ? .white : (highlight ? AppTheme.reminder : AppTheme.blue))
                    .frame(width: 36, height: 36)
                    .background(
                        (on ? AppTheme.reminder : (highlight ? AppTheme.reminderSoft : AppTheme.blueSoft)),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(on ? "Set as Bills Due reminders" : (highlight ? "Suggested bills calendar" : source.brand.title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(on ? AppTheme.reminder : AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(on ? AppTheme.reminder : AppTheme.cardBorder)
            }
            .padding(12)
            .background(on ? AppTheme.reminderSoft : AppTheme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(on ? AppTheme.reminder : AppTheme.cardBorder, lineWidth: on ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
