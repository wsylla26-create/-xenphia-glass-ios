import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    let voice: VoiceController
    let browser: BrowserModel
    init() {
        print("[XENPHIA Glass 0.5.0] Creating voice controller (audio deferred)")
        voice = VoiceController()
        print("[XENPHIA Glass 0.5.0] Creating browser model")
        browser = BrowserModel()
        voice.onVoiceRequest = { [weak self] captured in
            guard let self, self.active else { return }
            self.request = captured
            self.find()
        }
        print("[XENPHIA Glass 0.5.0] Browser model initialized")
    }
    @Published var showingWelcome = true
    @Published var showingRequestControls = false
    @Published var request = "" {
        didSet {
            if request != oldValue { lookup?.cancel(); isFinding = false; choices = []; allowWebSearch = false }
        }
    }
    @Published var status = ""
    @Published var choices: [TopicCandidate] = []
    @Published var allowWebSearch = false
    @Published var isFinding = false
    @Published var companionVisible = true
    private var lookup: Task<Void, Never>?
    private var hasLaunched = false
    private var active = true
    var greeting: String { voice.selectedLanguage.greeting }

    func launch() { guard !hasLaunched else { return }; hasLaunched = true; voice.speak(greeting) }
    func setForeground(_ value: Bool) {
        active = value; voice.setForeground(value)
        if !value { lookup?.cancel(); isFinding = false }
    }
    func welcome() {
        lookup?.cancel(); isFinding = false; showingWelcome = true; showingRequestControls = false
        voice.speak(greeting)
    }
    func open(_ url: URL, label: String) {
        lookup?.cancel(); isFinding = false; choices = []; allowWebSearch = false
        voice.stopAll(); browser.open(url); showingWelcome = false
        status = voice.selectedLanguage.opening(label); voice.speak(status)
    }
    func cancelRequest() {
        lookup?.cancel(); lookup = nil
        if isFinding { status = "" }
        isFinding = false; choices = []; allowWebSearch = false
        voice.stopAll()
    }
    func searchWeb() {
        guard !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        open(browser.searchProvider.search(request), label: "web search results")
    }
    func find() {
        voice.stopAll(); lookup?.cancel(); choices = []; allowWebSearch = false
        let submitted = request
        switch DestinationRouter.resolve(submitted) {
        case .destination(let url, let label): open(url, label: label)
        case .clarify(let message): status = message; allowWebSearch = !submitted.isEmpty; voice.speak(message)
        case .topic(let term):
            isFinding = true; status = "Looking for Wikipedia pages about \(term)…"
            lookup = Task { [weak self] in
                guard let self else { return }
                do {
                    let matches = try await TopicLookup.candidates(for: term)
                    guard !Task.isCancelled, self.active, self.request == submitted else { return }
                    self.isFinding = false
                    if let exact = TopicLookup.exact(term, in: matches) { self.open(exact.url, label: "\(exact.title) on Wikipedia"); return }
                    self.choices = matches; self.allowWebSearch = true
                    self.status = matches.isEmpty ? "I could not identify a topic page. Refine your request or search the web." : "Which of these topics do you mean?"
                    self.voice.speak(self.status)
                } catch {
                    guard !Task.isCancelled, self.active, self.request == submitted else { return }
                    self.isFinding = false; self.allowWebSearch = true
                    self.status = "Topic lookup is unavailable. Check your connection, refine your request, or search the web."
                }
            }
        }
    }
}
