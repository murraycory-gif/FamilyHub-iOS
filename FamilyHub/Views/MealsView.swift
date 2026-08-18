import MapKit
import SwiftUI

private enum MealsTab: String, CaseIterable, Identifiable {
    case week, recipes, nearby
    var id: String { rawValue }
    var title: String {
        switch self {
        case .week: return "This week"
        case .recipes: return "Recipes"
        case .nearby: return "Nearby"
        }
    }
}

struct MealsView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @StateObject private var catalog = RecipeCatalog()
    @StateObject private var places = PlacesSearch()
    @State private var tab: MealsTab = .week
    @State private var showAdd = false
    @State private var pickDay: Date?
    @State private var selectedCatalog: CatalogRecipe?
    @State private var selectedPlace: NearbyPlace?
    @State private var selectedSaved: Recipe?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(MealsTab.allCases) { item in
                        FilterChip(title: item.title, color: AppTheme.blue, selected: tab == item) {
                            tab = item
                        }
                    }
                }

                switch tab {
                case .week: weekSection
                case .recipes: recipesSection
                case .nearby: nearbySection
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if tab == .recipes {
                    HubIconButton(symbol: "plus", label: "Add recipe") { showAdd = true }
                }
            }
        }
        .sheet(isPresented: $showAdd) { AddRecipeSheet() }
        .fullScreenCover(item: pickDayBinding) { day in
            DinnerPlannerView(day: day.date)
        }
        .sheet(item: $selectedCatalog) { recipe in
            CatalogRecipeSheet(recipe: recipe, day: router.mealsDay)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailSheet(place: place, day: router.mealsDay)
        }
        .sheet(item: $selectedSaved) { recipe in
            SavedRecipeSheet(recipe: recipe, day: router.mealsDay)
        }
        .task {
            await catalog.load()
        }
        .onChange(of: tab) { _, next in
            if next == .nearby, places.places.isEmpty {
                Task { await places.load() }
            }
        }
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Dinner this week")
            ForEach(week, id: \.self) { day in
                Button { pickDay = day } label: {
                    HubCard {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dayLabel(day))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                                Text(store.dinnerTitle(on: day) ?? "Nothing planned")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(store.dinnerTitle(on: day) == nil ? AppTheme.textSecondary : AppTheme.text)
                                if let plan = store.dinner(on: day), let kind = plan.placeKind {
                                    Text(kind == "takeout" ? "Takeout" : "Sit down")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.blue)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.textTertiary)
                TextField("Search recipes", text: $catalog.query)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await catalog.search() } }
                if catalog.isLoading { ProgressView() }
            }
            .padding(12)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(catalog.categories, id: \.self) { item in
                        FilterChip(title: item, color: AppTheme.blue, selected: catalog.category == item) {
                            catalog.category = item
                            Task { await catalog.search() }
                        }
                    }
                }
            }

            if !store.recipes.isEmpty {
                SectionLabel(title: "Saved in HUB")
                ForEach(store.recipes) { recipe in
                    Button { selectedSaved = recipe } label: {
                        recipeRow(name: recipe.name, detail: recipe.kind.label, imageURL: recipe.imageURL)
                    }
                    .buttonStyle(.plain)
                }
            }

            SectionLabel(title: "Recipe library")
            if let message = catalog.message {
                Text(message).foregroundStyle(AppTheme.textSecondary)
            }
            ForEach(catalog.recipes) { recipe in
                Button {
                    Task {
                        selectedCatalog = await catalog.detail(id: recipe.id) ?? recipe
                    }
                } label: {
                    recipeRow(name: recipe.name, detail: [recipe.category, recipe.area].filter { !$0.isEmpty }.joined(separator: " · "), imageURL: recipe.thumb?.absoluteString ?? "")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(PlaceMode.allCases) { mode in
                    FilterChip(title: mode.title, color: AppTheme.blue, selected: places.mode == mode) {
                        Task { await places.setMode(mode) }
                    }
                }
                Spacer()
                if places.isLoading { ProgressView() }
            }
            Text(places.mode == .takeout ? "Takeout and quick pickup near you." : "Sit-down restaurants near you.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            if let message = places.message {
                Text(message).foregroundStyle(AppTheme.textSecondary)
            }

            ForEach(places.places) { place in
                Button { selectedPlace = place } label: {
                    HubCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: places.mode == .takeout ? "takeoutbag.and.cup.and.straw.fill" : "fork.knife")
                                .foregroundStyle(AppTheme.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name).font(.headline)
                                if !place.address.isEmpty {
                                    Text(place.address)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                HStack(spacing: 8) {
                                    if let distance = place.distanceLabel {
                                        Text(distance).font(.caption.weight(.semibold))
                                    }
                                    if !place.phone.isEmpty {
                                        Text(place.phone).font(.caption)
                                    }
                                }
                                .foregroundStyle(AppTheme.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recipeRow(name: String, detail: String, imageURL: String) -> some View {
        HubCard {
            HStack(spacing: 12) {
                recipeThumb(imageURL)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.headline).foregroundStyle(AppTheme.text)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }

    private func recipeThumb(_ urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    AppTheme.blueSoft
                }
            } else {
                ZStack {
                    AppTheme.blueSoft
                    Image(systemName: "fork.knife").foregroundStyle(AppTheme.blue)
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var week: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Tonight" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var pickDayBinding: Binding<DatedDay?> {
        Binding(
            get: { pickDay.map(DatedDay.init) },
            set: { pickDay = $0?.date }
        )
    }
}

private struct DatedDay: Identifiable {
    var date: Date
    var id: TimeInterval { Calendar.current.startOfDay(for: date).timeIntervalSince1970 }
}

struct DinnerPlannerView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let day: Date

    private enum Pane: String, CaseIterable, Identifiable {
        case saved, recipes, nearby
        var id: String { rawValue }
        var title: String {
            switch self {
            case .saved: return "Saved"
            case .recipes: return "Recipes"
            case .nearby: return "Nearby"
            }
        }
    }

    private enum Draft: Equatable {
        case none
        case recipe(UUID)
        case place(name: String, address: String, phone: String, url: String, kind: String)
    }

    @StateObject private var catalog = RecipeCatalog()
    @StateObject private var places = PlacesSearch()
    @State private var pane: Pane = .saved
    @State private var draft: Draft = .none
    @State private var showLeaveAlert = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(Pane.allCases) { item in
                        FilterChip(title: item.title, color: AppTheme.blue, selected: pane == item) {
                            pane = item
                            if item == .recipes { Task { await catalog.load() } }
                            if item == .nearby { Task { await places.load() } }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 20)

                if case .recipe(let id) = draft, let recipe = store.recipe(id: id) {
                    selectionBanner(recipe.name, "Recipe")
                } else if case .place(let name, _, _, _, let kind) = draft {
                    selectionBanner(name, kind == "takeout" ? "Takeout" : "Sit down")
                }

                ScrollView {
                    Group {
                        switch pane {
                        case .saved: savedList
                        case .recipes: recipesList
                        case .nearby: nearbyList
                        }
                    }
                    .padding(20)
                }
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { attemptClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Save dinner?", isPresented: $showLeaveAlert) {
                Button("Save") { save(); dismiss() }
                Button("Don't Save", role: .destructive) { dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You picked something for \(dayTitle.lowercased()) but haven’t saved it.")
            }
        }
        .interactiveDismissDisabled()
        .task {
            seedDraft()
            await catalog.load()
        }
    }

    private func seedDraft() {
        if let plan = store.dinner(on: day) {
            if let id = plan.recipeID {
                draft = .recipe(id)
            } else if let name = plan.placeName {
                draft = .place(
                    name: name,
                    address: plan.placeAddress ?? "",
                    phone: plan.placePhone ?? "",
                    url: plan.placeURL ?? "",
                    kind: plan.placeKind ?? "sitdown"
                )
            }
        }
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) { return "Tonight" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var subtitle: String {
        switch pane {
        case .saved: return "Meals you’ve saved in HUB."
        case .recipes: return "Search the recipe library, then tap one for dinner."
        case .nearby: return "Takeout or a sit-down place near you."
        }
    }

    private var isDirty: Bool {
        switch draft {
        case .none:
            return false
        case .recipe(let id):
            return store.dinner(on: day)?.recipeID != id
        case .place(let name, _, _, _, _):
            return store.dinner(on: day)?.placeName != name
        }
    }

    private func attemptClose() {
        if isDirty { showLeaveAlert = true } else { dismiss() }
    }

    private func save() {
        switch draft {
        case .none:
            store.clearDinner(on: day)
        case .recipe(let id):
            store.setDinner(on: day, recipeID: id)
        case .place(let name, let address, let phone, let url, let kind):
            store.setDinnerPlace(on: day, name: name, address: address, phone: phone, url: url, kind: kind)
        }
    }

    private func selectionBanner(_ title: String, _ kind: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Selected").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.blue)
                Text(title).font(.headline)
            }
            Spacer()
            Text(kind)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.blue)
        }
        .padding(14)
        .background(AppTheme.blueSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var savedList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { draft = .none } label: {
                plannerRow(title: "Nothing planned", detail: "Clear this night", selected: draft == .none)
            }
            .buttonStyle(.plain)

            ForEach(store.recipes) { recipe in
                Button { draft = .recipe(recipe.id) } label: {
                    plannerRow(title: recipe.name, detail: recipe.kind.label, selected: draft == .recipe(recipe.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recipesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.textTertiary)
                TextField("Search chicken, tacos, pasta…", text: $catalog.query)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await catalog.search() } }
                if catalog.isLoading { ProgressView() }
            }
            .padding(12)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(catalog.categories, id: \.self) { item in
                        FilterChip(title: item, color: AppTheme.blue, selected: catalog.category == item) {
                            catalog.category = item
                            Task { await catalog.search() }
                        }
                    }
                }
            }

            if let message = catalog.message {
                Text(message).foregroundStyle(AppTheme.textSecondary)
            }

            ForEach(catalog.recipes) { recipe in
                Button {
                    if let existing = store.recipes.first(where: { $0.catalogID == recipe.id && !recipe.id.isEmpty }) {
                        draft = .recipe(existing.id)
                    } else {
                        let saved = recipe.asHubRecipe()
                        store.addRecipe(saved)
                        draft = .recipe(saved.id)
                    }
                } label: {
                    plannerRow(
                        title: recipe.name,
                        detail: [recipe.category, recipe.area].filter { !$0.isEmpty }.joined(separator: " · "),
                        selected: {
                            if case .recipe(let id) = draft {
                                return store.recipe(id: id)?.catalogID == recipe.id
                            }
                            return false
                        }()
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var nearbyList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(PlaceMode.allCases) { mode in
                    FilterChip(title: mode.title, color: AppTheme.blue, selected: places.mode == mode) {
                        Task { await places.setMode(mode) }
                    }
                }
                if places.isLoading { ProgressView() }
            }
            if let message = places.message {
                Text(message).foregroundStyle(AppTheme.textSecondary)
            }
            ForEach(places.places) { place in
                Button {
                    draft = .place(
                        name: place.name,
                        address: place.address,
                        phone: place.phone,
                        url: place.url?.absoluteString ?? "",
                        kind: place.mode.rawValue
                    )
                } label: {
                    plannerRow(
                        title: place.name,
                        detail: [place.distanceLabel, place.address].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                        selected: {
                            if case .place(let name, _, _, _, _) = draft { return name == place.name }
                            return false
                        }()
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func plannerRow(title: String, detail: String, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(AppTheme.text)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.blue)
            }
        }
        .padding(14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? AppTheme.blue : Color.clear, lineWidth: 2)
        )
    }
}

private struct AddRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: RecipeKind = .recipe
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $kind) {
                    ForEach(RecipeKind.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                TextField("Notes", text: $notes)
            }
            .navigationTitle("Add meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addRecipe(.make(name: name.trimmingCharacters(in: .whitespaces), kind: kind, notes: notes))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct CatalogRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let recipe: CatalogRecipe
    let day: Date

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let url = recipe.thumb {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            AppTheme.blueSoft.frame(height: 220)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(recipe.name).font(.system(size: 28, weight: .semibold))
                        Text([recipe.category, recipe.area].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(AppTheme.textSecondary)
                        if !recipe.ingredients.isEmpty {
                            SectionLabel(title: "Ingredients")
                            ForEach(recipe.ingredients, id: \.self) { line in
                                Text("· \(line)").font(.body)
                            }
                        }
                        if !recipe.instructions.isEmpty {
                            SectionLabel(title: "Directions")
                            Text(recipe.instructions)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("Save to my recipes") {
                            store.addRecipe(recipe.asHubRecipe())
                            dismiss()
                        }
                        Button("Make this dinner") {
                            let item = recipe.asHubRecipe()
                            store.addRecipe(item)
                            store.setDinner(on: day, recipeID: item.id)
                            dismiss()
                        }
                    } label: {
                        Text("Use")
                    }
                }
            }
        }
    }
}

