import SwiftUI

enum WeatherSky {
    static func colors(code: Int, isDay: Bool) -> [Color] {
        if !isDay {
            switch code {
            case 0, 1: return [Color(hex: "071428"), Color(hex: "163056")]
            case 2: return [Color(hex: "0C1428"), Color(hex: "243048")]
            case 3, 45, 48: return [Color(hex: "121820"), Color(hex: "2A3340")]
            default: return [Color(hex: "0A1018"), Color(hex: "1C2838")]
            }
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

    enum Kind {
        case clearDay, clearNight, cloudyDay, cloudyNight, rain, thunder, snow, fog

        static func from(code: Int, isDay: Bool) -> Kind {
            switch code {
            case 95, 96, 99: return .thunder
            case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return .rain
            case 71, 73, 75, 77, 85, 86: return .snow
            case 45, 48: return .fog
            case 3: return isDay ? .cloudyDay : .cloudyNight
            case 2: return isDay ? .cloudyDay : .cloudyNight
            default: return isDay ? .clearDay : .clearNight
            }
        }
    }
}

struct WeatherAtmosphere: View {
    let code: Int
    let isDay: Bool

    var body: some View {
        let kind = WeatherSky.Kind.from(code: code, isDay: isDay)
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack {
                    LinearGradient(
                        colors: WeatherSky.colors(code: code, isDay: isDay),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    switch kind {
                    case .clearNight, .cloudyNight:
                        stars(in: geo.size, time: t, dim: kind == .cloudyNight)
                        moon(in: geo.size)
                        if kind == .cloudyNight { driftingClouds(in: geo.size, time: t, opacity: 0.18) }
                    case .clearDay:
                        sun(in: geo.size)
                    case .cloudyDay:
                        sun(in: geo.size)
                        driftingClouds(in: geo.size, time: t, opacity: 0.35)
                    case .rain:
                        driftingClouds(in: geo.size, time: t, opacity: 0.22)
                        rain(in: geo.size, time: t, count: 28)
                    case .thunder:
                        driftingClouds(in: geo.size, time: t, opacity: 0.28)
                        rain(in: geo.size, time: t, count: 32)
                        lightning(time: t)
                    case .snow:
                        snow(in: geo.size, time: t)
                    case .fog:
                        Color.white.opacity(0.12)
                        driftingClouds(in: geo.size, time: t, opacity: 0.4)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .clipped()
    }

    private func stars(in size: CGSize, time: TimeInterval, dim: Bool) -> some View {
        Canvas { context, _ in
            for star in Self.stars {
                let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * star.speed + star.phase))
                var ctx = context
                ctx.opacity = twinkle * (dim ? 0.45 : 1)
                let rect = CGRect(
                    x: star.x * size.width,
                    y: star.y * size.height * 0.72,
                    width: star.size,
                    height: star.size
                )
                ctx.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
    }

    private func moon(in size: CGSize) -> some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.95))
            Circle()
                .fill(WeatherSky.colors(code: 0, isDay: false)[0])
                .offset(x: size.width * 0.035)
        }
        .frame(width: min(size.width, size.height) * 0.28, height: min(size.width, size.height) * 0.28)
        .blur(radius: 0.2)
        .shadow(color: .white.opacity(0.35), radius: 18)
        .position(x: size.width * 0.78, y: size.height * 0.28)
    }

    private func sun(in size: CGSize) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white, Color(hex: "FFE08A").opacity(0.85), Color.clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: min(size.width, size.height) * 0.38
                )
            )
            .frame(width: min(size.width, size.height) * 0.7, height: min(size.width, size.height) * 0.7)
            .position(x: size.width * 0.78, y: size.height * 0.22)
    }

    private func rain(in size: CGSize, time: TimeInterval, count: Int) -> some View {
        Canvas { context, _ in
            for i in 0..<count {
                let frac = CGFloat((i * 37) % 100) / 100
                let speed = 220.0 + Double(i % 9) * 18
                let travel = size.height + 30
                let y = CGFloat((time * speed + Double(i) * 47).truncatingRemainder(dividingBy: travel)) - 15
                let x = frac * size.width
                var path = Path()
                path.addRoundedRect(in: CGRect(x: x, y: y, width: 1.4, height: 11), cornerSize: CGSize(width: 1, height: 1))
                context.opacity = 0.45
                context.fill(path, with: .color(.white))
            }
        }
    }

    private func snow(in size: CGSize, time: TimeInterval) -> some View {
        Canvas { context, _ in
            for i in 0..<22 {
                let frac = CGFloat((i * 41) % 100) / 100
                let speed = 28.0 + Double(i % 7) * 6
                let travel = size.height + 20
                let y = CGFloat((time * speed + Double(i) * 33).truncatingRemainder(dividingBy: travel))
                let wobble = CGFloat(sin(time * 1.4 + Double(i))) * 8
                let rect = CGRect(x: frac * size.width + wobble, y: y, width: 3.2, height: 3.2)
                context.opacity = 0.7
                context.fill(Path(ellipseIn: rect), with: .color(.white))
            }
        }
    }

    private func lightning(time: TimeInterval) -> some View {
        let flash = sin(time * 4.2) > 0.97 || sin(time * 6.1 + 1.7) > 0.985
        return Color.white.opacity(flash ? 0.22 : 0)
    }

    private func driftingClouds(in size: CGSize, time: TimeInterval, opacity: Double) -> some View {
        let drift = CGFloat(sin(time * 0.12)) * size.width * 0.06
        return ZStack {
            Ellipse().fill(Color.white.opacity(opacity))
                .frame(width: size.width * 0.7, height: size.height * 0.22)
                .offset(x: drift - size.width * 0.1, y: -size.height * 0.18)
            Ellipse().fill(Color.white.opacity(opacity * 0.8))
                .frame(width: size.width * 0.55, height: size.height * 0.18)
                .offset(x: -drift + size.width * 0.18, y: -size.height * 0.02)
        }
        .blur(radius: 10)
    }

    private struct SkyStar {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var phase: Double
        var speed: Double
    }

    private static let stars: [SkyStar] = (0..<56).map { i in
        let n = Double(i)
        return SkyStar(
            x: CGFloat((n * 0.618).truncatingRemainder(dividingBy: 1)),
            y: CGFloat((n * 0.173 + 0.04).truncatingRemainder(dividingBy: 1)),
            size: CGFloat(1.0 + (i % 4) * 0.6),
            phase: n * 0.7,
            speed: 0.8 + Double(i % 5) * 0.25
        )
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

    private var skyIsDay: Bool {
        if isToday { return now?.isDay ?? false }
        return true
    }

    private var skyCode: Int {
        if isToday { return now?.code ?? day?.code ?? 2 }
        return day?.code ?? 2
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WeatherAtmosphere(code: skyCode, isDay: skyIsDay)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Button(action: onChangePlace) {
                            HStack(spacing: 4) {
                                Text(shortPlace)
                                    .font(.headline)
                                    .lineLimit(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        if isLoading && now == nil && day == nil {
                            ProgressView().tint(.white)
                        } else {
                            Text(condition)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("H:\(day?.high ?? temp)°  L:\(day?.low ?? temp)°")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Spacer(minLength: 4)
                    Text("\(temp)°")
                        .font(.system(size: 56, weight: .thin))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !hours.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(hours.prefix(5).enumerated()), id: \.element.id) { index, hour in
                            VStack(spacing: 4) {
                                Text(index == 0 && isToday ? "Now" : hourLabel(hour.at))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                Image(systemName: hour.symbolName)
                                    .font(.body)
                                    .symbolRenderingMode(.multicolor)
                                    .frame(height: 18)
                                Text("\(hour.temp)°")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onOpen)
    }

    private var shortPlace: String {
        placeLabel.split(separator: ",").first.map(String.init) ?? placeLabel
    }

    private func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
            .replacingOccurrences(of: " ", with: "")
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

    private var skyIsDay: Bool { isToday ? (weather.now?.isDay ?? true) : true }
    private var skyCode: Int { isToday ? (weather.now?.code ?? selected?.code ?? 2) : (selected?.code ?? 2) }

    var body: some View {
        NavigationStack {
            ZStack {
                WeatherAtmosphere(code: skyCode, isDay: skyIsDay)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        hero
                        hourlyCard
                        weekCard
                    }
                    .padding(20)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
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
                        .foregroundStyle(.white)
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
        VStack(spacing: 4) {
            Text(store.weatherPlace?.label.split(separator: ",").first.map(String.init) ?? "Weather")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text("\(isToday ? (weather.now?.temp ?? selected?.high ?? 0) : (selected?.high ?? 0))°")
                .font(.system(size: 96, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(isToday ? (weather.now?.condition ?? "") : WeatherIcon.condition(for: selected?.code ?? 2))
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
            Text("H:\(selected?.high ?? 0)°   L:\(selected?.low ?? 0)°")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
            if isToday, let feels = weather.now?.feelsLike {
                Text("Feels like \(feels)°")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isToday ? "Hourly" : day.formatted(.dateTime.weekday(.wide)))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(hours.prefix(24).enumerated()), id: \.element.id) { index, hour in
                        VStack(spacing: 8) {
                            Text(index == 0 && isToday ? "Now" : hour.at.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))).replacingOccurrences(of: " ", with: ""))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                            Image(systemName: hour.symbolName)
                                .font(.title3)
                                .symbolRenderingMode(.multicolor)
                            if hour.precip >= 20 {
                                Text("\(hour.precip)%")
                                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Color(hex: "A8D8FF"))
                            }
                            Text("\(hour.temp)°")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .frame(width: 48)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("7-day forecast")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .padding(.bottom, 6)
            ForEach(Array(weather.days.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 8) {
                    Text(index == 0 ? "Today" : item.weekday)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, alignment: .leading)
                    Image(systemName: item.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 28)
                    Text("\(item.low)°")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 32, alignment: .trailing)
                    TempRangeBar(low: item.low, high: item.high, weekLow: weekLow, weekHigh: weekHigh)
                    Text("\(item.high)°")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.vertical, 8)
                if index < weather.days.count - 1 {
                    Divider().overlay(Color.white.opacity(0.12))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
