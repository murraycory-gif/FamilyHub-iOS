import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: HubStore
    @StateObject private var weather = WeatherLoader()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "HUB", tail: "Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HubPanel(symbol: "gearshape.fill", title: "Household") {
                        VStack(spacing: 10) {
                            NavigationLink {
                                FamilyView()
                            } label: {
                                settingsRow(
                                    symbol: "person.3.fill",
                                    title: "HUB Profiles",
                                    detail: "People, photos, birthdays, and contacts"
                                )
                            }
                            .buttonStyle(.plain)
                            NavigationLink {
                                CalendarSourcesView()
                            } label: {
                                settingsRow(
                                    symbol: "calendar.badge.plus",
                                    title: "Calendars",
                                    detail: "iCloud, Google, Outlook, and other calendars"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HubPanel(symbol: "cloud.sun.fill", title: "Weather") {
                        VStack(spacing: 10) {
                            NavigationLink {
                                WeatherPlacePicker()
                                    .environmentObject(store)
                                    .environmentObject(weather)
                            } label: {
                                settingsRow(
                                    symbol: "location.fill",
                                    title: store.weatherPlace?.label ?? "Set location",
                                    detail: "City, ZIP, or current location"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HubPanel(symbol: "ruler.fill", title: "Measurements") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Button("US") { store.setUnits(.us) }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(store.units == .us ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                                    .foregroundStyle(store.units == .us ? .white : AppTheme.blue)
                                    .font(.headline.weight(.bold))
                                Button("Metric") { store.setUnits(.metric) }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(store.units == .metric ? AppTheme.blue : AppTheme.blueSoft, in: Capsule())
                                    .foregroundStyle(store.units == .metric ? .white : AppTheme.blue)
                                    .font(.headline.weight(.bold))
                                Spacer()
                            }
                            measureRow("Temperature") {
                                ForEach(TemperatureUnit.allCases) { option in
                                    chip(option.name, on: store.units.temperature == option) {
                                        var next = store.units
                                        next.temperature = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Wind") {
                                ForEach(WindUnit.allCases) { option in
                                    chip(option.label, on: store.units.wind == option) {
                                        var next = store.units
                                        next.wind = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Rain") {
                                ForEach(PrecipUnit.allCases) { option in
                                    chip(option.name, on: store.units.precipitation == option) {
                                        var next = store.units
                                        next.precipitation = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Distance") {
                                ForEach(DistanceUnit.allCases) { option in
                                    chip(option.name, on: store.units.distance == option) {
                                        var next = store.units
                                        next.distance = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Speed") {
                                ForEach(SpeedUnit.allCases) { option in
                                    chip(option.label, on: store.units.speed == option) {
                                        var next = store.units
                                        next.speed = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Weight") {
                                ForEach(WeightUnit.allCases) { option in
                                    chip(option.name, on: store.units.weight == option) {
                                        var next = store.units
                                        next.weight = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Volume") {
                                ForEach(VolumeUnit.allCases) { option in
                                    chip(option.name, on: store.units.volume == option) {
                                        var next = store.units
                                        next.volume = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Length") {
                                ForEach(LengthUnit.allCases) { option in
                                    chip(option.name, on: store.units.length == option) {
                                        var next = store.units
                                        next.length = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                            measureRow("Time") {
                                ForEach(TimeFormatUnit.allCases) { option in
                                    chip(option.name, on: store.units.time == option) {
                                        var next = store.units
                                        next.time = option
                                        store.setUnits(next)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
    }

    private func measureRow<V: View>(_ title: String, @ViewBuilder chips: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            HStack(spacing: 8) {
                chips()
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
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

    private func settingsRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.blueSoft)
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.blue)
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
    }
}
