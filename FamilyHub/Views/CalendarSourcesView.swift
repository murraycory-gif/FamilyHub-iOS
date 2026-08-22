import SwiftUI

struct CalendarSourcesView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var ingest: CalendarIngestor
    @State private var showICS = false
    @State private var brandHint: CalendarBrand?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("HUB stays in sync with iCloud, Google, and Outlook calendars already on this iPad. Changes here write back to those calendars. Link-only calendars stay read-only.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    brandRow
                    deviceAccess
                    if !store.calendarSources.isEmpty {
                        connected
                    }
                    if let message = ingest.message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Calendars")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await ingest.sync(into: store) }
                    } label: {
                        if ingest.isSyncing { ProgressView() } else { Text("Sync") }
                    }
                    .disabled(!store.calendarSources.contains(where: \.isEnabled))
                }
            }
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
