import Foundation

enum RoutePlan {
    case destination(URL, String)
    case topic(String)
    case clarify(String)
}

enum DestinationRouter {
    static func secureURL(_ input: String) -> URL? {
        guard input.count <= 4096, !input.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let url = URL(string: input), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        return url
    }
    static func queryURL(_ base: String, _ items: [(String, String)]) -> URL {
        var parts = URLComponents(string: base)!
        parts.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return parts.url!
    }
    private static func capture(_ pattern: String, _ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }
    static func resolve(_ raw: String) -> RoutePlan {
        guard !raw.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }), raw.count <= 4096 else {
            return .clarify("Please enter a shorter request without control characters.")
        }
        let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "(?i)^xenphia[,: ]+", with: "", options: .regularExpression)
        guard !original.isEmpty else { return .clarify("What would you like me to find?") }
        let prefix = "(?i)^(?:please\\s+)?(?:(?:can|could|would) you\\s+)?(?:please\\s+)?(?:open|visit|go to|take me to|launch|show me|abre|abrir|visita|ouvre|ouvrir|apri|aprire)\\s+"
        let stripped = original.replacingOccurrences(of: prefix, with: "", options: .regularExpression)
        if stripped.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil {
            guard let url = secureURL(stripped) else { return .clarify("Use an HTTPS website address without embedded credentials.") }
            return .destination(url, url.host ?? "website")
        }
        let domainPattern = "(?i)^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,63}(?::[0-9]{1,5})?(?:[/?#][^\\s]*)?$"
        if stripped.range(of: domainPattern, options: .regularExpression) != nil, let url = secureURL("https://" + stripped) {
            return .destination(url, url.host ?? "website")
        }
        var spokenName = stripped.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Remove conversational endings only after an explicit navigation command.
        // URL parsing above and topic/query text below remain unchanged.
        if stripped != original {
            spokenName = spokenName.replacingOccurrences(
                of: "(?: (?:right now|now|please|for me))+$", with: "", options: .regularExpression)
        }
        let aliases = ["you tube": "youtube", "you-tube": "youtube"]
        let name = aliases[spokenName] ?? spokenName
        let sites: [String: (String, String)] = [
            "youtube": ("https://www.youtube.com/", "YouTube"),
            "wikipedia": ("https://en.wikipedia.org/", "Wikipedia"),
            "google": ("https://www.google.com/", "Google"),
            "maps": ("https://www.google.com/maps", "Google Maps"),
            "google maps": ("https://www.google.com/maps", "Google Maps"),
            "gmail": ("https://mail.google.com/", "Gmail"),
            "godaddy": ("https://www.godaddy.com/", "GoDaddy"),
            "raee": ("https://raee-industries.me/", "RAEE Industries"),
            "raee-industries": ("https://raee-industries.me/", "RAEE Industries"),
            "raee industries": ("https://raee-industries.me/", "RAEE Industries"),
            "raee store": ("https://raee-industries.me/", "RAEE Industries")
        ]
        if let site = sites[name], let url = secureURL(site.0) { return .destination(url, site.1) }
        if let place = capture("^(?:please\\s+)?(?:get |show me )?directions to\\s+(.+?)[.!?]?$", original) {
            return .destination(queryURL("https://www.google.com/maps/dir/", [("api", "1"), ("destination", place)]), "directions in Google Maps")
        }
        if let place = capture("^(?:please\\s+)?(?:find|show me|search for)\\s+(.+\\bnear me)[.!?]?$", original) {
            return .destination(queryURL("https://www.google.com/maps/search/", [("api", "1"), ("query", place)]), "nearby places in Google Maps")
        }
        if let topic = capture("^(?:please\\s+)?(?:search you[ -]?tube for|find videos (?:about|on)|show me videos (?:about|on))\\s+(.+?)[.!?]?$", original) {
            return .destination(queryURL("https://www.youtube.com/results", [("search_query", topic)]), "YouTube results")
        }
        if let topic = capture("^(?:please\\s+)?(?:what (?:is|are)|who (?:is|was)|tell me about|look up)\\s+(.+?)[?!.]?$", original), topic.count <= 160 { return .topic(topic) }
        return .clarify("Which website or topic do you mean? Refine your request or search the web.")
    }
    static func webSearch(_ text: String) -> URL { queryURL("https://www.google.com/search", [("q", text)]) }
}
