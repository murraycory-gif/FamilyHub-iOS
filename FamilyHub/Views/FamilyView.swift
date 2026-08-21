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
    @State private var profileMember: FamilyMember?

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
        .sheet(item: $profileMember) { member in
            MemberProfileView(memberID: member.id, onEdit: {
                profileMember = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    editing = store.member(id: member.id)
                }
            })
            .environmentObject(store)
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
        HStack(spacing: 18) {
            ZStack {
                if let data = store.familyPhotoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle().fill(AppTheme.blueSoft)
                    Image(systemName: "person.3.fill")
                        .font(.title)
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.blue, lineWidth: 4))
            .shadow(color: AppTheme.blue.opacity(0.2), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "Household")
                TextField("Family name", text: $household)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .onSubmit { store.setHouseholdName(household) }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.blue, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    private var members: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                ForEach(store.members) { member in
                    FamilyMemberRow(
                        member: member,
                        onOpen: { profileMember = member },
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
                    VStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(width: 108, height: 108)
                            .overlay(Circle().stroke(AppTheme.blue.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
                        Text("Add someone")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.text)
                        Text("Parent, kid, or pet")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(20)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(AppTheme.blue.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "Allowance")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)], spacing: 14) {
                ForEach(store.kids()) { kid in
                    HStack(spacing: 14) {
                        MemberAvatar(member: kid, size: 64)
                            .overlay(Circle().stroke(Color(hex: kid.colorHex), lineWidth: 3))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kid.name)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Text("Balance")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                            Text(Money.cents(kid.allowanceBalanceCents))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.blue)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color(hex: kid.colorHex), lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
                }
            }

            Text("Activity")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                ForEach(Array(store.ledger.prefix(20))) { entry in
                    AllowanceActivityCard(entry: entry)
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

private struct AllowanceActivityCard: View {
    @EnvironmentObject private var store: HubStore
    let entry: LedgerEntry

    var body: some View {
        let person = store.member(id: entry.memberID)
        let accent = Color(hex: person?.colorHex ?? "2563EB")
        return HStack(spacing: 14) {
            if let person {
                MemberAvatar(member: person, size: 56)
                    .overlay(Circle().stroke(accent, lineWidth: 3))
            } else {
                Circle().fill(AppTheme.blueSoft).frame(width: 56, height: 56)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.reason)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .lineLimit(2)
                Text(person?.name ?? "Family")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 8)
            Text(Money.cents(entry.amountCents))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(entry.amountCents < 0 ? AppTheme.chore : AppTheme.blue)
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }
}

private struct FamilyMemberRow: View {
    @EnvironmentObject private var store: HubStore
    let member: FamilyMember
    var onOpen: () -> Void
    var onPay: () -> Void
    private var accent: Color { Color(hex: member.colorHex) }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    MemberAvatar(member: member, size: 108)
                        .overlay(Circle().stroke(accent, lineWidth: 4))
                        .shadow(color: accent.opacity(0.25), radius: 10, y: 4)
                    Image(systemName: "line.3.horizontal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .padding(6)
                        .background(AppTheme.blueSoft, in: Circle())
                        .offset(x: 8, y: -4)
                        .accessibilityLabel("Hold to reorder")
                }
                VStack(spacing: 6) {
                    Text(member.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                HStack(spacing: 8) {
                    Text("Profile")
                        .font(.headline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.blue, in: Capsule())
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 280)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(accent, lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if member.role == .child {
                Button("Pay", action: onPay)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppTheme.blue, in: Capsule())
                    .padding(12)
            }
        }
    }
}

struct MemberProfileView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let memberID: UUID
    var onEdit: () -> Void
    @State private var showStudio = false

    private var member: FamilyMember? { store.member(id: memberID) }
    private var accent: Color { Color(hex: member?.colorHex ?? "2563EB") }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let member {
                    VStack(alignment: .leading, spacing: 18) {
                        banner(member)
                        stats(member)
                        today(member)
                        Button(action: onEdit) {
                            Label("Edit profile", systemImage: "pencil")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                }
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(AppTheme.blue)
                }
                ToolbarItem(placement: .principal) {
                    Text(member?.name ?? "Profile")
                        .font(.headline.weight(.bold))
                }
            }
            .sheet(isPresented: $showStudio) {
                BannerStudio(
                    title: member?.name.split(separator: " ").first.map(String.init) ?? "Banner",
                    current: member.flatMap { store.photo(for: $0) }
                ) { data in
                    store.setMemberPhoto(memberID, data: data)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func banner(_ member: FamilyMember) -> some View {
        HStack(spacing: 18) {
            Button { showStudio = true } label: {
                MemberAvatar(member: member, size: 108)
                    .overlay(Circle().stroke(accent, lineWidth: 4))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(AppTheme.blue, in: Circle())
                    }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 8) {
                Text(member.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Text(member.role.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.blueSoft, in: Capsule())
                Text("Tap photo to change banner")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer()
        }
        .padding(20)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    private func stats(_ member: FamilyMember) -> some View {
        HStack(spacing: 10) {
            stat("\(store.openAssignments(for: member.id).count)", "Chores", AppTheme.chore)
            stat("\(store.openReminders(for: member.id).count)", "Reminders", AppTheme.reminder)
            stat("\(store.openTodos(for: member.id).count)", "To-dos", AppTheme.todo)
        }
    }

    private func stat(_ value: String, _ title: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.text)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func today(_ member: FamilyMember) -> some View {
        let events = store.events(on: Date(), filter: .member(member.id))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Today")
                .font(.title3.weight(.bold))
            if events.isEmpty {
                Text("Free this day")
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { event in
                        HStack(spacing: 10) {
                            Text(event.allDay ? "All day" : event.startAt.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(AppTheme.blue)
                                .frame(width: 72, alignment: .leading)
                            Text(event.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
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
