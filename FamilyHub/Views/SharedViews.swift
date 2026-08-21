import SwiftUI
import PhotosUI
import UIKit

struct HubCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                    .fill(AppTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)
                            .stroke(AppTheme.cardBorder, lineWidth: 1)
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

struct BannerPreset: Identifiable {
    let id: String
    let title: String
    let startHex: String
    let endHex: String

    var colors: [Color] { [Color(hex: startHex), Color(hex: endHex)] }

    static let all: [BannerPreset] = [
        .init(id: "navy", title: "Navy", startHex: "0B1F3A", endHex: "2563EB"),
        .init(id: "azure", title: "Azure", startHex: "0284C7", endHex: "7DD3FC"),
        .init(id: "sunset", title: "Sunset", startHex: "9A3412", endHex: "F97316"),
        .init(id: "blush", title: "Blush", startHex: "9D174D", endHex: "F9A8D4"),
        .init(id: "forest", title: "Forest", startHex: "064E3B", endHex: "34D399"),
        .init(id: "dusk", title: "Dusk", startHex: "312E81", endHex: "C4B5FD"),
        .init(id: "night", title: "Night", startHex: "020617", endHex: "1E3A5F"),
        .init(id: "gold", title: "Gold", startHex: "92400E", endHex: "FBBF24"),
    ]

    func jpeg() -> Data? {
        let size = CGSize(width: 1200, height: 675)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            hexColor(startHex).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            hexColor(endHex).withAlphaComponent(0.85).setFill()
            UIRectFill(CGRect(x: 0, y: size.height * 0.35, width: size.width, height: size.height * 0.65))
        }
        return image.jpegData(compressionQuality: 0.9)
    }

    private func hexColor(_ hex: String) -> UIColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        return UIColor(
            red: CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >> 8) & 0xFF) / 255,
            blue: CGFloat(int & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct BannerStudio: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let current: Data?
    var onSave: (Data?) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var cropPayload: PhotoCropPayload?
    @State private var preview: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    bannerPreview
                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Photo", systemImage: "photo.on.rectangle")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(AppTheme.blueSoft, in: Capsule())
                                .foregroundStyle(AppTheme.blue)
                        }
                        .buttonStyle(.plain)
                        if let preview, let image = UIImage(data: preview) {
                            Button("Adjust") { cropPayload = PhotoCropPayload(image: image) }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                            Button("Clear") { preview = nil }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    SectionLabel(title: "Banners")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                        ForEach(BannerPreset.all) { preset in
                            Button {
                                preview = preset.jpeg()
                            } label: {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient(colors: preset.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(height: 78)
                                    .overlay(alignment: .bottomLeading) {
                                        Text(preset.title)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(8)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("\(title) banner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(preview)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { preview = current }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        cropPayload = PhotoCropPayload(image: image)
                    }
                }
            }
            .fullScreenCover(item: $cropPayload) { payload in
                PhotoCropper(
                    image: payload.image,
                    onCancel: { cropPayload = nil },
                    onCrop: { data in
                        preview = data
                        cropPayload = nil
                    }
                )
            }
        }
    }

    private var bannerPreview: some View {
        ZStack(alignment: .bottomLeading) {
            if let preview, let image = UIImage(data: preview) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [AppTheme.navy, AppTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .padding(16)
        }
        .frame(height: 160)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

