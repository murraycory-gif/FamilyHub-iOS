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

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
            AtmosphereLayers(
                code: code,
                isDay: isDay,
                time: timeline.date.timeIntervalSinceReferenceDate
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

    private var kind: WeatherSky.Kind { WeatherSky.Kind.from(code: code, isDay: isDay) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: WeatherSky.colors(code: code, isDay: isDay),
                    startPoint: .top,
                    endPoint: .bottom
                )
                particles(size: geo.size)
                overlays(size: geo.size)
            }
        }
    }

    @ViewBuilder
    private func overlays(size: CGSize) -> some View {
        let mid = CGPoint(x: size.width * 0.50, y: size.height * 0.46)
        switch kind {
        case .clearNight:
            moon(at: mid, size: size, scale: 0.22)
        case .partlyNight:
            moon(at: mid, size: size, scale: 0.18)
        case .clearDay:
            sun(at: mid, size: size, scale: 0.34)
        case .partlyDay:
            sun(at: mid, size: size, scale: 0.22)
        case .thunder:
            Color.white.opacity(lightningFlash ? 0.18 : 0)
        default:
            EmptyView()
        }
    }

    private var lightningFlash: Bool {
        sin(time * 4.2) > 0.97 || sin(time * 6.1 + 1.7) > 0.985
    }

    private func particles(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            switch kind {
            case .clearNight:
                drawStars(context, size: canvasSize, dim: false)
            case .partlyNight:
                drawStars(context, size: canvasSize, dim: false)
                drawClouds(context, size: canvasSize, night: true, coverage: 0.55)
            case .cloudyNight:
                drawStars(context, size: canvasSize, dim: true)
                drawClouds(context, size: canvasSize, night: true, coverage: 1)
            case .partlyDay:
                drawClouds(context, size: canvasSize, night: false, coverage: 0.55)
            case .cloudyDay:
                drawClouds(context, size: canvasSize, night: false, coverage: 1)
            case .rain:
                drawClouds(context, size: canvasSize, night: !isDay, coverage: 1)
                drawRain(context, size: canvasSize, count: 42)
            case .thunder:
                drawClouds(context, size: canvasSize, night: true, coverage: 1)
                drawRain(context, size: canvasSize, count: 48)
            case .snow:
                drawClouds(context, size: canvasSize, night: !isDay, coverage: 0.7)
                drawSnow(context, size: canvasSize)
            case .fog:
                drawFog(context, size: canvasSize)
            case .clearDay:
                break
            }
        }
    }

    private func drawStars(_ context: GraphicsContext, size: CGSize, dim: Bool) {
        for star in Self.stars {
            let twinkle = 0.25 + 0.75 * (0.5 + 0.5 * sin(time * star.speed + star.phase))
            var ctx = context
            ctx.opacity = twinkle * (dim ? 0.4 : 1)
            let rect = CGRect(
                x: star.x * size.width,
                y: star.y * size.height * 0.78,
                width: star.size,
                height: star.size
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(.white))
        }
    }

    private func drawRain(_ context: GraphicsContext, size: CGSize, count: Int) {
        var ctx = context
        ctx.opacity = 0.38
        ctx.translateBy(x: 6, y: 0)
        ctx.rotate(by: .degrees(12))
        for i in 0..<count {
            let frac = CGFloat((i * 37) % 100) / 100
            let speed = 280.0 + Double(i % 11) * 22
            let travel = Double(size.height + 50)
            let y = CGFloat((time * speed + Double(i) * 41).truncatingRemainder(dividingBy: travel)) - 20
            let rect = CGRect(x: frac * size.width, y: y, width: 1.1, height: 14)
            ctx.fill(Path(roundedRect: rect, cornerRadius: 0.6), with: .color(.white))
        }
    }

    private func drawSnow(_ context: GraphicsContext, size: CGSize) {
        for i in 0..<28 {
            var ctx = context
            ctx.opacity = 0.55 + Double(i % 4) * 0.1
            let frac = CGFloat((i * 41) % 100) / 100
            let speed = 18.0 + Double(i % 7) * 5
            let travel = Double(size.height + 24)
            let y = CGFloat((time * speed + Double(i) * 33).truncatingRemainder(dividingBy: travel))
            let wobble = CGFloat(sin(time * 0.9 + Double(i))) * 10
            let s = CGFloat(2.2 + Double(i % 3))
            ctx.fill(Path(ellipseIn: CGRect(x: frac * size.width + wobble, y: y, width: s, height: s)), with: .color(.white))
        }
    }

    private func drawFog(_ context: GraphicsContext, size: CGSize) {
        var ctx = context
        ctx.addFilter(.blur(radius: 16))
        ctx.opacity = 0.22
        ctx.fill(Path(ellipseIn: CGRect(x: -20, y: size.height * 0.35, width: size.width + 40, height: size.height * 0.3)), with: .color(.white))
        ctx.opacity = 0.16
        ctx.fill(Path(ellipseIn: CGRect(x: -40, y: size.height * 0.55, width: size.width + 80, height: size.height * 0.28)), with: .color(.white))
    }

    private func drawClouds(_ context: GraphicsContext, size: CGSize, night: Bool, coverage: CGFloat) {
        let layers: [(y: CGFloat, scale: CGFloat, speed: Double, opacity: Double)] = [
            (0.30, 0.95, 0.018, night ? 0.22 : 0.55),
            (0.42, 0.78, 0.028, night ? 0.18 : 0.42),
            (0.36, 0.62, 0.022, night ? 0.16 : 0.38),
        ]
        let count = coverage >= 1 ? layers.count : 2
        for (index, layer) in layers.prefix(count).enumerated() {
            let travel = size.width + 220
            let x = CGFloat((time * layer.speed * Double(size.width) + Double(index) * 160).truncatingRemainder(dividingBy: Double(travel))) - 110
            var ctx = context
            ctx.addFilter(.blur(radius: 5))
            let color = night ? Color(hex: "8A97AE") : Color.white
            ctx.opacity = layer.opacity
            fillCloud(&ctx, x: x, y: size.height * layer.y, scale: layer.scale * min(size.width / 280, 1.15), color: color)
        }
    }

    private func fillCloud(_ ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat, color: Color) {
        let w: CGFloat = 168 * scale
        let h: CGFloat = 72 * scale
        let blobs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.08, 0.38, 0.36, 0.52),
            (0.28, 0.08, 0.42, 0.70),
            (0.52, 0.00, 0.48, 0.78),
            (0.74, 0.22, 0.34, 0.56),
            (0.18, 0.42, 0.40, 0.50),
            (0.44, 0.38, 0.46, 0.52),
            (0.66, 0.40, 0.36, 0.48),
        ]
        for blob in blobs {
            let rect = CGRect(
                x: x + blob.0 * w,
                y: y + blob.1 * h,
                width: blob.2 * w,
                height: blob.3 * h
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    private func moon(at point: CGPoint, size: CGSize, scale: CGFloat) -> some View {
        let side = min(size.width, size.height) * scale
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color(hex: "E4EAF4"), Color(hex: "9AA6BA")],
                        center: UnitPoint(x: 0.35, y: 0.32),
                        startRadius: 2,
                        endRadius: side / 2
                    )
                )
            Circle()
                .fill(Color(hex: "C5CDD8").opacity(0.25))
                .frame(width: side * 0.22, height: side * 0.18)
                .offset(x: -side * 0.12, y: side * 0.08)
            Circle()
                .fill(Color(hex: "C5CDD8").opacity(0.18))
                .frame(width: side * 0.14, height: side * 0.14)
                .offset(x: side * 0.14, y: -side * 0.06)
        }
        .frame(width: side, height: side)
        .shadow(color: .white.opacity(0.28), radius: 14)
        .position(point)
    }

    private func sun(at point: CGPoint, size: CGSize, scale: CGFloat) -> some View {
        let side = min(size.width, size.height) * scale
        return ZStack {
            Circle()
                .fill(Color(hex: "FFE08A").opacity(0.35))
                .frame(width: side * 1.8, height: side * 1.8)
                .blur(radius: 18)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color(hex: "FFE566"), Color(hex: "FFC44D").opacity(0.15)],
                        center: .center,
                        startRadius: 2,
                        endRadius: side / 2
                    )
                )
                .frame(width: side, height: side)
        }
        .frame(width: side * 1.8, height: side * 1.8)
        .position(point)
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
