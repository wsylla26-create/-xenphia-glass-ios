# Standalone iPad 0.5.0 — Apple build verification

Source commit 21e5045736d4df318d0474720326d8813a67ac17 compiled successfully on GitHub’s standard macOS runner with Xcode 16.4.

The first simulator test attempt failed before executing tests: iOS 18.5 could not load libswiftWebKit.dylib. This matches WebKit bug 293831, confirmed by an Apple Frameworks Engineer. The test script now uses the documented simulator-only deployment-target override of 18.4 and selects an available simulator at least that new. The project itself retains its iPadOS 17 minimum.

https://bugs.webkit.org/show_bug.cgi?id=293831
https://developer.apple.com/forums/thread/785964

The corrected simulator test run is pending. Physical-device installation, microphone/voice behavior, visual parity and Apple signing/distribution are not yet verified. There is no signed IPA or TestFlight link.
