import MapKit
import SwiftUI
import WebKit

struct PlaceDetailView: View {
    @Environment(\.openURL) private var openURL
    let name: String
    var address: String?
    var phone: String?
    var website: URL?
    var coordinate: CLLocationCoordinate2D?
    var kindTitle: String
    var distance: String?
    var confirmTitle: String? = nil
    var onConfirm: (() -> Void)? = nil

    @StateObject private var facts = PlaceFacts()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HubPageTitle(lead: kindLead, tail: kindTail)
            PlaceHeroPhoto(name: name, address: address, coordinate: coordinate, website: website)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 3)
                )

            Text(name)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppTheme.text)

            HubPanel(symbol: "info.circle.fill", title: "Details") {
                VStack(alignment: .leading, spacing: 12) {
                    if let address, !address.isEmpty { detailRow("mappin.and.ellipse", address) }
                    if let phone = facts.phone ?? phone, !phone.isEmpty { detailRow("phone.fill", phone) }
                    if let distance { detailRow("location.fill", distance) }
                    if let cuisine = facts.cuisine { detailRow("fork.knife", cuisine) }
                }
            }

            HubPanel(symbol: "clock.fill", title: "Hours") {
                VStack(alignment: .leading, spacing: 10) {
                    if let openLabel = facts.openLabel {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(facts.isOpen == true ? AppTheme.todo : AppTheme.chore)
                                .frame(width: 10, height: 10)
                            Text(openLabel)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(facts.isOpen == true ? AppTheme.todo : AppTheme.chore)
                        }
                    }
                    if facts.hours.isEmpty {
                        Text(facts.loaded ? "Hours not listed for this location." : "Looking up hours…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(facts.hours) { row in
                            HStack {
                                Text(row.day)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Text(row.time)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
            }

            if let menu = PlaceMenus.url(for: name, website: facts.website ?? website) {
                HubPanel(symbol: "menucard", title: "Menu") {
                    VStack(alignment: .leading, spacing: 12) {
                        MenuWebView(url: menu)
                            .frame(height: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Button {
                            openURL(menu)
                        } label: {
                            Label("Open full menu", systemImage: "safari")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                if let phone = facts.phone ?? phone, !phone.isEmpty,
                   let tel = URL(string: "tel:\(phone.filter(\.isNumber))") {
                    action("Call", "phone.fill") { openURL(tel) }
                }
                action("Directions", "arrow.triangle.turn.up.right.diamond.fill") {
                    if let coordinate {
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        item.name = name
                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    } else if let address, let maps = URL(string: "http://maps.apple.com/?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address)") {
                        openURL(maps)
                    }
                }
            }

            if let confirmTitle, let onConfirm {
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await facts.load(name: name, address: address, coordinate: coordinate, fallbackURL: website, fallbackPhone: phone)
        }
    }

    private var kindLead: String {
        kindTitle.split(separator: " ").first.map(String.init) ?? kindTitle
    }

    private var kindTail: String {
        let parts = kindTitle.split(separator: " ").map(String.init)
        return parts.dropFirst().joined(separator: " ")
    }

    private func detailRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AppTheme.blue)
                .frame(width: 22)
            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.text)
            Spacer(minLength: 0)
        }
    }

    private func action(_ title: String, _ symbol: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.blue, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct MenuWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.scrollView.isScrollEnabled = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}
}
