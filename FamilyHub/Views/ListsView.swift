import SwiftUI

enum ListKind: String, CaseIterable, Identifiable {
    case reminders, todos
    var id: String { rawValue }
    var title: String { self == .reminders ? "Reminders" : "To-dos" }
}

struct ListsView: View {
    @EnvironmentObject private var store: HubStore
    @State private var kind: ListKind = .reminders
    @State private var showAdd = false
    @State private var memberFilter: UUID?

    var body: some View {
        VStack(spacing: 0) {
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
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddListItemSheet(kind: kind, defaultMember: memberFilter)
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
