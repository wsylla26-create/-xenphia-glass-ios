import Foundation

struct TopicCandidate: Identifiable {
    let title: String
    let url: URL
    let disambiguation: Bool
    var id: String { url.absoluteString }
}

enum TopicLookup {
    static func candidates(for topic: String) async throws -> [TopicCandidate] {
        let url = DestinationRouter.queryURL("https://en.wikipedia.org/w/api.php", [
            ("action", "query"), ("format", "json"), ("formatversion", "2"),
            ("prop", "info|pageprops"), ("inprop", "url"), ("ppprop", "disambiguation"),
            ("generator", "search"), ("gsrnamespace", "0"), ("gsrlimit", "5"), ("gsrsearch", topic)
        ])
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("Xenphia-iOS-Preview/0.1 (https://raee-industries.me)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url?.scheme == "https", http.url?.host == "en.wikipedia.org", data.count <= 512 * 1024 else { throw URLError(.badServerResponse) }
        return try parse(data)
    }
    static func parse(_ data: Data) throws -> [TopicCandidate] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], root["error"] == nil else { throw URLError(.cannotParseResponse) }
        let pages = (root["query"] as? [String: Any])?["pages"] as? [[String: Any]] ?? []
        return pages.prefix(5).compactMap { page in
            guard page["missing"] == nil, page["invalid"] == nil, page["ns"] as? Int == 0,
                  let pageID = page["pageid"] as? Int, pageID > 0,
                  let title = page["title"] as? String, !title.isEmpty, title.count <= 300,
                  let text = (page["canonicalurl"] ?? page["fullurl"]) as? String,
                  let url = DestinationRouter.secureURL(text), url.host == "en.wikipedia.org",
                  url.port == nil || url.port == 443, url.path.hasPrefix("/wiki/"), url.path.count > 6, url.query == nil else { return nil }
            let ambiguous = (page["pageprops"] as? [String: Any])?["disambiguation"] != nil
            return TopicCandidate(title: title, url: url, disambiguation: ambiguous)
        }
    }
    static func exact(_ topic: String, in candidates: [TopicCandidate]) -> TopicCandidate? {
        guard candidates.count == 1, let candidate = candidates.first, !candidate.disambiguation,
              candidate.title.caseInsensitiveCompare(topic) == .orderedSame else { return nil }
        return candidate
    }
}
