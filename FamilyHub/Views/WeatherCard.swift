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
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "63D2FF"), Color(hex: "FFE08A")],
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
