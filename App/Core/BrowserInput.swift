import Foundation

enum SearchProvider: String, CaseIterable, Identifiable {
    case google = "Google", duckDuckGo = "DuckDuckGo"
    var id: String { rawValue }
    func search(_ query: String) -> URL {
        DestinationRouter.queryURL(self == .google ? "https://www.google.com/search" : "https://duckduckgo.com/", [("q", query)])
    }
}

enum BrowserInput {
    static func destination(_ raw: String, provider: SearchProvider) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 4096,
              !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        switch DestinationRouter.resolve(text) {
        case .destination(let url, _): return url
        default:
            // Never interpret an unsafe or unsupported explicit scheme as a website.
            if text.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil { return nil }
            return provider.search(text)
        }
    }
    static func downloadName(_ suggestion: String) -> String {
        let last = (suggestion.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
        let clean = last.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let name = String(String.UnicodeScalarView(clean)).trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "." || name == ".." { return "Download" }
        // Keep the extension while limiting long server-provided filenames.
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        return String(stem.prefix(120)) + (ext.isEmpty ? "" : "." + String(ext.prefix(20)))
    }
}
