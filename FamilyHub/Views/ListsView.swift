import SwiftUI

enum ListKind: String, CaseIterable, Identifiable {
    case reminders, todos
    var id: String { rawValue }
    var title: String { self == .reminders ? "Reminders" : "To-dos" }
}

struct ListsView: View {
    @EnvironmentObject private var store: HubStore
    @EnvironmentObject private var router: HubRouter
    @State private var kind: ListKind = .reminders
    @State private var showAdd = false
    @State private var memberFilter: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubPageTitle(lead: kind == .reminders ? "Family" : "Family", tail: kind == .reminders ? "Reminders" : "To-dos")
                .padding(.horizontal, 20)
                .padding(.top, 8)
            Picker("List", selection: $kind) {
                ForEach(ListKind.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Everyone", color: AppTheme.forest, selected: memberFilter == nil) {
                        memberFilter = nil
                    }
                    ForEach(store.members) { member in
                        FilterChip(
                            title: member.name,
                            color: Color(hex: member.colorHex),
                            selected: memberFilter == member.id
                        ) {
                            memberFilter = member.id
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if kind == .reminders {
                        reminderList
                    } else {
                        todoList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddListItemSheet(kind: kind, defaultMember: memberFilter)
        }
        .onAppear { kind = router.listKind }
        .onChange(of: router.listKind) { _, next in
            kind = next
        }
    }

    @ViewBuilder
    private var reminderList: some View {
        let items = store.reminders.filter { memberFilter == nil || $0.memberID == memberFilter }
        if items.isEmpty {
            HubCard {
                EmptyHint(symbol: "bell", title: "No reminders", detail: "Add permission slips, trash night, fees.")
            }
        } else {
            ForEach(items) { item in
                HubCard {
                    HStack(alignment: .top, spacing: 12) {
                        Button { store.toggleReminder(item.id) } label: {
                            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(AppTheme.forest)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .strikethrough(item.isCompleted)
                                .foregroundStyle(item.isCompleted ? AppTheme.textTertiary : AppTheme.text)
                            if let due = item.dueAt {
                                Text(due.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                        MemberDot(member: item.memberID.flatMap(store.member(id:)))
                        Button { store.deleteReminder(item.id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var todoList: some View {
        let items = store.todos.filter { memberFilter == nil || $0.memberID == memberFilter }
        if items.isEmpty {
            HubCard {
                EmptyHint(symbol: "checkmark.square", title: "No to-dos", detail: "Groceries, oil change, pack the gym bag.")
            }
        } else {
            ForEach(items) { item in
                HubCard {
                    HStack(alignment: .top, spacing: 12) {
                        Button { store.toggleTodo(item.id) } label: {
                            Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                .font(.title3)
                                .foregroundStyle(AppTheme.forest)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .strikethrough(item.isCompleted)
                                .foregroundStyle(item.isCompleted ? AppTheme.textTertiary : AppTheme.text)
                            if !item.notes.isEmpty {
                                Text(item.notes)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            if let due = item.dueAt {
                                Text(due.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                        MemberDot(member: item.memberID.flatMap(store.member(id:)))
                        Button { store.deleteTodo(item.id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.textTertiary)
                    }
                }
            }
        }
    }
}

struct AddListItemSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let kind: ListKind
    let defaultMember: UUID?

    @State private var title = ""
    @State private var notes = ""
    @State private var hasDue = true
    @State private var dueAt = Date()
    @State private var memberID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                if kind == .todos {
                    TextField("Notes", text: $notes)
                }
                Toggle("Has due date", isOn: $hasDue)
                if hasDue {
                    DatePicker("Due", selection: $dueAt)
                }
                Picker("Who", selection: $memberID) {
                    Text("Whole family").tag(UUID?.none)
                    ForEach(store.members) { member in
                        Text(member.name).tag(Optional(member.id))
                    }
                }
            }
            .navigationTitle(kind == .reminders ? "New reminder" : "New to-do")
            .onAppear { memberID = defaultMember }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if kind == .reminders {
                            store.addReminder(.make(
                                title: title.trimmingCharacters(in: .whitespaces),
                                dueAt: hasDue ? dueAt : nil,
                                memberID: memberID
                            ))
                        } else {
                            store.addTodo(.make(
                                title: title.trimmingCharacters(in: .whitespaces),
                                notes: notes,
                                dueAt: hasDue ? dueAt : nil,
                                memberID: memberID
                            ))
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct ShoppingListView: View {
    @EnvironmentObject private var store: HubStore
    @State private var draft = ""
    @FocusState private var adding: Bool

    private var openItems: [ShoppingItem] { store.shoppingItems.filter { !$0.isChecked } }
    private var checkedItems: [ShoppingItem] { store.shoppingItems.filter { $0.isChecked } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HubPageTitle(lead: "Shopping", tail: "List")
                addRow
                if openItems.isEmpty && checkedItems.isEmpty {
                    HubCard {
                        EmptyHint(
                            symbol: "cart",
                            title: "List is empty",
                            detail: "Add milk, snacks, whatever the house needs."
                        )
                    }
                }
                if !openItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "To get")
                        ForEach(openItems) { item in
                            itemRow(item)
                        }
                    }
                }
                if !checkedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SectionLabel(title: "In the cart")
                            Spacer()
                            Button("Clear") { store.clearCheckedShopping() }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                        }
                        ForEach(checkedItems) { item in
                            itemRow(item)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HubIconButton(symbol: "plus", label: "Add") { adding = true }
            }
        }
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppTheme.blue)
            TextField("Add an item", text: $draft)
                .font(.title3)
                .focused($adding)
                .onSubmit { submit() }
            if !draft.isEmpty {
                Button("Add") { submit() }
                    .font(.headline)
                    .foregroundStyle(AppTheme.blue)
            }
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        Button {
            store.toggleShoppingItem(item.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isChecked ? AppTheme.todo : AppTheme.blue)
                Text(item.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(item.isChecked ? AppTheme.textTertiary : AppTheme.text)
                    .strikethrough(item.isChecked)
                Spacer()
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.blue, lineWidth: 3)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove", role: .destructive) { store.deleteShoppingItem(item.id) }
        }
    }

    private func submit() {
        store.addShoppingItem(draft)
        draft = ""
        adding = true
    }
}
