# Mobile development status — 10 November 2026

**Form 0.2.0 (2)** is a local development build for iPhone and iPad, targeting iOS/iPadOS 17+ with the separate bundle identifier `de.fdmwerk.form.mobile`. It is not released, submitted to Apple or distributed through TestFlight.

## Implemented redesign

The mobile interface now uses native UIKit components throughout navigation and editing: adaptive split navigation, native model sidebar/list, navigation/toolbars, SF Symbols, grouped form editors, file-information sheets, system menus, document/share sheets, color pickers and native empty/loading states. iPad uses adaptive columns; iPhone uses compact system navigation. WebKit supplies the local 3D renderer and model annotations, with desktop interaction chrome hidden.

The existing viewer operations remain connected to the renderer: import, touch navigation, model/component selection and visibility, hierarchy expansion, multiple selection, unloading, measuring, sections, views/projection, materials/background/grid, explosion, position/docking, file metrics and local geometric print estimates. Native sharing resolves the original imported file; it does not export scene edits or submit a print.

A synchronization defect was identified and repaired: continuously updated renderer attributes could indefinitely postpone the old debounced native-state delivery. The new bounded update path and committed-import snapshots keep native title, model list, enabled controls and source-file identity synchronized while rendering continues. The viewport also uses the actual native safe area, with automatic WebKit scroll insets disabled to avoid blank strips or rendering beneath the sidebar.

## Completed verification

The completed redesign simulator run used Xcode 27.2 SDK with:

| Destination | Result |
| --- | --- |
| iPhone 17 Pro, iOS 26.1 Simulator | 7/7 passed |
| iPad Pro 13-inch (M5), iPadOS 26.1 Simulator | 7/7 passed |

**14 successful test runs** cover four hosted native/renderer integration cases and three native-form cases:

- The original Benchy hash and production native example-opening path, including continuous observed renderer updates. Success requires both real native and renderer metadata, not merely a visible mesh.
- Native title, sidebar, enabled controls and registered source-file identity; queued valid/invalid/valid imports and continued operation after rejection.
- Sidebar selection, All Models, visibility and unloading while preserving the other model.
- Production toolbar/sidebar routes to native editors, ruler activation/deactivation, native file information and absence of desktop interaction chrome.
- Actual WKWebView frame versus native safe area, canvas origin and dimensions versus the real web viewport, with diagnostic JSON and screenshots.
- Typed switches, current-value menus, long labels, slider quantization and state updates during active editing.

Private simulator screenshots, geometry diagnostics and logs belong in `Software/Form/Dokumentation/Mobile-Entwicklung`, outside GitHub. The final build-2 simulator recheck also completed successfully on both destinations (14 runs); the verification log is `Form-native-redesign-verified-test.log` in the private handoff evidence. Build/test commands and the local cache convention are in [mobile/README.md](../mobile/README.md).

## Still required

These simulator checks do not establish real-device usability, accessibility or printing. Mail attachment opening, Files/iCloud provider behavior, native share destinations, touch/Apple Pencil, large CAD imports and memory pressure, rotation/resizable windows, VoiceOver, larger text, contrast/transparency settings and an iOS 27 runtime remain acceptance work. Full native-string localization and external OBJ/GLTF dependencies also need completion.

The mobile app has no verified direct Bambu Handy local-file printing integration, no slicer and no physical print result. Verified printer/nozzle/material profiles, supported handoff, device signing, TestFlight and mobile App Store review remain separate tasks. [Bambu investigation](MOBILE_BAMBU_HANDOFF.md) · [Mobile design decisions](MOBILE_DESIGN.md).

The public repository remains source-only. Private application binaries, screenshots/videos and signing material must not be published there; no claim is made here that the latest local source was pushed. The submitted macOS build remains separate and unchanged.
