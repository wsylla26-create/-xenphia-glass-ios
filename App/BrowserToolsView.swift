import SwiftUI

@MainActor
struct DownloadsView: View {
    @ObservedObject var manager: DownloadManager
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Downloads stay inside this project until you use Share > Save to Files. Downloads saved from private tabs are kept too. Downloads may stop if iPadOS suspends or closes the app.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !manager.status.isEmpty { Text(manager.status).foregroundStyle(.orange) }
                }
                if manager.items.isEmpty { Text("No downloads yet. Use a website's download link to save a file.") }
                ForEach(manager.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.name).lineLimit(2)
                        Text(item.state).font(.caption).foregroundStyle(.secondary)
                        if let file = item.file {
                            ShareLink(item: file) { Label("Share / Save to Files", systemImage: "square.and.arrow.up") }
                        } else if manager.isRunning(item.id) {
                            Button("Cancel download") { manager.cancel(item.id) }
                        }
                    }.swipeActions { Button("Delete", role: .destructive) { manager.remove(item.id) } }
                }
            }.navigationTitle("Downloads")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

@MainActor
struct BrowserSettingsView: View {
    @ObservedObject var browser: BrowserModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    Picker("Search engine", selection: $browser.searchProvider) {
                        ForEach(SearchProvider.allCases) { provider in Text(provider.rawValue).tag(provider) }
                    }
                }
                Section("Privacy") {
                    Text("Normal tabs keep cookies and recent history. Private tabs use temporary website storage and skip history. Private browsing does not hide your activity from websites or your network. XENPHIA speech and topic lookups use Apple/Wikipedia services separately.")
                    Text("Bookmarks and downloaded files are saved when you choose to save them, including in private tabs.")
                    Button("Clear browsing history") { browser.clearHistory() }
                    Button("Clear website data & history", role: .destructive) { confirmClear = true }.disabled(browser.clearingData)
                    Text("Clearing website data closes all tabs, removes cookies and signs you out of websites. It keeps bookmarks and downloaded files.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("XENPHIA Glass 0.5.0") {
                    Text("RAEE-INDUSTRIES · Powered by WebKit")
                    Text("HTTPS browsing, eight tabs, downloads, bookmarks, history, page sharing and find-on-page. The glass interface uses local artwork. Website camera/microphone requests and external-app links are blocked in this build; native XENPHIA speech is separate.").font(.footnote)
                    Text("Native WebKit browser. Website compatibility varies; report issues from the iPad test checklist.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Settings & privacy")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Clear website data and history? This closes all tabs and signs you out of websites.", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Close tabs and clear data", role: .destructive) { browser.clearWebsiteData(); dismiss() }
                    Button("Cancel", role: .cancel) { }
                }
        }
    }
}
