import Foundation

struct SocialRecipeDraft: Identifiable {
    var id = UUID()
    var name: String
    var source: String
    var sourceURL: String
    var imageURL: String
    var ingredients: [String]
    var instructions: String
    var caption: String
}

enum SocialRecipeImport {
    enum Failure: LocalizedError {
        case badURL
        case empty

        var errorDescription: String? {
            switch self {
            case .badURL: return "That does not look like a link."
            case .empty: return "Could not read a recipe from that link. Paste it anyway and fill in the details."
            }
        }
    }

    static func ingest(_ raw: String) async throws -> SocialRecipeDraft {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            throw Failure.badURL
        }
        let host = (url.host ?? "").lowercased()
        return SocialRecipeDraft(
            name: titleFromURL(url),
            source: brand(host),
            sourceURL: trimmed,
            imageURL: "",
            ingredients: [],
            instructions: "Add ingredients and steps here.\n\(trimmed)",
            caption: ""
        )
    }

    private static func brand(_ host: String) -> String {
        if host.contains("tiktok") { return "TikTok" }
        if host.contains("instagram") { return "Instagram" }
        if host.contains("youtube") || host.contains("youtu.be") { return "YouTube" }
        if host.contains("pinterest") { return "Pinterest" }
        return "Link"
    }

    private static func titleFromURL(_ url: URL) -> String {
        let title = url.lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return title.isEmpty ? "Saved link" : title
    }
}
