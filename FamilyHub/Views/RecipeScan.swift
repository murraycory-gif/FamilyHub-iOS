import PhotosUI
import SwiftUI
import UIKit
import Vision

struct ScanRecipeSheet: View {
    @EnvironmentObject private var store: HubStore
    @Environment(\.dismiss) private var dismiss
    @State private var picker: PhotosPickerItem?
    @State private var showCamera = false
    @State private var photo: UIImage?
    @State private var isReading = false
    @State private var name = ""
    @State private var ingredients = ""
    @State private var instructions = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Text("Scan")
                            .foregroundStyle(AppTheme.text)
                        Text("Recipe")
                            .foregroundStyle(AppTheme.blue)
                    }
                    .font(.system(size: 36, weight: .bold))
                    Text("Photo a recipe card or cookbook page. Check the details, then save.")
                        .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: 12) {
                        Button { showCamera = true } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.blue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        PhotosPicker(selection: $picker, matching: .images) {
                            Label("Photos", systemImage: "photo.on.rectangle")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppTheme.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.blueSoft, in: Capsule())
                        }
                    }

                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(AppTheme.blue, lineWidth: 3)
                            )
                    }

                    if isReading {
                        ProgressView("Reading the recipe…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let message {
                        Text(message).foregroundStyle(AppTheme.textSecondary)
                    }

                    field("Recipe name", text: $name, height: 1)
                    field("Ingredients (one per line)", text: $ingredients, height: 6)
                    field("Directions", text: $instructions, height: 8)

                    Button(action: save) {
                        Text("Save family recipe")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.textTertiary : AppTheme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundStyle(AppTheme.blue)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    Task { await ingest(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: picker) { _, item in
                Task { await loadPicker(item) }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, height: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextField(title, text: text, axis: .vertical)
                .lineLimit(height...max(height, 10))
                .padding(14)
                .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
        }
    }

    private func loadPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            message = "Could not open that photo."
            return
        }
        await ingest(image)
    }

    private func ingest(_ image: UIImage) async {
        photo = image
        isReading = true
        message = nil
        let text = await RecipeOCR.read(image)
        isReading = false
        let parsed = RecipeOCR.parse(text)
        if parsed.name.isEmpty && parsed.ingredients.isEmpty && parsed.instructions.isEmpty {
            message = "Couldn’t read that page. Try a closer, brighter photo."
            return
        }
        if name.isEmpty { name = parsed.name }
        if ingredients.isEmpty { ingredients = parsed.ingredients.joined(separator: "\n") }
        if instructions.isEmpty { instructions = parsed.instructions }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        var imageURL = ""
        if let photo, let url = RecipeOCR.saveImage(photo) {
            imageURL = url.absoluteString
        }
        store.addRecipe(.make(
            name: trimmed,
            kind: .family,
            ingredients: ingredients.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false },
            instructions: instructions,
            imageURL: imageURL
        ))
        dismiss()
    }
}

enum RecipeOCR {
    static func read(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
                let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }

    static func parse(_ text: String) -> (name: String, ingredients: [String], instructions: String) {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard lines.isEmpty == false else {
            return ("", [], "")
        }
        let lowered = lines.map { $0.lowercased() }
        let name = lines.first(where: { $0.count > 2 && $0.lowercased().contains("ingredient") == false }) ?? "Scanned recipe"
        let ingIndex = lowered.firstIndex(where: { $0.contains("ingredient") })
        let dirIndex = lowered.firstIndex(where: {
            $0.contains("instruction") || $0.contains("direction") || $0.contains("method") || $0 == "steps" || $0.hasPrefix("step ")
        })
        var ingredients: [String] = []
        var directions: [String] = []
        if let ingIndex {
            let end = dirIndex ?? lines.count
            if ingIndex + 1 < end {
                ingredients = Array(lines[(ingIndex + 1)..<end])
            }
            if let dirIndex, dirIndex + 1 < lines.count {
                directions = Array(lines[(dirIndex + 1)...])
            }
        } else if let dirIndex {
            ingredients = Array(lines[1..<dirIndex])
            if dirIndex + 1 < lines.count {
                directions = Array(lines[(dirIndex + 1)...])
            }
        } else {
            let split = max(1, lines.count / 2)
            ingredients = Array(lines[1..<split])
            directions = Array(lines[split...])
        }
        return (name, ingredients, directions.joined(separator: "\n"))
    }

    static func saveImage(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("recipes")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                if let image { self.onImage(image) }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
