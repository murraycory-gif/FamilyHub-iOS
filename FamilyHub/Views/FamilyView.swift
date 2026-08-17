import SwiftUI

struct FamilyView: View {
    @EnvironmentObject private var store: HubStore
    @State private var household: String = ""
    @State private var showAdd = false
    @State private var editing: FamilyMember?
    @State private var payMember: FamilyMember?
    @State private var payAmount = ""
    @State private var payReason = "Allowance payout"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                householdCard
                members
                ledger
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("Family")
        .onAppear { household = store.householdName }
        .sheet(isPresented: $showAdd) { EditMemberSheet(member: nil) }
        .sheet(item: $editing) { member in
            EditMemberSheet(member: member)
        }
        .alert("Pay / adjust", isPresented: Binding(
            get: { payMember != nil },
            set: { if !$0 { payMember = nil } }
        )) {
            TextField("Amount (e.g. 5 or -2)", text: $payAmount)
                .keyboardType(.decimalPad)
            TextField("Reason", text: $payReason)
            Button("Save") {
                if let member = payMember {
                    store.addManualAllowance(
                        memberID: member.id,
                        amountCents: centsFrom(payAmount),
                        reason: payReason.isEmpty ? "Adjustment" : payReason
                    )
                }
                payMember = nil
                payAmount = ""
            }
            Button("Cancel", role: .cancel) { payMember = nil }
        } message: {
            Text("Positive amounts add to the balance. Negative subtracts.")
        }
    }

    private var householdCard: some View {
        HubCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(title: "Household")
                TextField("Household name", text: $household)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .onSubmit { store.setHouseholdName(household) }
                Button("Save name") { store.setHouseholdName(household) }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var members: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(title: "People")
                Spacer()
                Button("Add") { showAdd = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            ForEach(store.members) { member in
                HubCard {
                    HStack(spacing: 12) {
                        MemberAvatar(member: member, size: 46)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(member.name).font(.headline)
                            Text(member.role.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            if member.role == .child {
                                MoneyText(cents: member.allowanceBalanceCents)
                            }
                        }
                        Spacer()
                        if member.role == .child {
                            Button("Pay") {
                                payMember = member
                                payAmount = ""
                                payReason = "Paid out"
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                        Button {
                            editing = member
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Allowance ledger")
            if store.ledger.isEmpty {
                HubCard {
                    EmptyHint(
                        symbol: "dollarsign.circle",
                        title: "No payments yet",
                        detail: "Approve a finished chore and it shows up here."
                    )
                }
            } else {
                ForEach(store.ledger.prefix(20)) { entry in
                    HubCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.reason).font(.headline)
                                Text(store.member(id: entry.memberID)?.name ?? "Family")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                MoneyText(cents: entry.amountCents)
                                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
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

struct EditMemberSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let member: FamilyMember?

    @State private var name = ""
    @State private var role: MemberRole = .child
    @State private var colorHex = "3D5A80"
    @State private var symbol = "figure.run"

    private let colors = ["2F4A3C", "3D5A80", "8C5A3C", "6B4C7A", "8B3A3A", "4A6B3C"]
    private let symbols = ["person.fill", "figure.run", "soccerball", "book.fill", "gamecontroller.fill", "leaf.fill"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Role", selection: $role) {
                    ForEach(MemberRole.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
                Section("Symbol") {
                    Picker("Symbol", selection: $symbol) {
                        ForEach(symbols, id: \.self) { item in
                            Label(item, systemImage: item).tag(item)
                        }
                    }
                }
            }
            .navigationTitle(member == nil ? "Add person" : "Edit person")
            .onAppear {
                if let member {
                    name = member.name
                    role = member.role
                    colorHex = member.colorHex
                    symbol = member.symbol
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if var existing = member {
                            existing.name = trimmed
                            existing.role = role
                            existing.colorHex = colorHex
                            existing.symbol = symbol
                            store.updateMember(existing)
                        } else {
                            store.addMember(.make(name: trimmed, role: role, colorHex: colorHex, symbol: symbol))
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
