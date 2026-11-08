# Mobile prototype checkpoint — 8 November 2026

Version 0.1.0 (1), iOS/iPadOS 17+ target, separate bundle `de.fdmwerk.form.mobile`. Development only, not submitted to Apple or available through TestFlight.

Verified locally with Xcode 27.2 SDK and iOS 26.1 Simulator:

- iPhone 17 Pro: 3/3 hosted tests passed.
- iPad Pro 13-inch (M5): 3/3 hosted tests passed.
- Benchy matches the original SHA-256 and loads through the real example button. Native UIKit toolbar, measurement toggle, unit changes and retained scene controls are verified.
- Native toolbar command coverage verifies all original toolbar actions remain reachable, with valid/invalid unit handling.
- Tests exercise the actual bundled WebKit renderer: valid / invalid / valid queued STL imports before readiness, continued import after rejection, supported-file policy, mobile adapter bootstrap and viewport overflow.
- Touch adapter tests pass against the actual HTML: 393/768/1024 layout breakpoints, panel open/close, tap/drag/pinch release across WebKit microtask boundaries.
- Existing full `npm test` regression suite passed after the shared viewer's mobile-only input guard.
- Simulator WKWebView snapshots visually inspected on phone and tablet. Evidence/logs stored privately in `Software/Form/Dokumentation/Mobile-Entwicklung`, outside Git.

File provider UI, Mail handoff, native share destinations, physical touch/Apple Pencil, VoiceOver, large model memory limits and any Bambu Handy interaction remain real-device acceptance work. The app adopts UIScene lifecycle and per-window sessions; an iOS 27 runtime still needs validation. No actual slicing or printing test has occurred. Do not describe this checkpoint as a complete mobile product.

On Xcode 27, open **Xcode → Open Developer Tool → Device Hub** for simulated devices. Select the installed iPhone 17 Pro, then Form. Alternatively open `mobile/FormMobile.xcodeproj`, choose the `FormMobile` scheme and a device, then Run.

Build instructions and implemented scope: [mobile/README.md](../mobile/README.md). Supported print handoff findings: [MOBILE_BAMBU_HANDOFF.md](MOBILE_BAMBU_HANDOFF.md).

Liquid Glass adaptation: [MOBILE_DESIGN.md](MOBILE_DESIGN.md). Native UIKit bars on iOS 26, SF Symbols, compact phone actions and additional direct iPad actions. Genuine original Benchy is bundled with separate CC BY-ND 4.0 attribution.

Further mobile UX pass: focused View/Measurement/Model menus, native grouped file-information sheet, explicit subpanel closes, scrollable landscape layouts and camera-adaptive coarser grid. Real WebKit tests verify panel open/close, units and native info groups on phone/tablet; source-based tests cover all original toolbar commands, detailed panel touch/layout contracts and adaptive grid math. Full existing regression suite passed. This does not establish real-device accessibility or physical print operation.
