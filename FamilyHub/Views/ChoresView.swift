import PhotosUI
import SwiftUI
import UIKit

struct ChoresView: View {
    @EnvironmentObject private var store: HubStore
    @State private var showAddChore = false
    @State private var focusedKidID: UUID?
    @State private var tourFocus = ""
    @State private var payMember: FamilyMember?
    @State private var payAmount = ""
    @State private var payReason = "Allowance payout"
    @State private var sendBackID: UUID?
    @State private var sendBackReason = ""
    @State private var justFinished: UUID?

    private var mode: ChoreDesk.Mode {
        let person = store.signedInMember()
        return ChoreDesk.mode(role: person?.role, memberID: person?.id, focusedKidID: focusedKidID)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch mode {
                        case .kid(let id):
                            kidBoard(id, now: timeline.date)
                        case .parent:
                            parentBoard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .navigationTitle("Chores")
        .navigationBarTitleDisplayMode(.large)
        .hubTour("chores", steps: HubTours.chores) { id in
            tourFocus = id
        }
        .sheet(isPresented: $showAddChore) { AddChoreSheet() }
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
        .alert("Not yet", isPresented: Binding(
            get: { sendBackID != nil },
            set: { if !$0 { sendBackID = nil } }
        )) {
            TextField("Short reason (optional)", text: $sendBackReason)
            Button("Send back") {
                if let id = sendBackID {
                    store.sendBackAssignment(id, reason: sendBackReason)
                }
                sendBackID = nil
                sendBackReason = ""
            }
            Button("Cancel", role: .cancel) {
                sendBackID = nil
                sendBackReason = ""
            }
        } message: {
            Text("The chore goes back to the kid.")
        }
    }

    private var kids: [FamilyMember] { store.kids() }

    @ViewBuilder
    private func kidBoard(_ id: UUID, now: Date) -> some View {
        if store.signedInMember()?.role != .child {
            Button("All kids") { focusedKidID = nil }
                .font(.body.weight(.semibold))
                .foregroundStyle(noteInk)
        }
        if let kid = store.member(id: id) {
            Text(kid.name)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        let rows = ChoreDesk.kidCards(store.assignments.filter { $0.memberID == id }, now: now)
        if rows.isEmpty {
            Text("Nothing to do right now.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ForEach(rows) { assignment in
                if let chore = store.chore(id: assignment.choreID) {
                    KidChoreCard(
                        assignment: assignment,
                        chore: chore,
                        now: now,
                        justFinished: justFinished == assignment.id,
                        proofNote: store.latestProof(for: assignment.id)?.note,
                        onDone: { markDone(assignment.id) },
                        onUndo: { store.reopenAssignment(assignment.id) }
                    )
                }
            }
        }
    }

    private var parentBoard: some View {
        VStack(alignment: .leading, spacing: 20) {
            needsOK
                .coachSpot("choreBoard")
            whosDoing
            addChoreButton
                .coachSpot("choreCatalog")
            allowance
                .coachSpot("chorePay")
        }
    }

    private var needsOK: some View {
        let waiting = ChoreDesk.waiting(store.assignments)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Needs your OK (\(waiting.count))")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            if waiting.isEmpty {
                Text("All caught up.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(waiting) { assignment in
                    if let chore = store.chore(id: assignment.choreID),
                       let kid = store.member(id: assignment.memberID) {
                        needsRow(assignment: assignment, chore: chore, kid: kid)
                    }
                }
            }
        }
    }

