import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportSocialRecipeView: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var loading = false
    @State private var error: String?
    @State private var draft: SocialRecipeDraft?
    @State private var name = ""
    @State private var ingredients = ""
    @State private var instructions = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Text("From a")
                            .foregroundStyle(AppTheme.text)
                        Text("Link")
                            .foregroundStyle(AppTheme.blue)
                    }
                    .font(.system(size: 36, weight: .bold))
                    Text("Paste a TikTok, YouTube, Instagram, Pinterest, or recipe-site link. HUB pulls the title, photo, and anything it can read. You check it, then save.")
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 10) {
                        TextField("https://www.tiktok.com/…", text: $link)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        Button("Paste") {
                            if let clip = UIPasteboard.general.string, clip.contains("http") {
                                link = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.blue)
                    }

                    Button(action: fetch) {
                        HStack {
                            if loading { ProgressView().tint(.white) }
                            Text(loading ? "Reading…" : "Pull recipe")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)

                    if let error {
                        Text(error).foregroundStyle(AppTheme.chore).font(.subheadline.weight(.semibold))
                    }

                    if let draft {
                        if !draft.imageURL.isEmpty, let url = URL(string: draft.imageURL) {
                            RecipePhoto(url: url, searchName: draft.name)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(AppTheme.blue, lineWidth: 3)
                                )
                        }
                        Text(draft.source.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.blue, in: Capsule())
                        field("Recipe name", text: $name, height: 1)
                        field("Ingredients (one per line)", text: $ingredients, height: 6)
                        field("Directions", text: $instructions, height: 8)
                        Button(action: save) {
                            Text("Save family recipe")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.blue)
                }
            }
        }
    }

    private func fetch() {
        error = nil
        loading = true
        Task {
            do {
                let pulled = try await SocialRecipeImport.ingest(link)
                await MainActor.run {
                    draft = pulled
                    name = pulled.name
                    ingredients = pulled.ingredients.joined(separator: "\n")
                    instructions = pulled.instructions
                    loading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    loading = false
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let draft else { return }
        let lines = ingredients
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        store.addRecipe(
            .make(
                name: trimmed,
                kind: .family,
                notes: "From \(draft.source)\n\(draft.sourceURL)",
                ingredients: lines,
                instructions: instructions,
                imageURL: draft.imageURL
            )
        )
        dismiss()
    }

    private func field(_ title: String, text: Binding<String>, height: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline.weight(.bold))
            if height == 1 {
                TextField(title, text: text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextEditor(text: text)
                    .frame(minHeight: CGFloat(height) * 22)
                    .padding(8)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.blue, lineWidth: 2)
                    )
            }
        }
    }
}
