struct MealChoiceSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var path: [MealPath] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What’s for dinner")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.blue)
                        Text(dayTitle)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                    }
                    if let title = store.dinnerTitle(on: day) {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.todo)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Locked in")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.todo)
                                Text(title)
                                    .font(.title3.weight(.bold))
                            }
                            Spacer()
                            Button("Change") { store.clearDinner(on: day) }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                        }
                        .padding(18)
                        .background(AppTheme.todoSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        DinnerChoiceCard(
                            title: "Eat out",
                            detail: "Restaurants near you",
                            symbol: "takeoutbag.and.cup.and.straw.fill",
                            photo: URL(string: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80")
                        ) { path.append(.eatOut) }
                        DinnerChoiceCard(
                            title: "Family recipes",
                            detail: "Your kitchen, your people",
                            symbol: "book.closed.fill",
                            photo: URL(string: "https://images.unsplash.com/photo-1556910103-1c02745aae4d?auto=format&fit=crop&w=1200&q=80")
                        ) { path.append(.family) }
                        DinnerChoiceCard(
                            title: "Recipes",
                            detail: "A huge American cookbook",
                            symbol: "fork.knife.circle.fill",
                            photo: URL(string: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80")
                        ) { path.append(.recipes) }
                        DinnerChoiceCard(
                            title: "Enter a meal",
                            detail: "Type it yourself",
                            symbol: "square.and.pencil",
                            photo: URL(string: "https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=1200&q=80")
                        ) { path.append(.manual) }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(AppTheme.blue)
                }
            }
            .navigationDestination(for: MealPath.self) { item in
                switch item {
                case .eatOut: EatOutPicker(day: day) { dismiss() }
                case .family: FamilyRecipePicker(day: day) { dismiss() }
                case .recipes: CatalogRecipePicker(day: day) { dismiss() }
                case .manual: ManualMealSheet(day: day) { dismiss() }
                }
            }
        }
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) { return "Tonight" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

private struct DinnerChoiceCard: View {
    let title: String
    let detail: String
    let symbol: String
    let photo: URL?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RecipePhoto(url: photo)
                LinearGradient(
                    colors: [.clear, .black.opacity(0.25), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.white.opacity(0.22), in: Circle())
                    Spacer(minLength: 0)
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, minHeight: 230, maxHeight: 230)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}