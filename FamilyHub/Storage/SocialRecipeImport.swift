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
        if host.contains("tiktok.com") {
            if let draft = await oembed("https://www.tiktok.com/oembed?url=\(encode(trimmed))", source: "TikTok", link: trimmed) {
                return draft
            }
        }
        if host.contains("youtube.com") || host.contains("youtu.be") {
            if let draft = await oembed("https://www.youtube.com/oembed?url=\(encode(trimmed))&format=json", source: "YouTube", link: trimmed) {
                return draft
            }
        }
        if host.contains("instagram.com") {
            if let draft = await oembed("https://api.instagram.com/oembed?url=\(encode(trimmed))", source: "Instagram", link: trimmed) {
                return draft
            }
        }
        if let html = await page(url) {
            if let recipe = jsonLD(html, link: trimmed, host: host) { return recipe }
            if let open = openGraph(html, link: trimmed, host: host) { return open }
        }
        return SocialRecipeDraft(
            name: titleFromURL(url),
            source: brand(host),
            sourceURL: trimmed,
            imageURL: "",
            ingredients: [],
            instructions: "Watch the video, then add ingredients and steps here.\n\(trimmed)",
            caption: ""
        )
    }

    private static func oembed(_ endpoint: String, source: String, link: String) async -> SocialRecipeDraft? {
        guard let url = URL(string: endpoint),
              let json = await json(url)
        else { return nil }
        let title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let author = json["author_name"] as? String ?? ""
        let thumb = json["thumbnail_url"] as? String ?? ""
        let caption = title
        let parts = splitCaption(caption)
        return SocialRecipeDraft(
            name: parts.name.isEmpty ? (title.isEmpty ? "\(source) recipe" : title) : parts.name,
            source: source,
            sourceURL: link,
            imageURL: thumb,
            ingredients: parts.ingredients,
            instructions: parts.steps.isEmpty
                ? "From \(author.isEmpty ? source : author).\nWatch: \(link)"
                : parts.steps + "\n\nWatch: \(link)",
            caption: caption
        )
    }

    private static func page(_ url: URL) async -> String? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("FamilyHub/1.0 (recipe import)", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        return html
    }

    private static func json(_ url: URL) async -> [String: Any]? {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("FamilyHub/1.0 (recipe import)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func jsonLD(_ html: String, link: String, host: String) -> SocialRecipeDraft? {
        let blocks = matches("application/ld\\+json[^>]*>([\\s\\S]*?)</script>", html)
        for block in blocks {
            let cleaned = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let data = cleaned.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data)
            else { continue }
            let nodes: [[String: Any]]
            if let dict = object as? [String: Any] {
                if let graph = dict["@graph"] as? [[String: Any]] { nodes = graph }
                else { nodes = [dict] }
            } else if let list = object as? [[String: Any]] {
                nodes = list
            } else {
                continue
            }
            for node in nodes {
                let type = ((node["@type"] as? String) ?? (node["@type"] as? [String])?.joined() ?? "").lowercased()
                guard type.contains("recipe") else { continue }
                let name = node["name"] as? String ?? "Imported recipe"
                let image = firstImage(node["image"])
                let ingredients = (node["recipeIngredient"] as? [String]) ?? []
                let steps = instructionText(node["recipeInstructions"])
                return SocialRecipeDraft(
                    name: name,
                    source: brand(host),
                    sourceURL: link,
                    imageURL: image,
                    ingredients: ingredients,
                    instructions: steps.isEmpty ? "From \(brand(host)).\n\(link)" : steps,
                    caption: node["description"] as? String ?? ""
                )
            }
        }
        return nil
    }

    private static func openGraph(_ html: String, link: String, host: String) -> SocialRecipeDraft? {
        let title = meta(html, "og:title") ?? meta(html, "twitter:title") ?? titleFromURL(URL(string: link) ?? URL(fileURLWithPath: "/"))
        let image = meta(html, "og:image") ?? meta(html, "twitter:image") ?? ""
        let desc = meta(html, "og:description") ?? meta(html, "description") ?? ""
        guard !title.isEmpty else { return nil }
        let parts = splitCaption(desc)
        return SocialRecipeDraft(
            name: title,
            source: brand(host),
            sourceURL: link,
            imageURL: image,
            ingredients: parts.ingredients,
            instructions: parts.steps.isEmpty ? "\(desc)\n\nWatch: \(link)" : parts.steps + "\n\nWatch: \(link)",
            caption: desc
        )
    }

    private static func splitCaption(_ text: String) -> (name: String, ingredients: [String], steps: String) {
        let lines = text
            .replacingOccurrences(of: "\\n", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var ingredients: [String] = []
        var steps: [String] = []
        var name = lines.first ?? ""
        for line in lines.dropFirst() {
            if looksLikeIngredient(line) { ingredients.append(line) }
            else { steps.append(line) }
        }
        if name.count > 80 { name = String(name.prefix(80)) }
        return (name, ingredients, steps.joined(separator: "\n"))
    }

    private static func looksLikeIngredient(_ line: String) -> Bool {
        let lower = line.lowercased()
        let units = ["cup", "tbsp", "tsp", "teaspoon", "tablespoon", "oz", "lb", "gram", "ml", "clove", "pinch"]
        if units.contains(where: { lower.contains($0) }) { return true }
        if line.first?.isNumber == true { return true }
        return false
    }

    private static func instructionText(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let list = value as? [String] { return list.joined(separator: "\n") }
        if let list = value as? [[String: Any]] {
            return list.compactMap { $0["text"] as? String ?? $0["name"] as? String }.joined(separator: "\n")
        }
        return ""
    }

    private static func firstImage(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let list = value as? [String] { return list.first ?? "" }
        if let dict = value as? [String: Any] { return dict["url"] as? String ?? "" }
        if let list = value as? [[String: Any]] { return list.first?["url"] as? String ?? "" }
        return ""
    }

    private static func meta(_ html: String, _ key: String) -> String? {
        let patterns = [
            "property=[\"']\(key)[\"'][^>]*content=[\"']([^\"']+)[\"']",
            "content=[\"']([^\"']+)[\"'][^>]*property=[\"']\(key)[\"']",
            "name=[\"']\(key)[\"'][^>]*content=[\"']([^\"']+)[\"']"
        ]
        for pattern in patterns {
            if let hit = matches(pattern, html).first, !hit.isEmpty { return decode(hit) }
        }
        return nil
    }

    private static func matches(_ pattern: String, _ html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let inner = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[inner])
        }
    }

    private static func brand(_ host: String) -> String {
        if host.contains("tiktok") { return "TikTok" }
        if host.contains("instagram") { return "Instagram" }
        if host.contains("youtube") || host.contains("youtu.be") { return "YouTube" }
        if host.contains("pinterest") { return "Pinterest" }
        if host.contains("facebook") || host.contains("fb.watch") { return "Facebook" }
        if host.contains("reddit") { return "Reddit" }
        if host.contains("threads") { return "Threads" }
        if host.contains("allrecipes") { return "Allrecipes" }
        if host.contains("foodnetwork") { return "Food Network" }
        if host.contains("tasty.co") { return "Tasty" }
        return "Web"
    }

    private static func titleFromURL(_ url: URL) -> String {
        url.lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private static func decode(_ value: String) -> String {
        let amp = "&" + "amp;"
        let quot = "&" + "quot;"
        let apos = "&#39;"
        return value
            .replacingOccurrences(of: amp, with: "&")
            .replacingOccurrences(of: apos, with: "'")
            .replacingOccurrences(of: quot, with: "\"")
    }
}
