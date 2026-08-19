import PhotosUI
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
            VStack(alignment: .leading, spacing: 20) {
                householdCard
                members
                if !store.ledger.isEmpty {
                    ledger
                }
            }
            .padding(20)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .navigationTitle("")
        .onAppear { household = store.householdName }
        .onDisappear { store.setHouseholdName(household) }
        .sheet(isPresented: $showAdd) { EditMemberSheet(member: nil) }
        .sheet(item: $editing) { member in
            EditMemberSheet(member: member)
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

    private var householdCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "Household")
            TextField("Family name", text: $household)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .onSubmit { store.setHouseholdName(household) }
        }
        .padding(.bottom, 4)
    }

    private var members: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                SectionLabel(title: "Family")
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ForEach(store.members) { member in
                FamilyMemberRow(
                    member: member,
                    onEdit: { editing = member },
                    onPay: {
                        payMember = member
                        payAmount = ""
                        payReason = "Paid out"
                    }
                )
                .onDrag {
                    draggingID = member.id
                    return NSItemProvider(object: member.id.uuidString as NSString)
                }
                .onDrop(
                    of: [.text],
                    delegate: MemberReorderDelegate(
                        targetID: member.id,
                        draggingID: $draggingID,
                        onMove: { store.moveMemberLive(id: $0, before: $1) },
                        onFinished: { store.persistMembers() }
                    )
                )
            }

            Button {
                showAdd = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.blue)
                    Text("Add someone")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AppTheme.blue.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Allowance")
            ForEach(store.ledger.prefix(20)) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.reason)
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text(store.member(id: entry.memberID)?.name ?? "Family")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        MoneyText(cents: entry.amountCents)
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                .padding(16)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
            }
        }
    }

    private func centsFrom(_ raw: String) -> Int {
        let cleaned = raw.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned) else { return 0 }
        return Int((value * 100).rounded())
    }
}

private struct FamilyMemberRow: View {
    let member: FamilyMember
    var onEdit: () -> Void
    var onPay: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Color(hex: member.colorHex)
                .frame(width: 6)
            Button(action: onEdit) {
                HStack(spacing: 16) {
                    MemberAvatar(member: member, size: 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        HStack(spacing: 8) {
                            Text(member.role.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.blueSoft, in: Capsule())
                            if member.role == .child {
                                Text(Money.cents(member.allowanceBalanceCents))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if member.role == .child {
                Button("Pay", action: onPay)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(AppTheme.blue, in: Capsule())
                    .padding(.trailing, 8)
            }

            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .padding(.trailing, 16)
                .accessibilityLabel("Hold to reorder")
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}

struct EditMemberSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let member: FamilyMember?

    @State private var name = ""
    @State private var role: MemberRole = .child
    @State private var colorHex = "2563EB"
    @State private var symbol = "🌟"
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var cropPayload: PhotoCropPayload?

    private let colorColumns = [GridItem(.adaptive(minimum: 36), spacing: 10)]
    private let emojiColumns = [GridItem(.adaptive(minimum: 44), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    nameAndRole
                    photoSection
                    colorSection
                    emojiSection
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle(member == nil ? "Add family" : "Edit family")
            .onAppear {
                if let member {
                    name = member.name
                    role = member.role
                    colorHex = member.colorHex
                    symbol = member.displayEmoji
                    photoData = store.photo(for: member)
                } else {
                    symbol = role.defaultEmoji
                }
            }
            .onChange(of: role) { _, newRole in
                if PersonStyle.emojis.contains(symbol) == false || MemberRole.allCases.contains(where: { $0.defaultEmoji == symbol }) {
                    symbol = newRole.defaultEmoji
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        cropPayload = PhotoCropPayload(image: image)
                    }
                }
            }
            .fullScreenCover(item: $cropPayload) { payload in
                PhotoCropper(
                    image: payload.image,
                    onCancel: { cropPayload = nil },
                    onCrop: { data in
                        photoData = data
                        cropPayload = nil
                    }
                )
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
                            store.setMemberPhoto(existing.id, data: photoData)
                        } else {
                            let created = FamilyMember.make(name: trimmed, role: role, colorHex: colorHex, symbol: symbol)
                            store.addMember(created)
                            store.setMemberPhoto(created.id, data: photoData)
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
            avatarPreview
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "New family member" : name)
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

    private var avatarPreview: some View {
        Button {
            if let photoData, let image = UIImage(data: photoData) {
                cropPayload = PhotoCropPayload(image: image)
            }
        } label: {
            ZStack {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle().fill(Color(hex: colorHex))
                    Text(symbol).font(.system(size: 34))
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(photoData == nil)
    }

    private var nameAndRole: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $name)
                .font(.title3)
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(MemberRole.allCases) { item in
                    FilterChip(title: item.label, color: AppTheme.blue, selected: role == item) {
                        role = item
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Photo")
            HStack(spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photoData == nil ? "Add photo" : "Change photo", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppTheme.blueSoft, in: Capsule())
                        .foregroundStyle(AppTheme.blue)
                }
                .buttonStyle(.plain)
                if photoData != nil {
                    Button("Adjust") {
                        if let photoData, let image = UIImage(data: photoData) {
                            cropPayload = PhotoCropPayload(image: image)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    Button("Use icon") {
                        photoData = nil
                        photoItem = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
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
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title: "Icon")
            ForEach(PersonStyle.groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    LazyVGrid(columns: emojiColumns, spacing: 8) {
                        ForEach(group.emojis, id: \.self) { emoji in
                            Button {
                                symbol = emoji
                                photoData = nil
                                photoItem = nil
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 26))
                                    .frame(width: 44, height: 44)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(symbol == emoji && photoData == nil ? AppTheme.navySoft : Color.clear)
                                    )
                                    .overlay {
                                        if symbol == emoji && photoData == nil {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(AppTheme.navy, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(emoji)
                        }
                    }
                }
            }
            .padding(14)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
