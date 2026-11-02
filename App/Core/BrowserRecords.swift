import Foundation

struct SavedPage: Identifiable, Codable {
    var id: UUID = UUID()
    let title: String
    let url: URL
    let date: Date
}

/// Local browser records only. Cookies and website data are managed separately by WebKit.
@MainActor
final class BrowserRecords {
    private let defaults: UserDefaults
    private(set) var bookmarks: [SavedPage]
    private(set) var history: [SavedPage]
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func read(_ key: String) -> [SavedPage] {
            guard let data = defaults.data(forKey: key),
                  let pages = try? JSONDecoder().decode([SavedPage].self, from: data) else { return [] }
            return pages.filter { DestinationRouter.secureURL($0.url.absoluteString) != nil }
        }
        bookmarks = Array(read("browser.bookmarks").prefix(500))
        history = Array(read("browser.history").prefix(500))
    }
    private func save(_ pages: [SavedPage], key: String) {
        if let data = try? JSONEncoder().encode(pages) { defaults.set(data, forKey: key) }
    }
    func bookmark(_ url: URL, title: String) {
        guard DestinationRouter.secureURL(url.absoluteString) != nil else { return }
        bookmarks.removeAll { $0.url == url }
        bookmarks.insert(SavedPage(title: String(title.prefix(300)), url: url, date: Date()), at: 0)
        bookmarks = Array(bookmarks.prefix(500)); save(bookmarks, key: "browser.bookmarks")
    }
    func visit(_ url: URL, title: String) {
        guard DestinationRouter.secureURL(url.absoluteString) != nil else { return }
        history.removeAll { $0.url == url }
        history.insert(SavedPage(title: String(title.prefix(300)), url: url, date: Date()), at: 0)
        history = Array(history.prefix(500)); save(history, key: "browser.history")
    }
    func removeBookmark(_ id: UUID) {
        bookmarks.removeAll { $0.id == id }; save(bookmarks, key: "browser.bookmarks")
    }
    func clearHistory() { history = []; defaults.removeObject(forKey: "browser.history") }
}
