import SwiftUI

struct ChoresView: View {
    @EnvironmentObject private var store: HubStore
    @State private var showAddChore = false
    @State private var assignChore: Chore?
    @State private var selectedKid: UUID?
    @State private var tourFocus = ""
    @State private var payMember: FamilyMember?
    @State private var payAmount = ""
    @State private var payReason = "Allowance payout"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HubStickyHeader(lead: "HUB", tail: "Chores") {
                HubHeaderPill(title: "Add chore") { showAddChore = true }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        peopleRow
                            .coachSpot("chorePay")
                        HStack(alignment: .top, spacing: 16) {
                            assignedPanel
                                .frame(maxWidth: .infinity)
                                .coachSpot("choreBoard")
                            catalogPanel
                                .frame(maxWidth: .infinity)
                                .coachSpot("choreCatalog")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .onChange(of: tourFocus) { _, id in
                    guard !id.isEmpty else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .hubTour("chores", steps: HubTours.chores) { id in
            tourFocus = id
        }
        .sheet(isPresented: $showAddChore) { AddChoreSheet() }
        .sheet(item: $assignChore) { chore in
            AssignChoreSheet(chore: chore)
        }
        .alert("Pay \(payMember?.name ?? "")", isPresented: Binding(
            get: { payMember != nil },
            set: { if !$0 { payMember = nil } }
        )) {
            TextField("Amount", text: $payAmount)
                .keyboardType(.decimalPad)
            TextField("Reason", text: $payReason)
            Button("Save") {
                if let member = payMember {
                    store.addManualAllowance(
                        memberID: member.id,
                        amountCents: centsFrom(payAmount),
                        reason: payReason.isEmpty ? "Paid out" : payReason
                    )
                }
                payMember = nil
                payAmount = ""
            }
            Button("Cancel", role: .cancel) { payMember = nil }
        } message: {
            Text("Use a minus to take money out.")
        }
    }

    private var kids: [FamilyMember] { store.kids() }

    private var totalCents: Int {
        kids.reduce(0) { $0 + $1.allowanceBalanceCents }
    }

    private var peopleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kids")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if kids.isEmpty {
                Text("Add a kid in Profiles to track chores and allowance.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        kidCard(
                            name: "Everyone",
                            cents: totalCents,
                            color: AppTheme.blue,
                            avatar: nil,
                            selected: selectedKid == nil,
                            openCount: store.openAssignments(for: nil).count,
                            onSelect: { selectedKid = nil },
                            onPay: nil
                        )
                        ForEach(kids) { kid in
                            kidCard(
                                name: kid.name,
                                cents: kid.allowanceBalanceCents,
                                color: Color(hex: kid.colorHex),
                                avatar: kid,
                                selected: selectedKid == kid.id,
                                openCount: store.openAssignments(for: kid.id).count,
                                onSelect: { selectedKid = kid.id },
                                onPay: {
                                    payMember = kid
                                    payAmount = ""
                                    payReason = "Paid out"
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }

    private func kidCard(
        name: String,
        cents: Int,
        color: Color,
        avatar: FamilyMember?,
        selected: Bool,
        openCount: Int,
        onSelect: @escaping () -> Void,
        onPay: (() -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    if let avatar {
                        MemberAvatar(member: avatar, size: 44)
                            .overlay(Circle().stroke(color, lineWidth: 3))
                    } else {
                        ZStack {
                            Circle().fill(AppTheme.blueSoft)
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(AppTheme.blue)
                        }
                        .frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                            .lineLimit(1)
                        Text(Money.cents(cents))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppTheme.blue)
                        Text(openCount == 0 ? "Clear" : "\(openCount) open")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(openCount == 0 ? AppTheme.todo : AppTheme.reminder)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let onPay {
                Button("Pay", action: onPay)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.blue, in: Capsule())
            }
        }
        .padding(14)
        .frame(width: 210, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? color : Color.black.opacity(0.05), lineWidth: selected ? 2.5 : 1)
        )
        .shadow(color: .black.opacity(selected ? 0.12 : 0.08), radius: selected ? 10 : 6, y: selected ? 5 : 3)
    }

    private var assignedPanel: some View {
        HubPanel(symbol: "checkmark.circle.fill", title: assignedTitle) {
            let items = store.openAssignments(for: selectedKid)
            if items.isEmpty {
                Text(selectedKid == nil ? "Nothing assigned yet." : "This kid is clear.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { assignment in
                        if let chore = store.chore(id: assignment.choreID),
                           let kid = store.member(id: assignment.memberID) {
                            AssignmentCard(assignment: assignment, chore: chore, kid: kid)
                        }
                    }
                }
            }
        }
    }

    private var assignedTitle: String {
        if let id = selectedKid, let kid = store.member(id: id) {
            return "\(kid.name)’s chores"
        }
        return "Assigned"
    }

    private var catalogPanel: some View {
        HubPanel(symbol: "list.bullet", title: "Jobs") {
            if store.chores.isEmpty {
                Text("Add a chore to hand out work.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(store.chores) { chore in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chore.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                    .lineLimit(1)
                                Text("\(chore.cadence.label) · \(Money.cents(chore.rewardCents))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.blue)
                            }
                            Spacer(minLength: 0)
                            Button("Assign") { assignChore = chore }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(AppTheme.blue, in: Capsule())
                        }
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    }
                }
            }
        }
    }

    private func centsFrom(_ raw: String) -> Int {
        let cleaned = raw.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned) else { return 0 }
        return Int((value * 100).rounded())
    }
}

struct AssignmentCard: View {
    @EnvironmentObject private var store: HubStore
    let assignment: ChoreAssignment
    let chore: Chore
    let kid: FamilyMember

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MemberAvatar(member: kid, size: 44)
                    .overlay(Circle().stroke(Color(hex: kid.colorHex), lineWidth: 3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(chore.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text("\(kid.name) · due \(assignment.dueOn.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Text(Money.cents(chore.rewardCents))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.blue)
            }
            HStack(spacing: 8) {
                Text(assignment.status.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.14), in: Capsule())
                Spacer()
                switch assignment.status {
                case .pending:
                    actionPill("Mark done") { store.completeAssignment(assignment.id) }
                case .done:
                    Button("Undo") { store.reopenAssignment(assignment.id) }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    actionPill("Approve \(Money.cents(chore.rewardCents))") {
                        store.approveAssignment(assignment.id)
                    }
                case .approved:
                    actionPill("Mark paid") { store.markAssignmentPaid(assignment.id) }
                case .paid:
                    EmptyView()
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    private var statusColor: Color {
        switch assignment.status {
        case .pending: return AppTheme.reminder
        case .done: return AppTheme.blue
        case .approved: return AppTheme.todo
        case .paid: return AppTheme.textSecondary
        }
    }

    private func actionPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.blue, in: Capsule())
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
