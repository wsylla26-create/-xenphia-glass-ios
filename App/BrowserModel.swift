import SwiftUI
import UIKit
@preconcurrency import WebKit

struct BrowserTab: Identifiable {
    let id: UUID
    let webView: WKWebView
    let isPrivate: Bool
    var title = "New tab"
    var desktopMode: Bool?
    var hasContent = false
}

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published private(set) var selectedID = UUID()
    @Published var address = ""
    @Published var status = ""
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var clearingData = false
    @Published private(set) var bookmarks: [SavedPage] = []
    @Published private(set) var history: [SavedPage] = []
    @Published var searchProvider: SearchProvider = SearchProvider(rawValue: UserDefaults.standard.string(forKey: "browser.searchProvider") ?? "") ?? .google {
        didSet { UserDefaults.standard.set(searchProvider.rawValue, forKey: "browser.searchProvider") }
    }
    let downloads = DownloadManager()
    private let records = BrowserRecords()
    private var observations: [UUID: [NSKeyValueObservation]] = [:]
    private var websiteDialog: UIAlertController?
    var webView: WKWebView { tabs.first { $0.id == selectedID }!.webView }
    var isPrivate: Bool { tabs.first { $0.id == selectedID }?.isPrivate ?? false }
    var isStartPage: Bool { !(tabs.first { $0.id == selectedID }?.hasContent ?? false) }
    var canAddTab: Bool { tabs.count < 8 && !clearingData }
    var currentURL: URL? { DestinationRouter.secureURL(address) }
    override init() {
        super.init()
        print("[XENPHIA Glass 0.5.0] Reading browser records")
        bookmarks = records.bookmarks; history = records.history
        print("[XENPHIA Glass 0.5.0] Creating first tab")
        newTab()
        print("[XENPHIA Glass 0.5.0] First tab ready")
    }
    func newTab(isPrivate: Bool = false) {
        guard canAddTab else { status = "Close a tab before adding another (8 tab limit)."; return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.defaultWebpagePreferences.preferredContentMode = .recommended
        appendTab(configuration: configuration, isPrivate: isPrivate)
    }
    @discardableResult
    private func appendTab(configuration: WKWebViewConfiguration, isPrivate: Bool, showContent: Bool = false) -> WKWebView {
        print("[XENPHIA Glass 0.5.0] Creating WebKit view")
        let view = WKWebView(frame: .zero, configuration: configuration)
        print("[XENPHIA Glass 0.5.0] WebKit view created")
        view.navigationDelegate = self; view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        var tab = BrowserTab(id: UUID(), webView: view, isPrivate: isPrivate)
        tab.hasContent = showContent
        tabs.append(tab)
        let changed: () -> Void = { [weak self, weak view] in
            Task { @MainActor in
                guard let self, let view else { return }
                self.update(view)
            }
        }
        observations[tab.id] = [
            view.observe(\.url, options: [.new]) { _, _ in changed() },
            view.observe(\.title, options: [.new]) { _, _ in changed() },
            view.observe(\.canGoBack, options: [.new]) { _, _ in changed() },
            view.observe(\.canGoForward, options: [.new]) { _, _ in changed() },
            view.observe(\.isLoading, options: [.new]) { _, _ in changed() },
            view.observe(\.estimatedProgress, options: [.new]) { _, _ in changed() }
        ]
        select(tab.id)
        return view
    }
    func select(_ id: UUID) {
        guard !clearingData, tabs.contains(where: { $0.id == id }) else { return }
        dismissWebsiteDialog(); selectedID = id; status = ""; refreshState()
    }
    func close(_ id: UUID) {
        guard !clearingData, let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        dismissWebsiteDialog()
        let wasSelected = selectedID == id
        releaseTab(tabs[index]); tabs.remove(at: index)
        if tabs.isEmpty { newTab() }
        else if wasSelected { select(tabs[min(index, tabs.count - 1)].id) }
    }
    private func releaseTab(_ tab: BrowserTab) {
        observations.removeValue(forKey: tab.id)
        tab.webView.stopLoading(); tab.webView.navigationDelegate = nil; tab.webView.uiDelegate = nil
        tab.webView.pauseAllMediaPlayback(completionHandler: nil)
    }
    func navigate(_ input: String) {
        guard let url = BrowserInput.destination(input, provider: searchProvider) else {
            status = "Enter a search or an HTTPS address without embedded credentials."; return
        }
        open(url)
    }
    func open(_ url: URL) {
        guard !clearingData else { return }
        guard DestinationRouter.secureURL(url.absoluteString) != nil else { status = "Only HTTPS website addresses are supported."; return }
        if let index = tabs.firstIndex(where: { $0.id == selectedID }) { tabs[index].hasContent = true }
        status = ""; address = url.absoluteString; webView.load(URLRequest(url: url))
    }
    func showHome() {
        guard !clearingData, let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        dismissWebsiteDialog(); webView.stopLoading(); webView.pauseAllMediaPlayback(completionHandler: nil)
        tabs[index].hasContent = false; address = ""; status = ""; isLoading = false
    }
    func extractReadableText(completion: @escaping (String) -> Void) {
        guard !clearingData, !isStartPage else { completion(""); return }
        let view = webView, id = selectedID, url = view.url
        let script = """
        (function(){const root=document.querySelector('article,main,[role=main]')||document.body;if(!root)return '';const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node,out=[],size=0,count=0;while((node=walker.nextNode())&&count++<12000&&size<12000){const e=node.parentElement;if(!e||e.closest('script,style,noscript,form,input,textarea,select,button,nav,header,footer,[contenteditable],[hidden],[aria-hidden=true]'))continue;const s=getComputedStyle(e);if(s.display==='none'||s.visibility==='hidden'||!e.getClientRects().length)continue;const t=node.textContent.trim();if(t){out.push(t);size+=t.length+1;}}return out.join(' ').slice(0,12000);})()
        """
        view.evaluateJavaScript(script) { [weak self, weak view] value, _ in
            guard let self, let view, !self.clearingData, !self.isStartPage,
                  self.selectedID == id, self.webView === view, view.url == url else { return }
            completion((value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    func runBrowserCheck() {
        guard !clearingData, let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        tabs[index].hasContent = true; status = "Built-in browser check. No account is needed."
        webView.loadHTMLString(BrowserCheck.html, baseURL: nil)
    }
    func bookmarkCurrent() {
        guard let url = webView.url, DestinationRouter.secureURL(url.absoluteString) != nil else { status = "Open a website before saving a bookmark."; return }
        records.bookmark(url, title: webView.title ?? url.host ?? "Website")
        bookmarks = records.bookmarks; status = "Bookmark saved on this iPad."
    }
    func removeBookmark(_ id: UUID) { records.removeBookmark(id); bookmarks = records.bookmarks }
    func clearHistory() { records.clearHistory(); history = [] }
    func clearWebsiteData() {
        guard !clearingData else { return }
        dismissWebsiteDialog()
        // Destroy live pages first so they cannot immediately rewrite cookies or history.
        downloads.cancelAll()
        for tab in tabs { releaseTab(tab) }
        clearingData = true; tabs = []; address = ""; isLoading = false; clearHistory(); status = "Clearing website data…"
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            guard let self else { return }
            self.clearingData = false; self.newTab()
            self.status = "Website data and history cleared. Bookmarks and downloaded files were kept."
        }
    }
    func find(_ text: String, backwards: Bool = false) {
        guard !clearingData, !text.isEmpty else { return }
        let view = webView
        let configuration = WKFindConfiguration(); configuration.backwards = backwards; configuration.wraps = true
        view.find(text, configuration: configuration) { [weak self, weak view] result in
            guard let self, let view, !self.clearingData, view === self.webView else { return }
            self.status = result.matchFound ? "Match found." : "No match on this page."
        }
    }
    func setDesktopMode(_ desktop: Bool) {
        guard !clearingData else { return }
        guard let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        tabs[index].desktopMode = desktop
        webView.reload()
    }
    private func refreshState() {
        guard !clearingData, !tabs.isEmpty else { return }
        address = isStartPage ? "" : (webView.url?.absoluteString ?? "")
        canGoBack = webView.canGoBack; canGoForward = webView.canGoForward
        isLoading = webView.isLoading; progress = webView.estimatedProgress
    }
    private func update(_ view: WKWebView, finished: Bool = false) {
        guard !clearingData, let index = tabs.firstIndex(where: { $0.webView === view }) else { return }
        let title = view.title ?? view.url?.host ?? "New tab"
        if tabs[index].title != title { tabs[index].title = String(title.prefix(100)) }
        if view === webView { refreshState() }
        if finished, !tabs[index].isPrivate, let url = view.url {
            records.visit(url, title: title); history = records.history
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !clearingData, let url = action.request.url else { decisionHandler(.cancel); return }
        let internalPage = url.absoluteString == "about:blank"
        let blob = url.scheme == "blob" && action.shouldPerformDownload
        guard internalPage || blob || DestinationRouter.secureURL(url.absoluteString) != nil else {
            if webView === self.webView { status = "This link needs HTTPS or an external app, so it was not opened." }
            decisionHandler(.cancel); return
        }
        decisionHandler(action.shouldPerformDownload ? .download : .allow)
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        if let desktop = tabs.first(where: { $0.webView === webView })?.desktopMode {
            preferences.preferredContentMode = desktop ? .desktop : .mobile
        }
        self.webView(webView, decidePolicyFor: action) { policy in decisionHandler(policy, preferences) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard !clearingData else { decisionHandler(.cancel); return }
        let attachment = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased().hasPrefix("attachment") ?? false
        decisionHandler(response.canShowMIMEType && !attachment ? .allow : .download)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { downloads.track(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { downloads.track(download) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update(webView, finished: true) }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { update(webView) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(webView, error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(webView, error) }
    private func failed(_ view: WKWebView, _ error: Error) {
        guard !clearingData, tabs.contains(where: { $0.webView === view }), view === webView else { return }
        if (error as NSError).code != NSURLErrorCancelled { status = "The page could not load. Check your connection or try another website." }
        refreshState()
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard !clearingData, webView === self.webView else { return }
        status = "This page stopped running. Tap Reload to try again."
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard action.targetFrame == nil, let url = action.request.url, DestinationRouter.secureURL(url.absoluteString) != nil,
              let source = tabs.first(where: { $0.webView === webView }) else { return nil }
        guard canAddTab else { status = "Popup blocked: close a tab before opening another."; return nil }
        // Use WebKit's supplied configuration so form bodies/window.opener are preserved.
        configuration.websiteDataStore = webView.configuration.websiteDataStore
        return appendTab(configuration: configuration, isPrivate: source.isPrivate, showContent: true)
    }
    func webViewDidClose(_ webView: WKWebView) {
        if let tab = tabs.first(where: { $0.webView === webView }) { close(tab.id) }
    }
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) { decisionHandler(.deny) }

    // JavaScript dialogs always identify the website; never present a background tab's message.
    private func presentDialog(_ view: WKWebView, frame: WKFrameInfo, message: String, prompt: String?, confirm: Bool, completion: @escaping (String?) -> Void) {
        guard !clearingData, view === webView, websiteDialog == nil,
              let root = view.window?.rootViewController, root.presentedViewController == nil else { completion(nil); return }
        let host = frame.request.url?.host ?? "Website"
        let alert = UIAlertController(title: "Website: " + host, message: String(message.prefix(2000)), preferredStyle: .alert)
        if let prompt { alert.addTextField { $0.text = prompt } }
        websiteDialog = alert
        if confirm || prompt != nil {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.finishDialog(nil) })
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self, weak alert] _ in
            self?.finishDialog(prompt == nil ? "OK" : (alert?.textFields?.first?.text ?? ""))
        })
        // Replace the cancellation wrapper with an exactly-once result callback.
        dialogResult = completion
        root.present(alert, animated: true)
    }
    private var dialogResult: ((String?) -> Void)?
    private func finishDialog(_ result: String?) {
        let callback = dialogResult; dialogResult = nil; websiteDialog = nil
        callback?(result)
    }
    private func dismissWebsiteDialog() {
        let alert = websiteDialog
        let callback = dialogResult; dialogResult = nil; websiteDialog = nil
        alert?.dismiss(animated: false); callback?(nil)
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        presentDialog(webView, frame: frame, message: message, prompt: nil, confirm: false) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        presentDialog(webView, frame: frame, message: message, prompt: nil, confirm: true) { completionHandler($0 != nil) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        presentDialog(webView, frame: frame, message: prompt, prompt: defaultText ?? "", confirm: true, completion: completionHandler)
    }
}

@MainActor
struct BrowserSurface: UIViewRepresentable {
    @ObservedObject var browser: BrowserModel
    func makeUIView(context: Context) -> WKWebView { browser.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
