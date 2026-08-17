import SwiftUI

struct FamilyView: View {
    @EnvironmentObject private var store: HubStore
    @State private var household: String = ""
    @State private var showAdd = false
    @State private var editing: FamilyMember?
    @State private var payMember: FamilyMember?
    @State private var payAmount = ""
    @State private var payReason = "Allowance payout"
    @State private var draggingID: UUID?

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
                Text("Drag to rearrange")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Button("Add") { showAdd = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
            ForEach(store.members) { member in
                HubCard {
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(AppTheme.textTertiary)
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
                .onDrag {
                    draggingID = member.id
                    return NSItemProvider(object: member.id.uuidString as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: MemberReorderDelegate(
                        targetID: member.id,
                        draggingID: $draggingID,
                        onMove: { store.moveMember(id: $0, before: $1) }
                    )
                )
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
    @State private var colorHex = "2563EB"
    @State private var symbol = "🦊"

    private let colorColumns = [GridItem(.adaptive(minimum: 36), spacing: 10)]
    private let emojiColumns = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    nameAndRole
                    colorSection
                    emojiSection
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(member == nil ? "Add person" : "Edit person")
            .onAppear {
                if let member {
                    name = member.name
                    role = member.role
                    colorHex = member.colorHex
                    symbol = member.displayEmoji
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

    private var preview: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: colorHex))
                Text(symbol).font(.system(size: 34))
            }
            .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "New person" : name)
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                Text(role.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var nameAndRole: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $name)
                .font(.title3)
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Picker("Role", selection: $role) {
                ForEach(MemberRole.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Color")
            LazyVGrid(columns: colorColumns, spacing: 10) {
                ForEach(PersonStyle.colors, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if colorHex.caseInsensitiveCompare(hex) == .orderedSame {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color \(hex)")
                }
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var emojiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Icon")
            LazyVGrid(columns: emojiColumns, spacing: 8) {
                ForEach(PersonStyle.emojis, id: \.self) { emoji in
                    Button {
                        symbol = emoji
                    } label: {
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(symbol == emoji ? AppTheme.navySoft : Color.clear)
                            )
                            .overlay {
                                if symbol == emoji {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(AppTheme.navy, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(emoji)
                }
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
