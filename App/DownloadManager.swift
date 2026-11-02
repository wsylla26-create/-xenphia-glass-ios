import Foundation
import Combine
@preconcurrency import WebKit

struct BrowserDownload: Identifiable {
    let id: UUID
    var name: String
    var state: String
    var file: URL?
}

@MainActor
final class DownloadManager: NSObject, ObservableObject, WKDownloadDelegate {
    @Published private(set) var items: [BrowserDownload] = []
    @Published var status = ""
    private struct Running {
        let download: WKDownload
        let id: UUID
        var destination: URL?
    }
    private var running: [ObjectIdentifier: Running] = [:]
    private var root: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("CyanGlassDownloads", isDirectory: true)
    }
    override init() {
        super.init()
        guard let root else { return }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: root.appendingPathComponent(".pending"))
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        for folder in folders {
            guard let id = UUID(uuidString: folder.lastPathComponent),
                  let file = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first else { continue }
            items.append(BrowserDownload(id: id, name: file.lastPathComponent, state: "Ready · Share to save a copy in Files", file: file))
        }
        items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func track(_ download: WKDownload) {
        guard running.count < 3 else { download.cancel { _ in }; status = "Three downloads are already running. Try again when one finishes."; return }
        let id = UUID()
        running[ObjectIdentifier(download)] = Running(download: download, id: id)
        items.insert(BrowserDownload(id: id, name: "Download", state: "Starting…", file: nil), at: 0)
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let key = ObjectIdentifier(download)
        guard var task = running[key], let root else { completionHandler(nil); return }
        let folder = root.appendingPathComponent(".pending", isDirectory: true).appendingPathComponent(task.id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(BrowserInput.downloadName(suggestedFilename))
            task.destination = url; running[key] = task
            change(task.id, name: url.lastPathComponent, state: "Downloading…")
            completionHandler(url)
        } catch { change(task.id, state: "Could not create download file."); running.removeValue(forKey: key); completionHandler(nil) }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let task = running.removeValue(forKey: ObjectIdentifier(download)), let pending = task.destination, let root else { return }
        do {
            let folder = root.appendingPathComponent(task.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let final = folder.appendingPathComponent(pending.lastPathComponent)
            try FileManager.default.moveItem(at: pending, to: final)
            try? FileManager.default.removeItem(at: pending.deletingLastPathComponent())
            change(task.id, state: "Ready · Share to save a copy in Files", file: final)
        } catch { change(task.id, state: "Could not finish saving this download.") }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let task = running.removeValue(forKey: ObjectIdentifier(download)) else { return }
        if let url = task.destination { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        change(task.id, state: "Download failed. Return to the website to retry.")
    }
    func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        decisionHandler(request.url.flatMap { DestinationRouter.secureURL($0.absoluteString) } == nil ? .cancel : .allow)
    }
    func cancel(_ id: UUID) {
        guard let pair = running.first(where: { $0.value.id == id }) else { return }
        running.removeValue(forKey: pair.key)
        pair.value.download.cancel { _ in }
        if let url = pair.value.destination { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        change(id, state: "Cancelled")
    }
    func cancelAll() {
        let ids = running.values.map { $0.id }
        for id in ids { cancel(id) }
    }
    func remove(_ id: UUID) {
        cancel(id)
        if let file = items.first(where: { $0.id == id })?.file {
            do { try FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
            catch { status = "The downloaded file could not be deleted."; return }
        }
        items.removeAll { $0.id == id }
    }
    func isRunning(_ id: UUID) -> Bool { running.values.contains { $0.id == id } }
    private func change(_ id: UUID, name: String? = nil, state: String, file: URL? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        if let name { items[index].name = name }
        items[index].state = state; items[index].file = file
    }
}
