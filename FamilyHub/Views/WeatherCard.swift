import SwiftUI

enum WeatherSky {
    static func colors(code: Int, isDay: Bool) -> [Color] {
        if !isDay {
            return [Color(hex: "0B1026"), Color(hex: "1C2A4A")]
        }
        switch code {
        case 0, 1: return [Color(hex: "2F80D4"), Color(hex: "6EB5E8")]
        case 2: return [Color(hex: "4A86C4"), Color(hex: "86B2D4")]
        case 3: return [Color(hex: "5A6E82"), Color(hex: "8A9AAB")]
        case 45, 48: return [Color(hex: "6B7684"), Color(hex: "9AA4B0")]
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return [Color(hex: "3E5368"), Color(hex: "6A7E92")]
        case 71, 73, 75, 77, 85, 86: return [Color(hex: "7A8CA0"), Color(hex: "C0CCD8")]
        case 95, 96, 99: return [Color(hex: "2A3344"), Color(hex: "4A5568")]
        default: return [Color(hex: "2F80D4"), Color(hex: "6EB5E8")]
        }
    }
}

struct AppleWeatherCard: View {
    let placeLabel: String
    let now: WeatherNow?
    let hours: [WeatherHour]
    let days: [WeatherDay]
    let isLoading: Bool
    let errorMessage: String?
    var onChangePlace: () -> Void

    private var weekLow: Int { days.map(\.low).min() ?? 0 }
    private var weekHigh: Int { days.map(\.high).max() ?? 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
            if !hours.isEmpty {
                Divider().overlay(Color.white.opacity(0.18))
                hourly
            }
            if !days.isEmpty {
                Divider().overlay(Color.white.opacity(0.18))
                daily
            }
        }
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: WeatherSky.colors(code: now?.code ?? days.first?.code ?? 2, isDay: now?.isDay ?? true),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var hero: some View {
        VStack(spacing: 2) {
            Button(action: onChangePlace) {
                HStack(spacing: 4) {
                    Text(shortPlace)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .opacity(0.95)
            }
            .buttonStyle(.plain)

            if isLoading && now == nil {
                ProgressView().tint(.white).padding(.vertical, 16)
            } else if let errorMessage, now == nil, days.isEmpty {
                Text(errorMessage)
                    .font(.subheadline)
                    .opacity(0.85)
                    .padding(.vertical, 12)
            } else {
                Text("\(now?.temp ?? days.first?.high ?? 0)°")
                    .font(.system(size: 72, weight: .thin))
                    .monospacedDigit()
                    .padding(.top, -6)
                Text(now?.condition ?? WeatherIcon.condition(for: days.first?.code ?? 2))
                    .font(.headline.weight(.medium))
                    .opacity(0.95)
                Text("H:\(nowHigh)°  L:\(nowLow)°")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .opacity(0.9)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var hourly: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                    VStack(spacing: 8) {
                        Text(index == 0 ? "Now" : hour.at.formatted(date: .omitted, time: .shortened).replacingOccurrences(of: ":00", with: ""))
                            .font(.caption.weight(.semibold))
                            .opacity(0.9)
                        Image(systemName: hour.symbolName)
                            .font(.title3)
                            .symbolRenderingMode(.multicolor)
                            .frame(height: 22)
                        if hour.precip >= 20 {
                            Text("\(hour.precip)%")
                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                .foregroundStyle(Color(hex: "A8D8FF"))
                        }
                        Text("\(hour.temp)°")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .frame(width: 44)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var daily: some View {
        VStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                HStack(spacing: 8) {
                    Text(index == 0 ? "Today" : day.weekday)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 52, alignment: .leading)
                    VStack(spacing: 1) {
                        Image(systemName: day.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.body)
                        if day.precip >= 20 {
                            Text("\(day.precip)%")
                                .font(.system(size: 9, weight: .bold).monospacedDigit())
                                .foregroundStyle(Color(hex: "A8D8FF"))
                        }
                    }
                    .frame(width: 28)
                    Text("\(day.low)°")
                        .font(.subheadline.monospacedDigit())
                        .opacity(0.65)
                        .frame(width: 28, alignment: .trailing)
                    TempRangeBar(low: day.low, high: day.high, weekLow: weekLow, weekHigh: weekHigh)
                    Text("\(day.high)°")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                if index < days.count - 1 {
                    Divider().overlay(Color.white.opacity(0.10))
                }
            }
        }
        .padding(.bottom, 8)
        .padding(.top, 4)
    }

    private var shortPlace: String {
        placeLabel.split(separator: ",").first.map(String.init) ?? placeLabel
    }

    private var nowHigh: Int { days.first?.high ?? now?.temp ?? 0 }
    private var nowLow: Int { days.first?.low ?? now?.temp ?? 0 }
}

struct HubWeatherTile: View {
    let placeLabel: String
    let now: WeatherNow?
    let day: WeatherDay?
    let hours: [WeatherHour]
    let isToday: Bool
    let isLoading: Bool
    var onOpen: () -> Void
    var onChangePlace: () -> Void

    private var temp: Int {
        if isToday { return now?.temp ?? day?.high ?? 0 }
        return day?.high ?? 0
    }

    private var condition: String {
        if isToday { return now?.condition ?? WeatherIcon.condition(for: day?.code ?? 2) }
        return WeatherIcon.condition(for: day?.code ?? 2)
    }

    private var symbol: String {
        if isToday { return now?.symbolName ?? day?.symbolName ?? "cloud.sun.fill" }
        return day?.symbolName ?? "cloud.sun.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onChangePlace) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(shortPlace)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(AppTheme.blue)
            }
            .buttonStyle(.plain)

            if isLoading && now == nil && day == nil {
                Spacer()
                ProgressView().tint(AppTheme.blue)
                Spacer()
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(temp)°")
                            .font(.system(size: 52, weight: .thin))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.text)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(condition)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                        Text("H:\(day?.high ?? temp)°  L:\(day?.low ?? temp)°")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: symbol)
                        .font(.system(size: 34))
                        .symbolRenderingMode(.multicolor)
                        .symbolVariant(.fill)
                }

                if !hours.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(hours.prefix(5).enumerated()), id: \.element.id) { index, hour in
                            VStack(spacing: 4) {
                                Text(index == 0 && isToday ? "Now" : hour.at.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted))))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                                Image(systemName: hour.symbolName)
                                    .font(.caption)
                                    .symbolRenderingMode(.multicolor)
                                Text("\(hour.temp)°")
                                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(AppTheme.text)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onOpen)
    }

    private var shortPlace: String {
        placeLabel.split(separator: ",").first.map(String.init) ?? placeLabel
    }
}

