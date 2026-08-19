import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var store: HubStore
    @State private var draft = ""
    @FocusState private var adding: Bool

    private var openItems: [ShoppingItem] { store.shoppingItems.filter { !$0.isChecked } }
    private var checkedItems: [ShoppingItem] { store.shoppingItems.filter(\.isChecked) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
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