import SwiftUI
import UIKit

@main
@MainActor
struct XenphiaApp: App {
    var body: some Scene {
        WindowGroup { StartupView().preferredColorScheme(.dark) }
    }
}

@MainActor
struct StartupView: View {
    @State private var model: AppModel?
    @State private var starting = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if let model { ContentView(model: model) }
            else {
                ZStack {
                    Image("MountainLake", bundle: .main).resizable().scaledToFill().ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image("RAEELogo", bundle: .main).resizable().scaledToFit().frame(width: 96, height: 96).clipShape(Circle())
                        Text("XENPHIA GLASS").font(.title.weight(.light)).tracking(5)
                        Text("RAEE-INDUSTRIES").font(.caption).tracking(4)
                        if starting { ProgressView("Opening your browser…") }
                        else { Button("Open browser") { starting = true }.buttonStyle(.borderedProminent) }
                    }.padding(32)
                }.task { starting = true }
            }
        }
        .task(id: starting) {
            guard starting, model == nil else { return }
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            let ready = AppModel()
            ready.showingWelcome = false; ready.companionVisible = false
            ready.setForeground(scenePhase == .active); model = ready
        }
        .onChange(of: scenePhase) { _, phase in model?.setForeground(phase == .active) }
    }
}

@MainActor
struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var voice: VoiceController
    @ObservedObject var browser: BrowserModel
    @State private var sheet: BrowserSheet?
    @State private var sidebarOpen = true
    @State private var wideLayout = false
    @State private var addressDraft = ""
    @State private var findText = ""
    @State private var showFind = false
    @State private var reviewedText = ""
    @State private var confirmReading = false
    @State private var shade = 3
    @FocusState private var addressFocused: Bool
    @AppStorage("glass.cycleColors") private var cycleColors = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    init(model: AppModel) {
        _model = ObservedObject(wrappedValue: model)
        _voice = ObservedObject(wrappedValue: model.voice)
        _browser = ObservedObject(wrappedValue: model.browser)
    }
    private var accent: Color { GlassPalette.shades[shade] }
    private var microphoneStatus: String { voice.authorizing ? "Microphone permission" : voice.isListening ? "Listening…" : "Microphone off" }
    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 850 && geometry.size.width > geometry.size.height
            ZStack {
                Image("MountainLake", bundle: .main)
                    .resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                Color.black.opacity(0.17)
                VStack(spacing: 12) {
                    header(wide: wide)
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 8) {
                            addressBar
                            if browser.isLoading { ProgressView(value: browser.progress).tint(accent).accessibilityLabel("Page loading") }
                            if browser.clearingData { ProgressView("Clearing website data…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                            else if browser.isStartPage { homePage }
                            else { BrowserSurface(browser: browser).id(browser.selectedID).clipShape(RoundedRectangle(cornerRadius: 16)) }
                            if showFind { findBar }
                            if !browser.status.isEmpty { Text(browser.status).font(.caption).lineLimit(3).accessibilityAddTraits(.updatesFrequently) }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        if wide && sidebarOpen {
                            assistantPanel { model.cancelRequest(); sidebarOpen = false }
                                .frame(width: min(310, geometry.size.width * 0.29))
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    navigationBar(wide: wide)
                }.padding(.horizontal, 34).padding(.vertical, 28)
                GlassRim().hueRotation(.degrees(GlassPalette.hue[shade])).allowsHitTesting(false).accessibilityHidden(true)
            }.clipShape(RoundedRectangle(cornerRadius: 34))
                .overlay(alignment: .topLeading) {
                    // Real iPad status indicators remain owned by iPadOS.
                    Color.clear.frame(width: 0, height: 0)
                }
                .padding(8)
                .background(Color(red: 0.005, green: 0.035, blue: 0.045))
                .sheet(item: $sheet, onDismiss: { model.cancelRequest() }) { selected in
                    switch selected {
                    case .saved: SavedPagesView(browser: browser)
                    case .downloads: DownloadsView(manager: browser.downloads)
                    case .settings: BrowserSettingsView(browser: browser)
                    case .checks: DeviceCheckView { model.cancelRequest(); browser.runBrowserCheck(); sheet = nil }
                    case .tabs: tabsSheet
                    case .appearance: appearanceSheet
                    case .assistant: assistantPanel { model.cancelRequest(); sheet = nil }.padding(20).background(Color(red: 0.01, green: 0.08, blue: 0.10))
                    }
                }
                .alert("Read this page aloud?", isPresented: $confirmReading) {
                    Button("Read aloud") { voice.speak(reviewedText) }
                    Button("Cancel", role: .cancel) { reviewedText = "" }
                } message: { Text(String(reviewedText.prefix(450)) + (reviewedText.count > 450 ? "…" : "")) }
                .onChange(of: browser.address) { _, value in if !addressFocused { addressDraft = value } }
                .onChange(of: browser.selectedID) { _, _ in model.cancelRequest(); addressFocused = false; addressDraft = browser.isStartPage ? "" : browser.address; showFind = false; reviewedText = ""; confirmReading = false }
                .onChange(of: browser.isStartPage) { _, start in if start { addressDraft = "" } }
                .onAppear { wideLayout = wide; addressDraft = browser.isStartPage ? "" : browser.address }
                .onChange(of: wide) { _, value in wideLayout = value }
                .task(id: "\(cycleColors)-\(scenePhase == .active)-\(reduceMotion)") {
                    guard cycleColors, !reduceMotion, scenePhase == .active else { return }
                    while !Task.isCancelled {
                        do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeInOut(duration: 3)) { shade = (shade + 1) % GlassPalette.shades.count }
                    }
                }
                .tint(accent)
        }
    }
    private func header(wide: Bool) -> some View {
        HStack(spacing: 12) {
            Button { model.cancelRequest(); browser.open(URL(string: "https://raee-industries.me/")!) } label: {
                Image("RAEELogo", bundle: .main).resizable().scaledToFit().frame(width: 60, height: 60).clipShape(Circle())
            }.accessibilityLabel("RAEE-Industries store")
            VStack(alignment: .leading, spacing: 8) {
                Text("RAEE-INDUSTRIES").font(.system(size: wide ? 16 : 13, weight: .light)).tracking(wide ? 4 : 2).lineLimit(1).minimumScaleFactor(0.7)
                languageMenu.font(.caption2)
            }
            Spacer(minLength: 8)
            VStack(spacing: 5) {
                Image(systemName: browser.isPrivate ? "hand.raised" : "shield.lefthalf.filled").font(.title3)
                Text(microphoneStatus).font(.system(size: 10)).lineLimit(2)
            }.foregroundStyle(voice.isListening ? accent : Color.white)
                .accessibilityElement(children: .combine)
        }.foregroundStyle(.white).frame(minHeight: 62)
    }
    private var languageMenu: some View {
        Menu {
            ForEach(VoiceLanguage.allCases) { language in
                Button { model.cancelRequest(); voice.language = language.rawValue } label: {
                    if voice.language == language.rawValue { Label(language.label, systemImage: "checkmark") }
                    else { Text(language.label) }
                }
            }
        } label: { Text("EN · ES · FR · IT").foregroundStyle(.white.opacity(0.85)) }
        .accessibilityLabel("Assistant language: " + voice.selectedLanguage.label)
    }
    private var addressBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.title3)
            TextField("Search or enter website", text: $addressDraft)
                .focused($addressFocused).textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.webSearch).submitLabel(.go)
                .onSubmit { addressFocused = false; model.cancelRequest(); browser.navigate(addressDraft) }
                .disabled(browser.clearingData)
                .font(.system(size: 16, weight: .light))
            browserMenu
        }.foregroundStyle(.white).padding(.leading, 16).padding(.trailing, 8).frame(minHeight: 50)
            .glassSurface(accent: accent, radius: 28)
    }
    private var browserMenu: some View {
        Menu {
            Button(browser.isLoading ? "Stop loading" : "Reload", systemImage: browser.isLoading ? "xmark" : "arrow.clockwise") { model.cancelRequest(); if browser.isLoading { browser.webView.stopLoading() } else { browser.webView.reload() } }
            Button("New tab", systemImage: "plus") { model.cancelRequest(); browser.newTab() }.disabled(!browser.canAddTab)
            Button("New private tab", systemImage: "hand.raised") { model.cancelRequest(); browser.newTab(isPrivate: true) }.disabled(!browser.canAddTab)
            Button("Bookmark this page", systemImage: "bookmark") { browser.bookmarkCurrent() }.disabled(browser.isStartPage || browser.clearingData)
            Button("My shortcuts & history", systemImage: "star") { sheet = .saved }
            Button("Downloads", systemImage: "arrow.down.circle") { sheet = .downloads }
            if let url = browser.currentURL, !browser.isStartPage { ShareLink(item: url) { Label("Share page", systemImage: "square.and.arrow.up") } }
            Button("Read aloud", systemImage: "book") { readPage() }.disabled(browser.isStartPage || browser.clearingData)
            Button("Find on page", systemImage: "doc.text.magnifyingglass") { showFind.toggle() }.disabled(browser.isStartPage)
            Button("Desktop website") { browser.setDesktopMode(true) }.disabled(browser.clearingData)
            Button("Mobile website") { browser.setDesktopMode(false) }.disabled(browser.clearingData)
            Button("Show XENPHIA", systemImage: "sparkles") { presentAssistant() }
            Button("Stop voice", systemImage: "stop.circle") { model.cancelRequest() }
            Button("Colors & appearance", systemImage: "paintpalette") { sheet = .appearance }
            Button("Settings & privacy", systemImage: "gearshape") { sheet = .settings }
            Button("iPad test checklist", systemImage: "checklist") { model.cancelRequest(); sheet = .checks }
            Button("Built-in browser check") { model.cancelRequest(); browser.runBrowserCheck() }.disabled(browser.clearingData)
        } label: { Image(systemName: "ellipsis").font(.title2).frame(width: 44, height: 44).contentShape(Rectangle()) }
        .accessibilityLabel("Browser menu")
    }
    private var homePage: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: geometry.size.height < 500 ? 12 : 22) {
                    Spacer(minLength: geometry.size.height < 500 ? 8 : 30)
                    Text(browser.isPrivate ? "Private browsing" : "Browse with clarity.")
                        .font(.system(size: geometry.size.width > 600 ? 42 : 36, weight: .ultraLight))
                        .multilineTextAlignment(.center).foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 10)
                        .padding(.horizontal, 8)
                    if browser.isPrivate { Text("Temporary website storage. Saved bookmarks and downloads are kept.").font(.caption).multilineTextAlignment(.center).padding(.horizontal) }
                    Spacer(minLength: geometry.size.height < 500 ? 12 : 34)
                    HStack(spacing: 12) {
                        destinationTile("YouTube", asset: nil, system: "play.rectangle.fill", color: .red, url: "https://www.youtube.com/")
                        destinationTile("Google", asset: "GoogleLogo", system: nil, color: .white, url: "https://www.google.com/")
                        destinationTile("RAEE-Industries", asset: "RAEELogo", system: nil, color: .white, url: "https://raee-industries.me/")
                    }.frame(maxWidth: 680)
                    HStack(spacing: 10) {
                        homeAction("Talk to XENPHIA", icon: "mic") { presentAssistant(); toggleListening() }
                        homeAction("Read aloud", icon: "book") { readPage() }
                        homeAction("My shortcuts", icon: "star") { sheet = .saved }
                    }.frame(maxWidth: 680)
                }.padding(.horizontal, 4).padding(.bottom, 14)
                    .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 4))
            }.scrollIndicators(.hidden)
        }
    }
    private func destinationTile(_ title: String, asset: String?, system: String?, color: Color, url: String) -> some View {
        Button { addressFocused = false; model.cancelRequest(); browser.open(URL(string: url)!) } label: {
            VStack(spacing: 10) {
                if let asset { Image(asset, bundle: .main).resizable().scaledToFit().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: asset == "RAEELogo" ? 24 : 0)) }
                else { Image(systemName: system ?? "globe").font(.system(size: 46)).foregroundStyle(color) }
                Text(title).font(.system(size: 13, weight: .regular)).foregroundStyle(.white).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }.padding(.vertical, 14).padding(.horizontal, 4).frame(maxWidth: .infinity, minHeight: 116)
                .glassSurface(accent: accent, radius: 15)
        }.buttonStyle(.plain).accessibilityLabel("Open " + title)
    }
    private func homeAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 19, weight: .light))
                Text(title).font(.system(size: 12)).lineLimit(2).minimumScaleFactor(0.8)
            }.foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 6)
                .glassSurface(accent: accent, radius: 14)
        }.buttonStyle(.plain)
    }
    private func navigationBar(wide: Bool) -> some View {
        HStack(spacing: 4) {
            navigationButton("Back", icon: "chevron.left", disabled: !browser.canGoBack || browser.isStartPage || browser.clearingData) { model.cancelRequest(); browser.webView.goBack() }
            navigationButton("Forward", icon: "chevron.right", disabled: !browser.canGoForward || browser.isStartPage || browser.clearingData) { model.cancelRequest(); browser.webView.goForward() }
            navigationButton("Home", icon: "house", disabled: browser.clearingData) { model.cancelRequest(); browser.showHome(); addressDraft = "" }
            navigationButton("Tabs", icon: "square.on.square", disabled: browser.clearingData) { sheet = .tabs }
            browserMenu.frame(maxWidth: .infinity)
            Button { presentAssistant(); toggleListening() } label: {
                Image(systemName: voice.isListening ? "stop.fill" : "mic.fill").font(.system(size: 23, weight: .light))
                    .frame(width: 48, height: 48).glassSurface(accent: accent, radius: 25)
            }.frame(maxWidth: .infinity).disabled(voice.authorizing || browser.clearingData)
                .accessibilityLabel(voice.isListening ? "Stop listening" : "Speak to XENPHIA")
        }.foregroundStyle(.white).padding(.top, 10)
            .overlay(alignment: .top) { Rectangle().fill(accent.opacity(0.6)).frame(height: 1).accessibilityHidden(true) }
    }
    private func navigationButton(_ title: String, icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 24, weight: .light)).frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle()) }
            .accessibilityLabel(title).disabled(disabled).opacity(disabled ? 0.4 : 1)
    }
    private func presentAssistant() { sidebarOpen = true; if !wideLayout { sheet = .assistant } }
    private func toggleListening() { if voice.isListening { voice.stopListening() } else { Task { await voice.startListening() } } }
    private func readPage() {
        guard !browser.isStartPage else { browser.status = "Open an article first, then choose Read aloud from the menu."; return }
        browser.extractReadableText { text in
            guard !text.isEmpty else { browser.status = "No readable article text found."; return }
            reviewedText = text; confirmReading = true
        }
    }
    private func assistantPanel(close: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("XENPHIA", systemImage: "sparkles").font(.system(size: 17, weight: .light))
                Spacer()
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close XENPHIA panel")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Image("RAEELogo", bundle: .main).resizable().scaledToFit().frame(width: 44, height: 44).clipShape(Circle())
                    Text(model.status.isEmpty ? model.greeting : model.status)
                        .font(.system(size: 16, weight: .light)).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .glassSurface(accent: accent, radius: 22).accessibilityAddTraits(.updatesFrequently)
                    if !voice.transcript.isEmpty { Text(voice.transcript).font(.callout).foregroundStyle(accent) }
                    if !voice.status.isEmpty { Text(voice.status).font(.caption).foregroundStyle(.white.opacity(0.7)) }
                    if model.isFinding { ProgressView("Finding a topic page…") }
                    ForEach(model.choices) { candidate in
                        Button(candidate.title + " · Wikipedia") { model.open(candidate.url, label: candidate.title) }.buttonStyle(.bordered)
                    }
                    if model.allowWebSearch { Button("Search the web") { model.searchWeb() }.buttonStyle(.bordered) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                TextField("Type a browsing request…", text: $model.request, axis: .vertical)
                    .font(.system(size: 14)).lineLimit(1...3).submitLabel(.go).onSubmit { model.find() }
                Button { model.find() } label: { Image(systemName: "paperplane.fill").frame(width: 44, height: 44).glassSurface(accent: accent, radius: 24) }
                    .accessibilityLabel("Send browsing request").disabled(model.request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(8).glassSurface(accent: accent, radius: 24)
            HStack {
                Button(voice.isListening ? "Stop listening" : "Speak", systemImage: "mic") { toggleListening() }.disabled(voice.authorizing)
                Spacer()
                Button("Stop voice") { model.cancelRequest() }
            }.font(.caption).frame(minHeight: 44)
            Text("Browsing commands and Wikipedia topics. Not general AI chat. Speech may use Apple services.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
        }.padding(16).frame(maxHeight: .infinity).foregroundStyle(.white).glassSurface(accent: accent, radius: 22)
    }
    private var findBar: some View {
        HStack {
            TextField("Find on page", text: $findText).onSubmit { browser.find(findText) }
            Button { browser.find(findText, backwards: true) } label: { Image(systemName: "chevron.up").frame(width: 44, height: 44) }.accessibilityLabel("Previous match")
            Button { browser.find(findText) } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Next match")
            Button("Done") { showFind = false }
        }.padding(.horizontal, 12).glassSurface(accent: accent, radius: 12)
    }
    private var tabsSheet: some View {
        NavigationStack {
            List {
                ForEach(browser.tabs) { tab in
                    Button { model.cancelRequest(); browser.select(tab.id); sheet = nil } label: {
                        Label(tab.title, systemImage: tab.id == browser.selectedID ? "checkmark.circle" : tab.isPrivate ? "hand.raised" : "globe")
                    }.swipeActions { Button("Close", role: .destructive) { browser.close(tab.id) } }
                }
                Button("New tab", systemImage: "plus") { model.cancelRequest(); browser.newTab(); sheet = nil }.disabled(!browser.canAddTab)
                Button("New private tab", systemImage: "hand.raised") { model.cancelRequest(); browser.newTab(isPrivate: true); sheet = nil }.disabled(!browser.canAddTab)
            }.navigationTitle("Tabs").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
        }
    }
    private var appearanceSheet: some View {
        NavigationStack {
            Form {
                Section("Glass colors") {
                    Toggle("Smooth automatic color changes", isOn: $cycleColors)
                    ForEach(0..<4) { group in
                        HStack(spacing: 16) {
                            Text(GlassPalette.names[group]).frame(width: 65, alignment: .leading)
                            ForEach(0..<3) { offset in
                                let index = group * 3 + offset
                                Button { cycleColors = false; withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { shade = index } } label: {
                                    Circle().fill(GlassPalette.shades[index]).frame(width: 40, height: 40)
                                        .overlay { if shade == index { Image(systemName: "checkmark").foregroundStyle(.black) } }
                                }.accessibilityLabel(GlassPalette.names[group] + " shade " + String(offset + 1))
                            }
                        }
                    }
                    Text("Twelve shades. Fades pause outside the app and when Reduce Motion is enabled.").font(.footnote)
                }
                Section("Assistant") { languageMenu; Toggle("XENPHIA voice", isOn: $voice.enabled) }
            }.navigationTitle("Appearance").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
        }
    }
}

enum BrowserSheet: String, Identifiable {
    case saved, downloads, settings, tabs, appearance, assistant, checks
    var id: String { rawValue }
}

@MainActor
struct SavedPagesView: View {
    @ObservedObject var browser: BrowserModel
    @Environment(\.dismiss) private var dismiss
    @State private var section = 0
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Saved pages", selection: $section) {
                    Text("Bookmarks").tag(0)
                    Text("History").tag(1)
                }.pickerStyle(.segmented).padding(.horizontal)
                List {
                    if section == 0 {
                        if browser.bookmarks.isEmpty { Text("Open a website and tap Bookmark to save it.") }
                        ForEach(browser.bookmarks) { page in
                            pageButton(page)
                                .swipeActions {
                                    Button("Delete", role: .destructive) { browser.removeBookmark(page.id) }
                                }
                        }
                    } else {
                        Text("Recent pages are saved on this iPad. Clearing this list does not remove cookies or website data.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if browser.history.isEmpty { Text("No browsing history yet.") }
                        ForEach(browser.history) { page in pageButton(page) }
                    }
                }
            }
            .navigationTitle("Saved pages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    if section == 1 { Button("Clear history", role: .destructive) { browser.clearHistory() }.disabled(browser.history.isEmpty) }
                }
            }
        }
    }
    private func pageButton(_ page: SavedPage) -> some View {
        Button { browser.open(page.url); dismiss() } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(page.title).foregroundStyle(.primary).lineLimit(2)
                Text(page.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}
