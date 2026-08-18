import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var store: HubStore
    @State private var showAdd = false
    @State private var pickDay: Date?

    private var week: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionLabel(title: "This week")
                ForEach(week, id: \.self) { day in
                    dinnerRow(day)
                }

                HStack {
                    SectionLabel(title: "Recipes and cooked items")
                    Spacer()
                    Button {
                        showAdd = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.top, 8)

                if store.recipes.isEmpty {
                    HubCard {
                        EmptyHint(
                            symbol: "fork.knife",
                            title: "No meals yet",
                            detail: "Add a recipe or something already cooked, then assign it to a night."
                        )
                    }
                } else {
                    ForEach(store.recipes) { recipe in
                        HubCard {
                            HStack {
                                Image(systemName: recipe.kind == .cooked ? "takeoutbag.and.cup.and.straw" : "book")
                                    .foregroundStyle(AppTheme.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.name).font(.headline)
                                    Text(recipe.kind.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    if !recipe.notes.isEmpty {
                                        Text(recipe.notes)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textTertiary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Meals")
        .sheet(isPresented: $showAdd) {
            AddRecipeSheet()
        }
        .sheet(item: pickDayBinding) { day in
            DinnerPickerSheet(day: day.date)
        }
    }

    private func dinnerRow(_ day: Date) -> some View {
        Button {
            pickDay = day
        } label: {
            HubCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayLabel(day))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textTertiary)
                        Text(store.dinnerTitle(on: day) ?? "Nothing planned")
                            .font(.headline)
                            .foregroundStyle(store.dinnerTitle(on: day) == nil ? AppTheme.textSecondary : AppTheme.text)
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

struct DinnerPickerSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let day: Date

    var body: some View {
        NavigationStack {
            List {
                Button("Nothing planned") {
                    store.clearDinner(on: day)
                    dismiss()
                }
                Section("Recipes") {
                    ForEach(store.recipes.filter { $0.kind == .recipe }) { recipe in
                        Button(recipe.name) {
                            store.setDinner(on: day, recipeID: recipe.id)
                            dismiss()
                        }
                    }
                }
                Section("Already made") {
                    ForEach(store.recipes.filter { $0.kind == .cooked }) { recipe in
                        Button(recipe.name) {
                            store.setDinner(on: day, recipeID: recipe.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Dinner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
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
