import SwiftUI
import UIKit

/// Results are recorded by the tester, never inferred from button presses.
@MainActor
final class DeviceCheckStore: ObservableObject {
    @Published private(set) var results: [String: String]
    @Published var notes: String {
        didSet { UserDefaults.standard.set(String(notes.prefix(1500)), forKey: "ipad.checks.0.5.0.notes") }
    }
    init() {
        results = UserDefaults.standard.dictionary(forKey: "ipad.checks.0.5.0.results") as? [String: String] ?? [:]
        notes = UserDefaults.standard.string(forKey: "ipad.checks.0.5.0.notes") ?? ""
    }
    func result(_ key: String) -> String { results[key] ?? "Not checked" }
    func set(_ key: String, _ value: String) {
        results[key] = value
        UserDefaults.standard.set(results, forKey: "ipad.checks.0.5.0.results")
    }
    func reset() {
        results = [:]; notes = ""
        UserDefaults.standard.removeObject(forKey: "ipad.checks.0.5.0.results")
    }
    var report: String {
        let lines = DeviceCheckStep.steps.map { "\($0.title): \(result($0.id))" }.joined(separator: "\n")
        return """
        XENPHIA Glass iPad 0.5.0 — device test report
        These results were manually recorded by the tester. They are not automated certification.
        Device family: \(UIDevice.current.model)
        OS: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)

        \(lines)

        Notes (entered by tester):
        \(String(notes.prefix(1500)))

        No browsing history, addresses, transcripts or account details are automatically included.
        """
    }
}

struct DeviceCheckStep: Identifiable {
    let id: String
    let title: String
    let instructions: String
    static let steps = [
        DeviceCheckStep(id: "home", title: "1. Glass home & shortcuts", instructions: "Check that the mountain lake fills the home background. YouTube, Google and RAEE-Industries should be side by side and open their websites when tapped."),
        DeviceCheckStep(id: "rotation", title: "2. Rotation & sidebar", instructions: "Rotate the iPad and try a narrow window. The shortcut row should stay horizontal. A wide landscape window shows the XENPHIA sidebar; a narrow window opens it from Talk or the microphone. Controls should remain tappable."),
        DeviceCheckStep(id: "browser", title: "3. Browsing & tabs", instructions: "Enter example.com in the address bar. Try another HTTPS website, Back, Forward and Home. Open two tabs from the Tabs button, switch between them and close one."),
        DeviceCheckStep(id: "webcheck", title: "4. Page controls & downloads", instructions: "Use Open built-in browser check below. Test typing, website dialogs, a text-file download and find-on-page. Downloads is in the three-dot menu. This checks actual WebKit behavior; no account is needed."),
        DeviceCheckStep(id: "voice", title: "5. Speak & automatic opening", instructions: "Close this checklist, select English, tap the microphone and say Open YouTube. Grant Apple speech/microphone permissions if you want to use voice. Pause for two seconds. Check that the site opens without a Find button and the microphone turns off. Then check Stop voice."),
        DeviceCheckStep(id: "languages", title: "6. Language selection", instructions: "Select each language from EN · ES · FR · IT. Test Open YouTube / Abre YouTube / Ouvre YouTube / Apri YouTube. Check the spoken opening reply. Recognition and voice availability depend on the iPad. This feature does not translate pages."),
        DeviceCheckStep(id: "reading", title: "7. Read aloud", instructions: "Open an article. Choose Read aloud in the menu, check the preview, then confirm playback. Check Stop voice. Article extraction may vary by website."),
        DeviceCheckStep(id: "privacy", title: "8. Private tab & background audio", instructions: "Open a private tab, browse a test page and close the tab. Its page should not appear in recent History. Bookmarks/downloads you deliberately save are kept. Start listening, then leave the app; the microphone should stop."),
        DeviceCheckStep(id: "colors", title: "9. Colors & motion", instructions: "In Colors & appearance, try a fixed shade and then enable automatic changes. Check green, teal, pink and cyan. Fades should pause outside the app; Reduce Motion prevents automatic fading.")
    ]
}

@MainActor
struct DeviceCheckView: View {
    let openBrowserCheck: () -> Void
    @StateObject private var store = DeviceCheckStore()
    @State private var confirmReset = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Test on your iPad").font(.headline)
                    Text("Record what you actually observe. Nothing is marked Passed automatically. You can return to this checklist from the browser menu.").font(.callout)
                    Text("The checklist stays on this iPad. Only the report you choose to share leaves the app; review your own notes before sharing.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(DeviceCheckStep.steps) { step in
                    Section(step.title) {
                        Text(step.instructions).font(.callout)
                        Picker("Your result", selection: Binding(get: { store.result(step.id) }, set: { store.set(step.id, $0) })) {
                            Text("Not checked").tag("Not checked")
                            Text("Passed on my iPad").tag("Passed on my iPad")
                            Text("Issue found").tag("Issue found")
                        }
                    }
                }
                Section("Offline browser test page") {
                    Button("Open built-in browser check", systemImage: "checklist", action: openBrowserCheck)
                    Text("Opens the included WebKit test page and closes this checklist. Come back through Menu > iPad test checklist.").font(.footnote)
                }
                Section("Notes") {
                    TextField("What happened? Avoid account details or private information.", text: $store.notes, axis: .vertical).lineLimit(3...8)
                        .onChange(of: store.notes) { _, value in if value.count > 1500 { store.notes = String(value.prefix(1500)) } }
                }
                Section("Report") {
                    Text(store.report).font(.caption).textSelection(.enabled)
                    ShareLink(item: store.report) { Label("Share reviewed test report", systemImage: "square.and.arrow.up") }
                    Button("Reset checklist", role: .destructive) { confirmReset = true }
                }
            }.navigationTitle("iPad test checklist")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Reset your recorded test results and notes?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { store.reset() }
                    Button("Cancel", role: .cancel) { }
                }
        }
    }
}