    private func needsRow(assignment: ChoreAssignment, chore: Chore, kid: FamilyMember) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ChoreReview.title(kid: kid.name, chore: chore.title))
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            if let note = store.latestProof(for: assignment.id)?.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    approveButton(assignment.id)
                    notYetButton(assignment.id)
                }
                VStack(spacing: 8) {
                    approveButton(assignment.id)
                    notYetButton(assignment.id)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func approveButton(_ id: UUID) -> some View {
        Button("Approve") { store.approveAssignment(id) }
            .font(.headline.weight(.bold))
            .foregroundStyle(Color(hex: ChoreDesk.actionInk))
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color(hex: ChoreDesk.actionFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(.plain)
    }

    private func notYetButton(_ id: UUID) -> some View {
        Button("Not yet") {
            sendBackReason = ""
            sendBackID = id
        }
        .font(.headline.weight(.bold))
        .foregroundStyle(noteInk)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(noteInk, lineWidth: 1.5)
        )
        .buttonStyle(.plain)
    }

    private var whosDoing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who's doing chores?")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            if kids.isEmpty {
                Text("Add a kid in Profiles to hand out chores.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88, maximum: 140), spacing: 12)], alignment: .leading, spacing: 12) {
                    ForEach(kids) { kid in
                        Button {
                            focusedKidID = kid.id
                        } label: {
                            VStack(spacing: 6) {
                                MemberAvatar(member: kid, size: 64)
                                Text(kid.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(kid.name), show chores")
                    }
                }
                ForEach(kids) { kid in
                    kidList(kid)
                }
            }
        }
    }

    private func kidList(_ kid: FamilyMember) -> some View {
        let rows = store.assignments.filter { $0.memberID == kid.id && $0.status != .paid }
        return VStack(alignment: .leading, spacing: 8) {
            Text(kid.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if rows.isEmpty {
                Text("No chores yet.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(rows) { assignment in
                    if let chore = store.chore(id: assignment.choreID) {
                        HStack(alignment: .top, spacing: 8) {
                            choreIcon(chore.icon, size: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chore.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(assignment.status == .done ? "Waiting for grown-up" : assignment.status.kidLabel)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private var addChoreButton: some View {
        Button {
            showAddChore = true
        } label: {
            Text("Add chore")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(hex: ChoreDesk.actionInk))
                .frame(maxWidth: .infinity, minHeight: ChoreDesk.doneButtonMinHeight)
        }
        .buttonStyle(.plain)
        .background(Color(hex: ChoreDesk.actionFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHint("Name, icon, kid, and an optional reward")
    }

    private var allowance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allowance")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.text)
            if kids.isEmpty {
                Text("Allowance shows up here after you add a kid.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(kids) { kid in
                    allowanceRow(kid)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    private func allowanceRow(_ kid: FamilyMember) -> some View {
        let streak = CircleXP.streak(memberID: kid.id, assignments: store.assignments)
        let xp = CircleXP.total(memberID: kid.id, assignments: store.assignments, chores: store.chores)
        return VStack(alignment: .leading, spacing: 8) {
            Text(kid.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.text)
            Text("\(Money.cents(kid.allowanceBalanceCents)) · Lv \(CircleXP.level(xp: xp)) · \(streak) day streak")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Pay") {
                payMember = kid
                payAmount = ""
                payReason = "Paid out"
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(noteInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func markDone(_ id: UUID) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        justFinished = id
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            store.completeAssignment(id)
        }
    }

    private var noteInk: Color {
        AppTheme.adaptive(light: ChoreDesk.noteInkLight, dark: ChoreDesk.noteInkDark)
    }

    private func centsFrom(_ raw: String) -> Int {
        let cleaned = raw.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned) else { return 0 }
        return Int((value * 100).rounded())
    }

    @ViewBuilder
    private func choreIcon(_ icon: String, size: CGFloat) -> some View {
        if ChoreDesk.symbolIcon(icon) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundStyle(noteInk)
                .frame(width: size + 8, height: size + 8)
        } else {
            Text(icon)
                .font(.system(size: size))
        }
    }
}

struct KidChoreCard: View {
    @EnvironmentObject private var store: HubStore
    let assignment: ChoreAssignment
    let chore: Chore
    let now: Date
    let justFinished: Bool
    let proofNote: String?
    var onDone: () -> Void
    var onUndo: () -> Void
    @State private var showProof = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                icon
                Text(chore.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if assignment.status == .pending, let reason = assignment.returnReason, !reason.isEmpty {
                Text("Not yet. \(reason)")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let proofNote, !proofNote.isEmpty {
                Text(proofNote)
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch assignment.status {
            case .pending:
                Button(action: onDone) {
                    Label("Done", systemImage: "checkmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color(hex: ChoreDesk.actionInk))
                        .frame(maxWidth: .infinity, minHeight: ChoreDesk.doneButtonMinHeight)
                        .background(Color(hex: ChoreDesk.actionFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done, \(chore.title)")
                Button("Add a note") { showProof = true }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(noteInk)
                    .accessibilityHint("Optional note or photo")
            case .done:
                waiting
            case .approved, .paid:
                greatJob
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showProof) {
            ChoreProofSheet(assignmentID: assignment.id)
        }
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .symbolEffect(.bounce, value: justFinished)
                Text("Waiting for grown-up")
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AppTheme.text)
            if ChoreReview.offersUndo(status: assignment.status, completedAt: assignment.completedAt, now: now) {
                Button("Undo", action: onUndo)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(noteInk)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, minHeight: ChoreDesk.doneButtonMinHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var greatJob: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "star.fill")
                .font(.title2)
            Text("Great job!")
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppTheme.celebrateInk)
        .frame(maxWidth: .infinity, minHeight: ChoreDesk.doneButtonMinHeight, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.celebrateFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var cardFill: Color {
        switch assignment.status {
        case .done: return AppTheme.blueSoft
        case .approved, .paid: return AppTheme.card
        case .pending: return AppTheme.card
        }
    }

    private var noteInk: Color {
        AppTheme.adaptive(light: ChoreDesk.noteInkLight, dark: ChoreDesk.noteInkDark)
    }

    @ViewBuilder
    private var icon: some View {
        if ChoreDesk.symbolIcon(chore.icon) {
            Image(systemName: chore.icon)
                .font(.largeTitle)
                .foregroundStyle(noteInk)
                .frame(minWidth: 56, minHeight: 56)
                .accessibilityHidden(true)
        } else {
            Text(chore.icon)
                .font(.largeTitle)
                .frame(minWidth: 56, minHeight: 56)
                .accessibilityHidden(true)
        }
    }
}

struct ChoreProofSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    let assignmentID: UUID
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var jpeg: Data?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add a note")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                TextField("What did you do?", text: $note, axis: .vertical)
                    .font(.body)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(jpeg == nil ? "Add a photo" : "Photo ready", systemImage: "camera")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.adaptive(light: ChoreDesk.noteInkLight, dark: ChoreDesk.noteInkDark))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addChoreProof(assignmentID: assignmentID, note: note, photoJPEG: jpeg)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        jpeg = ChoreProofSheet.jpeg(from: data)
                    }
                }
            }
        }
    }

    static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 1 else { return image.jpegData(compressionQuality: 0.6) }
        let maxSide: CGFloat = 800
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.6)
    }
}

struct AddChoreSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var icon = "sparkles"
    @State private var memberID: UUID?
    @State private var dollars = ""
    @State private var cadence: ChoreCadence = .weekly

    private let symbols = ["sparkles", "fork.knife", "trash.fill", "bed.double.fill", "tshirt.fill", "pawprint.fill", "book.fill", "drop.fill"]
    private let emoji = ["🧹", "🍽️", "🛏️", "🐕", "📚", "🗑️"]

    var body: some View {
        HubSheetStack(
            lead: "New",
            tail: "Chore",
            confirm: "Add",
            confirmEnabled: canSave,
            onCancel: { dismiss() },
            onConfirm: save
        ) {
            HubField(label: "Chore") {
                TextField("Chore name", text: $title)
            }
            HubField(label: "Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(symbols, id: \.self) { symbol in
                        iconButton(symbol)
                    }
                    ForEach(emoji, id: \.self) { item in
                        iconButton(item)
                    }
                }
            }
            HubField(label: "Assign to") {
                if store.kids().isEmpty {
                    Text("Add a kid in Profiles, then assign this chore.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Picker("Assign to", selection: $memberID) {
                        ForEach(store.kids()) { kid in
                            Text(kid.name).tag(Optional(kid.id))
                        }
                    }
                    .labelsHidden()
                }
            }
            HubField(label: "Repeat") {
                Picker("Repeat", selection: $cadence) {
                    ForEach(ChoreCadence.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .labelsHidden()
            }
            HubField(label: "Reward (optional)") {
                TextField("0.00", text: $dollars)
                    .keyboardType(.decimalPad)
            }
        }
        .onAppear { memberID = store.kids().first?.id }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && (store.kids().isEmpty || memberID != nil)
    }

    private func save() {
        let chore = Chore.make(
            title: title.trimmingCharacters(in: .whitespaces),
            rewardCents: centsFrom(dollars),
            cadence: cadence,
            icon: icon
        )
        store.addChore(chore)
        if let memberID {
            store.assign(choreID: chore.id, to: memberID, dueOn: Date())
        }
        dismiss()
    }

    private func iconButton(_ value: String) -> some View {
        Button {
            icon = value
        } label: {
            Group {
                if ChoreDesk.symbolIcon(value) {
                    Image(systemName: value)
                        .font(.title3)
                        .foregroundStyle(AppTheme.text)
                } else {
                    Text(value).font(.title3)
                }
            }
            .frame(width: 52, height: 52)
            .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(icon == value ? Color(hex: ChoreDesk.actionFill) : AppTheme.cardBorder, lineWidth: icon == value ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value)
        .accessibilityAddTraits(icon == value ? .isSelected : AccessibilityTraits())
    }

    private func centsFrom(_ raw: String) -> Int {
        let cleaned = raw.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let value = Double(cleaned) else { return 0 }
        return Int((value * 100).rounded())
    }
}
