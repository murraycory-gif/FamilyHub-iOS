import SwiftUI

struct HubLook: Identifiable, Hashable {
    var id: Int
    var title: String
    var detail: String
    var asset: String

    static let all: [HubLook] = [
        .init(id: 1, title: "Skylight", detail: "Giant month on the wall. Color dots per person, meals sit on the day. Like a kitchen calendar display.", asset: "HubLook01"),
        .init(id: 2, title: "Echo Show", detail: "Kitchen glance. Huge clock and weather, next event, dinner, family dock along the bottom.", asset: "HubLook02"),
        .init(id: 3, title: "Cozi week", detail: "The #1 family organizer pattern. Color week on the left, meals and shopping on the right.", asset: "HubLook03"),
        .init(id: 4, title: "TimeTree day", detail: "One shared day, top to bottom. Each event is a color bar tagged to a person.", asset: "HubLook04"),
        .init(id: 5, title: "Things Today", detail: "Apple Design Award list. Giant Today heading, four beautiful rows: event, dinner, shop, home.", asset: "HubLook05"),
        .init(id: 6, title: "Apple Home", detail: "Glass widgets over a family photo. Weather, next event, dinner, shopping as big tiles.", asset: "HubLook06"),
        .init(id: 7, title: "Fantastical", detail: "Month on the left, agenda on the right. People as color ticks. Calendar-first families live here.", asset: "HubLook07"),
        .init(id: 8, title: "Photo frame", detail: "iPad as a family picture frame. Big photo, thin control strip: time, weather, next, dinner, shop.", asset: "HubLook08"),
        .init(id: 9, title: "At a Glance", detail: "Google Nest style. One huge next thing. Dinner, weather, shopping, people, counts around it.", asset: "HubLook09"),
        .init(id: 10, title: "Fridge door", detail: "Samsung Family Hub. Polaroid photos of everyone, overlay cards for today, weather, shopping.", asset: "HubLook10")
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
            Text("New set. Inspired by Skylight, Cozi, TimeTree, Echo Show, Things 3, Fantastical, and Apple Home. Swipe, then tap Use this look.")
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
