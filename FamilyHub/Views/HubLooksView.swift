import SwiftUI

struct HubLook: Identifiable, Hashable {
    var id: Int
    var title: String
    var detail: String
    var asset: String

    static let all: [HubLook] = [
        .init(id: 1, title: "Refined current", detail: "Same Hub you have now, tightened. Calendar, weather, shopping, dinner, then the family row.", asset: "HubLook01"),
        .init(id: 2, title: "Magazine", detail: "Tonight’s dinner is a big photo on the left. Lists stack on the right. Family as circles.", asset: "HubLook02"),
        .init(id: 3, title: "Bento", detail: "iOS widget tiles. Big Today, weather, shopping, dinner, then a family strip.", asset: "HubLook03"),
        .init(id: 4, title: "Command center", detail: "A day timeline down the middle. Weather and shopping on the right. Family dock at the bottom.", asset: "HubLook04"),
        .init(id: 5, title: "Member columns", detail: "Four tall lanes — Family, Cory, Sandra, Liam. Each person’s day lives in their column.", asset: "HubLook05"),
        .init(id: 6, title: "Dinner first", detail: "Kitchen command. Huge What’s For Dinner on top, then the three cards, family along the bottom.", asset: "HubLook06"),
        .init(id: 7, title: "Swiss minimal", detail: "Lots of air, big type, almost no boxes. Circle portraits. Quiet and readable across the room.", asset: "HubLook07"),
        .init(id: 8, title: "Color block", detail: "Bold tiles and thick member colors. Playful, still adult.", asset: "HubLook08"),
        .init(id: 9, title: "Day timeline", detail: "Today as a schedule from morning to night. Events sit on the hours.", asset: "HubLook09"),
        .init(id: 10, title: "Dark luxury", detail: "Night wall panel. Navy glass, thin color outlines, dinner glow.", asset: "HubLook10")
    ]
}

struct HubLooksView: View {
    @AppStorage("hub.pickedLook") private var pickedLook = 0
    @State private var page = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text("Hub")
                    .foregroundStyle(AppTheme.text)
                Text("Looks")
                    .foregroundStyle(AppTheme.blue)
            }
            .font(.system(size: 36, weight: .bold))
            Text("Swipe the pictures. Tap Use this look when you want that layout built.")
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)

            TabView(selection: $page) {
                ForEach(HubLook.all) { look in
                    lookPage(look)
                        .tag(look.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(20)
        .background(AppTheme.bg.ignoresSafeArea())
        .onAppear {
            if pickedLook > 0 { page = pickedLook }
        }
    }

    private func lookPage(_ look: HubLook) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(look.asset)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(pickedLook == look.id ? AppTheme.blue : AppTheme.cardBorder, lineWidth: pickedLook == look.id ? 4 : 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            HStack(alignment: .firstTextBaseline) {
                Text("\(look.id). \(look.title)")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Text("\(look.id) / 10")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Text(look.detail)
                .font(.title3)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                pickedLook = look.id
            } label: {
                Text(pickedLook == look.id ? "Selected" : "Use this look")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(pickedLook == look.id ? AppTheme.todo : AppTheme.blue, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(8)
    }
}