struct WeatherOutlookView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var weather: WeatherLoader
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var showPlace = false

    private var selected: WeatherDay? { weather.forecastDay(on: day) }
    private var hours: [WeatherHour] { weather.hoursOn(day) }
    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var weekLow: Int { weather.days.map(\.low).min() ?? 0 }
    private var weekHigh: Int { weather.days.map(\.high).max() ?? 100 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    hourlyCard
                    weekCard
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Button { showPlace = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                            Text(store.weatherPlace?.label ?? "Weather")
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                        }
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    }
                }
            }
            .sheet(isPresented: $showPlace) {
                WeatherPlacePicker()
                    .environmentObject(store)
                    .environmentObject(weather)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 6) {
            Image(systemName: isToday ? (weather.now?.symbolName ?? "cloud.sun.fill") : (selected?.symbolName ?? "cloud.sun.fill"))
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)
            Text("\(isToday ? (weather.now?.temp ?? selected?.high ?? 0) : (selected?.high ?? 0))°")
                .font(.system(size: 84, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(AppTheme.text)
            Text(isToday ? (weather.now?.condition ?? "") : WeatherIcon.condition(for: selected?.code ?? 2))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text("H:\(selected?.high ?? 0)°   L:\(selected?.low ?? 0)°")
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.text)
            if isToday, let feels = weather.now?.feelsLike {
                Text("Feels like \(feels)°")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isToday ? "Hourly" : day.formatted(.dateTime.weekday(.wide)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(hours.prefix(24).enumerated()), id: \.element.id) { index, hour in
                        VStack(spacing: 8) {
                            Text(index == 0 && isToday ? "Now" : hour.at.formatted(date: .omitted, time: .shortened).replacingOccurrences(of: ":00", with: ""))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Image(systemName: hour.symbolName)
                                .font(.title3)
                                .symbolRenderingMode(.multicolor)
                            if hour.precip >= 20 {
                                Text("\(hour.precip)%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(AppTheme.blue)
                            }
                            Text("\(hour.temp)°")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(AppTheme.text)
                        }
                        .frame(width: 48)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("7-day forecast")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.bottom, 6)
            ForEach(Array(weather.days.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Text(index == 0 ? "Today" : item.weekday)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .frame(width: 52, alignment: .leading)
                    Image(systemName: item.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 28)
                    Text("\(item.low)°")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 32, alignment: .trailing)
                    TempRangeBar(low: item.low, high: item.high, weekLow: weekLow, weekHigh: weekHigh)
                    Text("\(item.high)°")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 8)
                if index < weather.days.count - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct WeatherPlacePicker: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var weather: WeatherLoader
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var locating = false
    @State private var locateError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await useLocation() }
                    } label: {
                        HStack {
                            Image(systemName: "location.fill").foregroundStyle(AppTheme.blue)
                            Text(locating ? "Finding you…" : "Use current location")
                            Spacer()
                            if locating { ProgressView() }
                        }
                    }
                    if let locateError {
                        Text(locateError).foregroundStyle(AppTheme.chore)
                    }
                }
                Section("City or ZIP") {
                    TextField("Chicago or 60614", text: $query)
                        .textInputAutocapitalization(.words)
                        .onChange(of: query) { _, value in
                            Task { await weather.search(query: value) }
                        }
                    ForEach(weather.searchResults) { place in
                        Button {
                            store.setWeatherPlace(place)
                            Task { await weather.load(place: place) }
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.label).foregroundStyle(AppTheme.text)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Weather location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func useLocation() async {
        locating = true
        locateError = nil
        defer { locating = false }
        do {
            let place = try await weather.placeFromCurrentLocation()
            store.setWeatherPlace(place)
            await weather.load(place: place)
            dismiss()
        } catch {
            locateError = error.localizedDescription
        }
    }
}

private struct TempRangeBar: View {
    let low: Int
    let high: Int
    let weekLow: Int
    let weekHigh: Int

    var body: some View {
        GeometryReader { geo in
            let span = max(CGFloat(weekHigh - weekLow), 1)
            let start = CGFloat(low - weekLow) / span
            let end = CGFloat(high - weekLow) / span
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.blueSoft)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.blue, Color(hex: "F59E0B")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, (end - start) * geo.size.width))
                    .offset(x: start * geo.size.width)
            }
        }
        .frame(height: 4)
    }
}
