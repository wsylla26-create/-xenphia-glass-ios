# XENPHIA Glass — standalone iPad app project 0.5.0

This is a regular native Xcode application, not a Swift Playground and not a Safari website. It uses WKWebView within its own window. Its target is iPadOS 17 or later. Users of the finished installed app do not open Xcode, write code or use Swift Playground.

## Current state

The native project, local artwork, permission descriptions, a shared build/run scheme, XCTest routing tests and Mac build/test scripts are included. The glass home, horizontal YouTube / Google / RAEE-Industries shortcuts, XENPHIA panel, voice routing, languages, private tabs and device-test checklist are carried forward.

This environment has no macOS, Apple SDK, simulator or signing identity. The project compiled successfully on the cloud Mac. Simulator verification is in progress; it has not been signed, installed on a physical iPad or visually verified as a standalone app. There is no installable IPA or TestFlight link in this package. Do not rename this ZIP to IPA.

## Build and personally test for free on a Mac

1. Install the full Xcode app on a compatible Mac and open `XenphiaGlass.xcodeproj`.
2. Select the `XenphiaGlass` scheme and an iPad simulator, then Run. Simulator testing does not require your signing credentials.
3. To install on your own iPad, sign in with your Apple Account in Xcode Settings > Apple Accounts.
4. In the app target's Signing & Capabilities, select your Personal Team and keep automatic signing enabled. If Apple says the bundle identifier is unavailable, choose a unique identifier belonging to your team.
5. Connect your iPad, complete Apple's pairing / Developer Mode steps if requested, select it as the run destination and Run.
6. The resulting app is launched on the iPad. Use Menu > iPad test checklist to record observations.

Apple permits Personal Team testing without paid program membership. Free provisioning currently expires after seven days and requires rebuilding/reinstalling; Apple's device and app limits apply. This is personal testing, not public distribution.

Official guidance:
- https://developer.apple.com/help/account/basics/about-your-developer-account
- https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices

## Command-line verification on a Mac

From this directory:

```sh
./scripts/build-simulator.sh
./scripts/test-ipad-simulator.sh
```

The first script performs an unsigned simulator build. The second runs the app-hosted routing tests on an available iPad simulator at iOS 18.4 or later. It applies a simulator-only 18.4 deployment override for the documented Xcode 16.4 / iOS 18.5 WebKit loader bug; the app project retains its iPadOS 17 minimum. Results are saved under `build/`; the scripts do not upload artifacts or run cloud jobs. Use the Xcode GUI to select your signing team and install on your personal device.

## Distribution later

TestFlight / App Store distribution requires an Apple Developer Program account, signing and App Store Connect preparation. No membership purchase, account agreement, certificate creation, public publishing or cloud build billing has been performed. Apple credentials are not bundled or requested in chat.

## Design and behavior limits

The mountain-lake artwork fills the home screen behind the glass controls. Loaded websites render their own page content in the central WebKit area; XENPHIA retains its own header, navigation and optional assistant sidebar around it. The app does not make other iPad apps visible through websites.

The assistant currently handles browsing requests and selected Wikipedia topics. It is not a general AI chat service. Speech uses Apple frameworks and a manually selected language; recognition can require internet or supported device assets. No always-on wake word has been implemented. Public safety, privacy and website compatibility claims still need validation.

This target uses a new production-oriented bundle identifier `com.raee.xenphia.glass`. Data from the old playground preview is not automatically migrated. The supplied app icon is the existing preview icon; final App Store branding is a later release task.

## Cloud Mac verification

This public repository uses a standard macOS GitHub Actions runner. A push to main or a manual dispatch builds the unsigned simulator app and runs the routing tests. The workflow has no signing credentials, release upload, Actions cache or artifact upload. See the Actions tab for actual compiler and test results. A successful simulator build does not install the app on a physical iPad or produce a signed IPA.
