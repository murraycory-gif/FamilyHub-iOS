import MapKit
import SwiftUI
import UIKit

struct HubCard<Content: View>: View {
    var fill: Color = AppTheme.card
    var stroke: Color = AppTheme.cardBorder
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .stroke(stroke, lineWidth: stroke == AppTheme.blue ? 3 : 1)
                    )
            )
    }
}

struct MemberDot: View {
    let member: FamilyMember?
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(member.map { Color(hex: $0.colorHex) } ?? AppTheme.forest)
            .frame(width: size, height: size)
    }
}

struct MemberAvatar: View {
    @EnvironmentObject private var store: HubStore
    let member: FamilyMember
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            if let data = store.photo(for: member), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color(hex: member.colorHex))
                Text(member.displayEmoji)
                    .font(.system(size: size * 0.48))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(AppTheme.cardBorder, lineWidth: 1)
        }
        .accessibilityLabel(member.name)
    }
}

struct MoneyText: View {
    let cents: Int

    var body: some View {
        Text(Money.cents(cents))
            .foregroundStyle(AppTheme.ice)
            .font(.headline.monospacedDigit())
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(AppTheme.textTertiary)
    }
}

struct EmptyHint: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.forest)
            Text(title).font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct FilterChip: View {
    let title: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? AppTheme.blue : AppTheme.blueSoft)
            )
            .foregroundStyle(selected ? Color.white : AppTheme.text)
        }
        .buttonStyle(.plain)
    }
}

struct MemberReorderDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    let onMove: (UUID, UUID) -> Void
    var onFinished: (() -> Void)?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        onFinished?()
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        onMove(draggingID, targetID)
    }
}

struct HubIconButton: View {
    let symbol: String
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 40, height: 36)
                .background(AppTheme.card, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.isEmpty ? symbol : label)
    }
}

struct HubNavLogo: View {
    var body: some View {
        Image("HubGlyph")
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .padding(.vertical, -10)
            .accessibilityLabel("HUB")
    }
}

struct HubChromeModifier: ViewModifier {
    @EnvironmentObject private var router: HubRouter
    @Environment(\.horizontalSizeClass) private var sizeClass
    var showBack: Bool

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(AppTheme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        if sizeClass == .regular {
                            HubIconButton(symbol: "sidebar.left", label: "Menu") {
                                router.toggleSidebar()
                            }
                        }
                        if showBack {
                            HubIconButton(symbol: "chevron.left", label: "HUB") {
                                router.open(.today)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    HubNavLogo()
                }
            }
    }
}

extension View {
    func hubChrome(showBack: Bool = false) -> some View {
        modifier(HubChromeModifier(showBack: showBack))
    }

    func backToHub(visible: Bool = true) -> some View {
        hubChrome(showBack: visible)
    }
}

struct HideSystemSidebarToggle: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = Sentinel()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? Sentinel)?.hideSoon()
    }

    final class Sentinel: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            hideSoon()
        }

        func hideSoon() {
            hideNow()
            DispatchQueue.main.async { self.hideNow() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.hideNow() }
        }

        private func hideNow() {
            guard let root = window?.rootViewController else { return }
            hide(in: root)
        }

        private func hide(in controller: UIViewController) {
            if let split = controller as? UISplitViewController {
                split.displayModeButtonVisibility = .never
            }
            for child in controller.children {
                hide(in: child)
            }
            if let presented = controller.presentedViewController {
                hide(in: presented)
            }
        }
    }
}

struct PhotoCropPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct PhotoCropper: View {
    let image: UIImage
    var onCancel: () -> Void
    var onCrop: (Data) -> Void

