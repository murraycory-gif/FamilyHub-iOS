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
        case clearDay, clearNight, partlyDay, partlyNight, cloudyDay, cloudyNight, rain, thunder, snow, fog

        static func from(code: Int, isDay: Bool) -> Kind {
            switch code {
            case 95, 96, 99: return .thunder
            case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return .rain
            case 71, 73, 75, 77, 85, 86: return .snow
            case 45, 48: return .fog
            case 3: return isDay ? .cloudyDay : .cloudyNight
            case 2: return isDay ? .partlyDay : .partlyNight
            case 1: return isDay ? .partlyDay : .partlyNight
            default: return isDay ? .clearDay : .clearNight
            }
        }
    }
}

struct WeatherAtmosphere: View {
    let code: Int
    let isDay: Bool
    var showPhotos: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
            AtmosphereLayers(
                code: code,
                isDay: isDay,
                time: timeline.date.timeIntervalSinceReferenceDate,
                showPhotos: showPhotos
            )
        }
        .allowsHitTesting(false)
        .clipped()
    }
}

private struct AtmosphereLayers: View {
    let code: Int
    let isDay: Bool
    let time: TimeInterval
    var showPhotos: Bool = true

    private var kind: WeatherSky.Kind { WeatherSky.Kind.from(code: code, isDay: isDay) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: WeatherSky.colors(code: code, isDay: isDay),
                    startPoint: .top,
                    endPoint: .bottom
                )
                if !isDay {
                    Canvas { context, size in
                        drawStars(context, size: size, dim: kind == .cloudyNight || kind == .rain || kind == .thunder)
                    }
                }
                skyBody(size: geo.size)
                if showPhotos {
                    driftingSky(size: geo.size)
                }
                weatherFX(size: geo.size)
            }
        }
    }

    @ViewBuilder
    private func skyBody(size: CGSize) -> some View {
        switch kind {
        case .clearNight, .partlyNight:
            moon(in: size, scale: kind == .clearNight ? 0.46 : 0.38)
        case .clearDay:
            sun(in: size, scale: 0.58)
        case .partlyDay:
            sun(in: size, scale: 0.40)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func driftingSky(size: CGSize) -> some View {
        switch kind {
        case .partlyDay, .partlyNight:
            clouds(in: size, storm: false, coverage: 0.6)
        case .cloudyDay, .cloudyNight, .fog:
            clouds(in: size, storm: false, coverage: 1)
        case .rain, .thunder, .snow:
            clouds(in: size, storm: true, coverage: 1)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func weatherFX(size: CGSize) -> some View {
        switch kind {
        case .rain:
            Canvas { context, canvas in drawRain(context, size: canvas, count: 46) }
        case .thunder:
            Canvas { context, canvas in drawRain(context, size: canvas, count: 52) }
            Color.white.opacity(lightningFlash ? 0.2 : 0)
        case .snow:
            Canvas { context, canvas in drawSnow(context, size: canvas) }
        default:
            EmptyView()
        }
    }

    private var lightningFlash: Bool {
        sin(time * 4.2) > 0.97 || sin(time * 6.1 + 1.7) > 0.985
    }

    private func moon(in size: CGSize, scale: CGFloat) -> some View {
        let side = min(size.width, size.height) * scale
        let phase = Self.lunarPhase
        let illum = 1 - abs(2 * phase - 1)
        let dir: CGFloat = phase <= 0.5 ? -1 : 1
        let shadow = dir * illum * side * 0.92
        return ZStack {
            Image("WeatherMoon")
                .resizable()
                .scaledToFit()
            Circle()
                .fill(Color.black.opacity(0.82))
                .offset(x: shadow)
                .blur(radius: 0.6)
        }
        .frame(width: side, height: side)
        .clipShape(Circle())
        .shadow(color: .white.opacity(0.22), radius: 16)
        .position(x: size.width * 0.78, y: size.height * 0.50)
    }

    private func sun(in size: CGSize, scale: CGFloat) -> some View {
        let side = min(size.width, size.height) * scale
        return Image("WeatherSun")
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .position(x: size.width * 0.78, y: size.height * 0.42)
    }

    private func clouds(in size: CGSize, storm: Bool, coverage: CGFloat) -> some View {
        let name = storm ? "WeatherStorm" : "WeatherCloud"
        let travel = size.width + 320
        let x1 = CGFloat((time * 6).truncatingRemainder(dividingBy: Double(travel))) - 160
        let x2 = CGFloat((time * 4.2 + 140).truncatingRemainder(dividingBy: Double(travel))) - 160
        return ZStack {
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size.width * 1.05)
                .opacity(isDay ? 0.92 : 0.45)
                .offset(x: x1 - size.width * 0.15, y: size.height * 0.10)
            if coverage >= 0.8 {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.width * 0.9)
                    .opacity(isDay ? 0.7 : 0.32)
                    .offset(x: x2 - size.width * 0.05, y: size.height * 0.28)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawStars(_ context: GraphicsContext, size: CGSize, dim: Bool) {
        for star in Self.stars {
            let twinkle = 0.25 + 0.75 * (0.5 + 0.5 * sin(time * star.speed + star.phase))
            var ctx = context
            ctx.opacity = twinkle * (dim ? 0.4 : 1)
            let rect = CGRect(
                x: star.x * size.width,
                y: star.y * size.height * 0.82,
                width: star.size,
                height: star.size
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(.white))
        }
    }

    private func drawRain(_ context: GraphicsContext, size: CGSize, count: Int) {
        var ctx = context
        ctx.opacity = 0.4
        ctx.translateBy(x: 8, y: 0)
        ctx.rotate(by: .degrees(14))
        for i in 0..<count {
            let frac = CGFloat((i * 37) % 100) / 100
            let speed = 320.0 + Double(i % 11) * 24
            let travel = Double(size.height + 60)
            let y = CGFloat((time * speed + Double(i) * 41).truncatingRemainder(dividingBy: travel)) - 24
            let rect = CGRect(x: frac * size.width, y: y, width: 1.05, height: 16)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 0.6), with: .color(.white))
        }
    }

    private func drawSnow(_ context: GraphicsContext, size: CGSize) {
        for i in 0..<30 {
            var ctx = context
            ctx.opacity = 0.55 + Double(i % 4) * 0.1
            let frac = CGFloat((i * 41) % 100) / 100
            let speed = 16.0 + Double(i % 7) * 5
            let travel = Double(size.height + 24)
            let y = CGFloat((time * speed + Double(i) * 33).truncatingRemainder(dividingBy: travel))
            let wobble = CGFloat(sin(time * 0.9 + Double(i))) * 10
            let s = CGFloat(2.2 + Double(i % 3))
            ctx.fill(Path(ellipseIn: CGRect(x: frac * size.width + wobble, y: y, width: s, height: s)), with: .color(.white))
        }
    }

    /// 0 = new moon, 0.5 = full.
    private static var lunarPhase: Double {
        let epoch = Date(timeIntervalSince1970: 947_182_890)
        let days = Date().timeIntervalSince(epoch) / 86_400
        var age = days.truncatingRemainder(dividingBy: 29.530588673)
        if age < 0 { age += 29.530588673 }
        return age / 29.530588673
    }

    private struct SkyStar {
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var phase: Double
        var speed: Double
    }

    private static let stars: [SkyStar] = (0..<80).map { i in
        let n = Double(i)
        return SkyStar(
            x: CGFloat((n * 0.618033).truncatingRemainder(dividingBy: 1)),
            y: CGFloat((n * 0.139 + 0.03).truncatingRemainder(dividingBy: 1)),
            size: CGFloat(0.7 + Double(i % 5) * 0.45),
            phase: n * 0.63,
            speed: 0.55 + Double(i % 6) * 0.22
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
            VStack(alignment: .leading, spacing: 6) {
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
                        .foregroundStyle(.white.opacity(0.92))
                    Text("H:\(day?.high ?? temp)°  L:\(day?.low ?? temp)°")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.88))
                    Text("\(temp)°")
                        .font(.system(size: 58, weight: .thin))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 1)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                Spacer(minLength: 8)
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
                    .padding(.bottom, 10)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)
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

private struct WeatherGlyph: View {
    let code: Int
    var isDay: Bool = true
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: WeatherIcon.symbol(for: code, isDay: isDay))
            .font(.system(size: size, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .accessibilityLabel(WeatherIcon.condition(for: code, isDay: isDay))
    }

    private var tint: Color {
        switch code {
        case 0, 1: return isDay ? Color(hex: "E6A400") : AppTheme.blue
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return AppTheme.blue
        case 71, 73, 75, 77, 85, 86: return Color(hex: "5B8DEF")
        case 95, 96, 99: return Color(hex: "7C5CFC")
        default: return AppTheme.blue
        }
    }
}

struct WeatherOutlookView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var weather: WeatherLoader
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var showPlace = false
    @State private var focusedDay = Date()

    private var selected: WeatherDay? { weather.forecastDay(on: focusedDay) }
    private var hours: [WeatherHour] {
        if Calendar.current.isDateInToday(focusedDay) {
            return Array(weather.hours.filter { $0.at >= Date().addingTimeInterval(-30 * 60) }.prefix(24))
        }
        return weather.hoursOn(focusedDay)
    }
    private var isToday: Bool { Calendar.current.isDateInToday(focusedDay) }
    private var weekLow: Int { upcomingDays.map(\.low).min() ?? 0 }
    private var weekHigh: Int { upcomingDays.map(\.high).max() ?? 100 }
    private var skyIsDay: Bool { isToday ? (weather.now?.isDay ?? true) : true }
    private var skyCode: Int { isToday ? (weather.now?.code ?? selected?.code ?? 2) : (selected?.code ?? 2) }
    private var now: WeatherNow? { weather.now }
    private var canGoBack: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.startOfDay(for: focusedDay) > today
            && weather.forecastDay(on: shiftDate(-1)) != nil
    }
    private var canGoForward: Bool { weather.forecastDay(on: shiftDate(1)) != nil }

    private func shiftDate(_ delta: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: delta, to: Calendar.current.startOfDay(for: focusedDay)) ?? focusedDay
    }

    private func shift(_ delta: Int) {
        let next = shiftDate(delta)
        if weather.forecastDay(on: next) != nil {
            focusedDay = next
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    dayPager
                    detailsGrid
                    hourlyCard
                    dailyCard
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .simultaneousGesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width < -50 { shift(1) }
                        if value.translation.width > 50 { shift(-1) }
                    }
            )
            .onAppear { focusedDay = Calendar.current.startOfDay(for: day) }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.blue)
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
        ZStack {
            WeatherAtmosphere(code: skyCode, isDay: skyIsDay, showPhotos: false)
            VStack(spacing: 6) {
                WeatherGlyph(code: skyCode, isDay: skyIsDay, size: 44)
                Text("\(isToday ? (now?.temp ?? selected?.high ?? 0) : (selected?.high ?? 0))°")
                    .font(.system(size: 84, weight: .thin))
                    .monospacedDigit()
                Text(isToday ? (now?.condition ?? WeatherIcon.condition(for: skyCode, isDay: skyIsDay)) : WeatherIcon.condition(for: selected?.code ?? 2))
                    .font(.title2.weight(.semibold))
                Text("H:\(selected?.high ?? 0)°   L:\(selected?.low ?? 0)°")
                    .font(.title3.weight(.semibold).monospacedDigit())
                if isToday, let feels = now?.feelsLike {
                    Text("Feels like \(feels)°")
                        .font(.headline.weight(.medium))
                        .opacity(0.9)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 1)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var dayPager: some View {
        HStack(spacing: 16) {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(canGoBack ? AppTheme.blue : AppTheme.blue.opacity(0.3))
            }
            .disabled(!canGoBack)
            VStack(spacing: 2) {
                Text(focusedDay.formatted(.dateTime.weekday(.wide)))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(focusedDay.formatted(.dateTime.month(.wide).day().year()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Swipe for other days")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            Button { shift(1) } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(canGoForward ? AppTheme.blue : AppTheme.blue.opacity(0.3))
            }
            .disabled(!canGoForward)
        }
        .padding(.vertical, 4)
    }

    private var detailsGrid: some View {
        let uv = isToday ? (now?.uv ?? selected?.uv ?? 0) : (selected?.uv ?? 0)
        let humidity = now?.humidity ?? 0
        let wind = isToday ? (now?.windMph ?? selected?.windMph ?? 0) : (selected?.windMph ?? 0)
        let rain = selected?.precip ?? 0
        let rise = selected?.sunrise
        let set = selected?.sunset
        let tiles: [(String, String, String)] = [
            ("thermometer.medium", "Feels like", isToday ? "\(now?.feelsLike ?? 0)°" : "—"),
            ("humidity", "Humidity", isToday ? "\(humidity)%" : "—"),
            ("wind", "Wind", "\(wind) mph"),
            ("sun.max", "UV index", uvLabel(uv)),
            ("sunrise", "Sunrise", rise.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—"),
            ("sunset", "Sunset", set.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—"),
            ("cloud.rain", "Rain chance", "\(rain)%"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(tiles, id: \.1) { tile in
                VStack(alignment: .leading, spacing: 6) {
                    Label(tile.1, systemImage: tile.0)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .labelStyle(.titleAndIcon)
                    Text(tile.2)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next 24 hours")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                        VStack(spacing: 8) {
                            Text(hourHeading(index: index, date: hour.at))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            WeatherGlyph(code: hour.code, isDay: hour.isDay, size: 34)
                                .frame(height: 36)
                            Text(WeatherIcon.condition(for: hour.code, isDay: hour.isDay))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(hour.precip > 0 ? "\(hour.precip)%" : " ")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(hour.precip >= 20 ? AppTheme.blue : AppTheme.textTertiary)
                            Text("\(hour.temp)°")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppTheme.text)
                        }
                        .frame(width: 72)
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var dailyCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(upcomingDays.count)-day forecast")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.bottom, 8)
            ForEach(Array(upcomingDays.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayLabel(index, iso: item.dateISO, weekday: item.weekday))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text("\(dayDate(iso: item.dateISO, index: index)) · \(WeatherIcon.condition(for: item.code))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(width: 150, alignment: .leading)
                    WeatherGlyph(code: item.code, isDay: true, size: 32)
                        .frame(width: 40)
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption2)
                            .foregroundStyle(item.precip >= 20 ? AppTheme.blue : AppTheme.textTertiary.opacity(0.45))
                        Text("\(item.precip)%")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(item.precip >= 20 ? AppTheme.blue : AppTheme.textTertiary)
                    }
                    .frame(width: 58, alignment: .leading)
                    Text("\(item.low)°")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 40, alignment: .trailing)
                    TempRangeBar(low: item.low, high: item.high, weekLow: weekLow, weekHigh: weekHigh, height: 8)
                    Text("\(item.high)°")
                        .font(.body.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .background(
                    isFocused(item.dateISO) ? AppTheme.blueSoft : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .contentShape(Rectangle())
                .onTapGesture { jumpTo(iso: item.dateISO) }
                if index < upcomingDays.count - 1 {
                    Divider()
                }
            }
        }
        .padding(18)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func hourHeading(index: Int, date: Date) -> String {
        if index == 0 && isToday { return "Now" }
        if Calendar.current.component(.hour, from: date) == 0 {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))).replacingOccurrences(of: " ", with: "")
    }

    private var upcomingDays: [WeatherDay] {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let today = stamp.string(from: Date())
        return weather.days.filter { $0.dateISO >= today }
    }

    private func dayLabel(_ index: Int, iso: String, weekday: String) -> String {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        guard let date = stamp.date(from: iso) else { return weekday }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide))
    }

    private func dayDate(iso: String, index: Int) -> String {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        guard let date = stamp.date(from: iso) else { return "" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func jumpTo(iso: String) {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        if let date = stamp.date(from: iso) {
            focusedDay = date
        }
    }

    private func isFocused(_ iso: String) -> Bool {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        return stamp.string(from: focusedDay) == iso
    }

    private func uvLabel(_ value: Int) -> String {
        switch value {
        case 0: return "0 Low"
        case 1...2: return "\(value) Low"
        case 3...5: return "\(value) Mod"
        case 6...7: return "\(value) High"
        case 8...10: return "\(value) Very high"
        default: return "\(value) Extreme"
        }
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
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let span = max(CGFloat(weekHigh - weekLow), 1)
            let start = CGFloat(low - weekLow) / span
            let end = CGFloat(high - weekLow) / span
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.blue, Color(hex: "F59E0B")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height * 2, (end - start) * geo.size.width))
                    .offset(x: start * geo.size.width)
            }
        }
        .frame(height: height)
    }
}
