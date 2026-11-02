import XCTest
@testable import XenphiaGlass

final class BrowserRoutingTests: XCTestCase {
    private func routed(_ text: String) -> URL? {
        if case .destination(let url, _) = DestinationRouter.resolve(text) { return url }
        return nil
    }
    func testNamedDestinations() {
        XCTAssertEqual(routed("Open YouTube")?.host, "www.youtube.com")
        XCTAssertEqual(routed("Open you tube please")?.host, "www.youtube.com")
        XCTAssertEqual(routed("XENPHIA, open Google")?.host, "www.google.com")
        XCTAssertEqual(routed("Open RAEE-Industries")?.host, "raee-industries.me")
    }
    func testSupportedLanguageOpenCommands() {
        for command in ["Abre YouTube", "Ouvre YouTube", "Apri YouTube"] {
            XCTAssertEqual(routed(command)?.host, "www.youtube.com", command)
        }
    }
    func testSecureNavigationRejectsCredentialsAndInsecureSchemes() {
        for input in ["http://example.com", "https://name:secret@example.com", "javascript:alert(1)", "file:///private/test", "https://example.com\n"] {
            XCTAssertNil(DestinationRouter.secureURL(input), input)
        }
        XCTAssertEqual(DestinationRouter.secureURL("https://example.com/path?q=1")?.host, "example.com")
    }
    func testUnknownVoiceRequestNeedsClarification() {
        if case .clarify = DestinationRouter.resolve("open an unspecified service") { }
        else { XCTFail("Unknown service should not navigate automatically") }
    }
    func testTypedSearchPreservesQuery() {
        let url = BrowserInput.destination("crystal & glass + teal", provider: .google)!
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "q" })?.value, "crystal & glass + teal")
    }
    func testUnsupportedTypedSchemesNeverBecomeSearches() {
        XCTAssertNil(BrowserInput.destination("javascript:alert(1)", provider: .google))
        XCTAssertNil(BrowserInput.destination("http://example.com", provider: .google))
    }
    func testDownloadNamesDoNotEscapeDestinationDirectory() {
        XCTAssertEqual(BrowserInput.downloadName("../../private.txt"), "private.txt")
        XCTAssertEqual(BrowserInput.downloadName("..\\..\\notes.txt"), "notes.txt")
        XCTAssertEqual(BrowserInput.downloadName(".."), "Download")
    }
    func testFourSpeechLanguagesHaveDistinctLocales() {
        XCTAssertEqual(Set(VoiceLanguage.allCases.map(\.rawValue)).count, 4)
        for language in VoiceLanguage.allCases { XCTAssertFalse(language.greeting.isEmpty) }
    }
}