    @State private var scale: CGFloat = 1
    @State private var pinchStart: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var hole: CGFloat = 280

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let nextHole = min(geo.size.width, geo.size.height) * 0.58
                VStack(spacing: 18) {
                    ZStack {
                        Color.black.opacity(0.92)
                        imageView(hole: hole)
                            .frame(width: hole, height: hole)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(pan(hole: hole))
                    .simultaneousGesture(pinch(hole: hole))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Drag to center · pinch or slide to zoom")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Slider(value: Binding(
                            get: { scale },
                            set: { scale = $0; clamp(hole: hole) }
                        ), in: 1...4)
                        .tint(AppTheme.blue)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                }
                .onAppear { hole = nextHole }
                .onChange(of: nextHole) { _, value in hole = value }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Move and scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use photo") {
                        if let data = render(hole: hole) { onCrop(data) }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func imageView(hole: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(scale)
            .offset(offset)
            .frame(width: hole, height: hole)
    }

    private func pan(hole: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: dragStart.width + value.translation.width,
                    height: dragStart.height + value.translation.height
                )
            }
            .onEnded { _ in
                clamp(hole: hole)
                dragStart = offset
            }
    }

    private func pinch(hole: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(pinchStart * value, 1), 4)
            }
            .onEnded { _ in
                pinchStart = scale
                clamp(hole: hole)
            }
    }

    private func clamp(hole: CGFloat) {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }
        let fit = max(hole / size.width, hole / size.height)
        let current = fit * scale
        let maxX = max((size.width * current - hole) / 2, 0)
        let maxY = max((size.height * current - hole) / 2, 0)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        dragStart = offset
        pinchStart = scale
    }

    private func render(hole: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let fit = max(hole / size.width, hole / size.height)
        let current = fit * scale
        let origin = CGPoint(
            x: hole / 2 + offset.width - size.width * current / 2,
            y: hole / 2 + offset.height - size.height * current / 2
        )
        let side = hole / current
        let crop = CGRect(
            x: (0 - origin.x) / current,
            y: (0 - origin.y) / current,
            width: side,
            height: side
        )
        let output: CGFloat = 600
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: output, height: output))
        let cropped = renderer.image { _ in
            let draw = CGRect(
                x: -crop.origin.x * (output / side),
                y: -crop.origin.y * (output / side),
                width: size.width * (output / side),
                height: size.height * (output / side)
            )
            image.draw(in: draw)
        }
        return cropped.jpegData(compressionQuality: 0.86)
    }
}

struct PlaceSnapshot: View {
    let coordinate: CLLocationCoordinate2D
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            AppTheme.blueSoft
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.blue)
            }
        }
        .task(id: key) { await load() }
    }

    private var key: String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }

    private func load() async {
        if let cached = PlaceSnapshotCache.image(for: key) {
            image = cached
            return
        }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 350, longitudinalMeters: 350)
        options.size = CGSize(width: 480, height: 320)
        options.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .bakery])
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return }
        PlaceSnapshotCache.set(snapshot.image, for: key)
        image = snapshot.image
    }
}

enum PlaceSnapshotCache {
    private static var images: [String: UIImage] = [:]
    static func image(for key: String) -> UIImage? { images[key] }
    static func set(_ image: UIImage, for key: String) { images[key] = image }
}

struct PlaceHeroPhoto: View {
    let name: String
    var coordinate: CLLocationCoordinate2D?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            AppTheme.blueSoft
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: name) { await load() }
    }

    private func load() async {
        let key = "hero-\(name)-\(coordinate?.latitude ?? 0)"
        if let cached = PlaceSnapshotCache.image(for: key) {
            image = cached
            return
        }
        if let coordinate {
            let request = MKLookAroundSceneRequest(coordinate: coordinate)
            if let scene = try? await request.scene {
                let options = MKLookAroundSnapshotter.Options()
                options.size = CGSize(width: 800, height: 500)
                if let snap = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot {
                    PlaceSnapshotCache.set(snap.image, for: key)
                    image = snap.image
                    return
                }
            }
        }
        if let wiki = await wikipediaImage(for: name) {
            PlaceSnapshotCache.set(wiki, for: key)
            image = wiki
            return
        }
        if let wiki = await wikipediaSearch(name) {
            PlaceSnapshotCache.set(wiki, for: key)
            image = wiki
        }
    }

    private func wikipediaImage(for title: String) async -> UIImage? {
        let slug = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(slug)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("HUB/1.0 (family organizer)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let thumb = json["thumbnail"] as? [String: Any],
              let source = thumb["source"] as? String,
              let imageURL = URL(string: source),
              let (imgData, _) = try? await URLSession.shared.data(from: imageURL)
        else { return nil }
        return UIImage(data: imgData)
    }

    private func wikipediaSearch(_ query: String) async -> UIImage? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: "\(query) restaurant"),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "pithumbsize", value: "800"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("HUB/1.0 (family organizer)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryObj = json["query"] as? [String: Any],
              let pages = queryObj["pages"] as? [String: [String: Any]]
        else { return nil }
        for page in pages.values {
            if let thumb = page["thumbnail"] as? [String: Any],
               let source = thumb["source"] as? String,
               let imageURL = URL(string: source),
               let (imgData, _) = try? await URLSession.shared.data(from: imageURL),
               let image = UIImage(data: imgData) {
                return image
            }
        }
        return nil
    }
}

struct HubTileBanner<Trailing: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder var trailing: Trailing

    init(symbol: String, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.symbol = symbol
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
            Text(title)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            trailing
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue)
    }
}

extension HubTileBanner where Trailing == EmptyView {
    init(symbol: String, title: String) {
        self.init(symbol: symbol, title: title) { EmptyView() }
    }
}