private struct SavedRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let day: Date

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.name).font(.system(size: 28, weight: .semibold))
                    Text(recipe.kind.label).foregroundStyle(AppTheme.textSecondary)
                    if !recipe.notes.isEmpty { Text(recipe.notes) }
                    if !recipe.ingredients.isEmpty {
                        SectionLabel(title: "Ingredients")
                        ForEach(recipe.ingredients, id: \.self) { line in
                            Text("· \(line)")
                        }
                    }
                    if !recipe.instructions.isEmpty {
                        SectionLabel(title: "Directions")
                        Text(recipe.instructions)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Make dinner") {
                        store.setDinner(on: day, recipeID: recipe.id)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PlaceDetailSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let place: NearbyPlace
    let day: Date

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: place.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Map(initialPosition: .region(region)) {
                        Marker(place.name, coordinate: place.coordinate)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 0))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(place.name).font(.system(size: 28, weight: .semibold))
                        Text(place.mode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                        if !place.address.isEmpty {
                            infoRow("mappin.and.ellipse", place.address)
                        }
                        if let distance = place.distanceLabel {
                            infoRow("location", distance)
                        }
                        if !place.phone.isEmpty {
                            infoRow("phone", place.phone)
                        }
                        if let url = place.url {
                            infoRow("safari", url.host ?? "Website")
                        }

                        HStack(spacing: 10) {
                            if !place.phone.isEmpty, let tel = URL(string: "tel:\(place.phone.filter { $0.isNumber || $0 == "+" })") {
                                pill("Call", "phone.fill") { openURL(tel) }
                            }
                            if let url = place.url {
                                pill(place.mode == .takeout ? "Menu / order" : "Menu & info", "menucard") { openURL(url) }
                            }
                            pill("Directions", "arrow.triangle.turn.up.right.diamond.fill") {
                                let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                                item.name = place.name
                                item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                            }
                        }

                        Button {
                            store.setDinnerPlace(
                                on: day,
                                name: place.name,
                                address: place.address,
                                phone: place.phone,
                                url: place.url?.absoluteString ?? "",
                                kind: place.mode.rawValue
                            )
                            dismiss()
                        } label: {
                            Text("Set as dinner")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 28)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func infoRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(AppTheme.blue).frame(width: 20)
            Text(text).font(.body)
        }
    }

    private func pill(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.card, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
