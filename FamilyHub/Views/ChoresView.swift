import SwiftUI

struct ChoresView: View {
    @EnvironmentObject private var store: HubStore
    @State private var showAddChore = false
    @State private var assignChore: Chore?
    @State private var selectedKid: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HubPageTitle(lead: "Chore", tail: "Board")
                kidBalances
                kidFilter
                board
                catalog
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddChore = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddChore) { AddChoreSheet() }
        .sheet(item: $assignChore) { chore in
            AssignChoreSheet(chore: chore)
        }
    }

    private var kidBalances: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.kids()) { kid in
                    HubCard {
                        HStack(spacing: 12) {
                            MemberAvatar(member: kid, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kid.name).font(.headline)
                                MoneyText(cents: kid.allowanceBalanceCents)
                            }
                        }
                    }
                    .frame(minWidth: 180)
                }
            }
        }
    }

    private var kidFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All kids", color: AppTheme.forest, selected: selectedKid == nil) {
                    selectedKid = nil
                }
                ForEach(store.kids()) { kid in
                    FilterChip(
                        title: kid.name,
                        color: Color(hex: kid.colorHex),
                        selected: selectedKid == kid.id
                    ) {
                        selectedKid = kid.id
                    }
                }
            }
        }
    }

    private var board: some View {
            HubPanel(symbol: "checkmark.circle.fill", title: "Assigned") {
            let items = store.openAssignments(for: selectedKid)
            if items.isEmpty {
                HubCard {
                    EmptyHint(
                        symbol: "checkmark.circle",
                        title: "Board is clear",
                        detail: "Assign a chore from the catalog below."
                    )
                }
            } else {
                ForEach(items) { assignment in
                    if let chore = store.chore(id: assignment.choreID),
                       let kid = store.member(id: assignment.memberID) {
                        AssignmentCard(assignment: assignment, chore: chore, kid: kid)
                    }
                }
            }
        }
    }

    private var catalog: some View {
            HubPanel(symbol: "list.bullet", title: "Chore Catalog") {
            if store.chores.isEmpty {
                HubCard {
                    EmptyHint(
                        symbol: "list.bullet",
                        title: "No chores yet",
                        detail: "Add dishes, trash, lawn — whatever you pay for."
                    )
                }
            } else {
                ForEach(store.chores) { chore in
                    HubCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chore.title).font(.headline)
                                Text("\(chore.cadence.label) · \(Money.cents(chore.rewardCents))")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                if !chore.details.isEmpty {
                                    Text(chore.details)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                            }
                            Spacer()
                            Button("Assign") { assignChore = chore }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
            }
        }
    }
}

struct AssignmentCard: View {
    @EnvironmentObject private var store: HubStore
    let assignment: ChoreAssignment
    let chore: Chore
    let kid: FamilyMember

    var body: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    MemberAvatar(member: kid, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chore.title).font(.headline)
                        Text("\(kid.name) · due \(assignment.dueOn.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    MoneyText(cents: chore.rewardCents)
                }

                HStack(spacing: 8) {
                    Text(assignment.status.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.forestSoft, in: Capsule())
                        .foregroundStyle(AppTheme.forest)

                    Spacer()

                    switch assignment.status {
                    case .pending:
                        Button("Mark done") { store.completeAssignment(assignment.id) }
                            .buttonStyle(SecondaryButtonStyle())
                    case .done:
                        Button("Undo") { store.reopenAssignment(assignment.id) }
                            .buttonStyle(SecondaryButtonStyle())
                        Button("Approve \(Money.cents(chore.rewardCents))") {
                            store.approveAssignment(assignment.id)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    case .approved:
                        Button("Mark paid") { store.markAssignmentPaid(assignment.id) }
                            .buttonStyle(SecondaryButtonStyle())
                    case .paid:
                        EmptyView()
                    }
                }
            }
        }
    }
}

struct AddChoreSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    @State private var dollars = "2.00"
    @State private var cadence: ChoreCadence = .weekly

    var body: some View {
        HubSheetStack(
            lead: "New",
            tail: "Chore",
            confirm: "Add",
            confirmEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
            onCancel: { dismiss() },
            onConfirm: {
                store.addChore(.make(
                    title: title.trimmingCharacters(in: .whitespaces),
                    details: details,
                    rewardCents: centsFrom(dollars),
                    cadence: cadence
                ))
                dismiss()
            }
        ) {
            HubField(label: "Chore") {
                TextField("Chore name", text: $title)
            }
            HubField(label: "Details") {
                TextField("Details", text: $details)
            }
            HubField(label: "Reward") {
                TextField("Reward ($)", text: $dollars).keyboardType(.decimalPad)
            }
            HubField(label: "Repeat") {
                Picker("Repeat", selection: $cadence) {
                    ForEach(ChoreCadence.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private func centsFrom(_ raw: String) -> Int {
        let cleaned = raw.replacingOccurrences(of: "$", with: "")
        guard let value = Double(cleaned) else { return 0 }
        return Int((value * 100).rounded())
    }
}

struct AssignChoreSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let chore: Chore
    @State private var memberID: UUID?
    @State private var dueOn = Date()

    var body: some View {
        HubSheetStack(
            lead: "Assign",
            tail: "Chore",
            confirm: "Assign",
            confirmEnabled: memberID != nil,
            onCancel: { dismiss() },
            onConfirm: {
                if let memberID {
                    store.assign(choreID: chore.id, to: memberID, dueOn: dueOn)
                }
                dismiss()
            }
        ) {
            Text(chore.title)
                .font(.title2.weight(.bold))
            HubField(label: "Assign to") {
                Picker("Assign to", selection: $memberID) {
                    ForEach(store.kids()) { kid in
                        Text(kid.name).tag(Optional(kid.id))
                    }
                }
                .labelsHidden()
            }
            HubField(label: "Due") {
                DatePicker("Due", selection: $dueOn, displayedComponents: .date)
                    .labelsHidden()
            }
        }
        .onAppear { memberID = store.kids().first?.id }
    }
}
