# Form for iPhone and iPad

**Development build 0.2.0 (2) — 10 November 2026.** A native UIKit app for iOS/iPadOS 17+, with the existing local CAD renderer in WKWebView. This mobile build is separate from the submitted macOS app. It is not on TestFlight or the App Store.

## Native mobile interface

The user interface uses Apple's system components: `UISplitViewController`, `UINavigationController`, a sidebar collection-view list, navigation/toolbars, menus, grouped inspector tables, document/share sheets, color pickers and native empty/loading states. On iPad, models and the viewport appear in adaptive columns. On iPhone, the same content uses the system's compact navigation. Controls use SF Symbols, Dynamic Type and the current system material, including Liquid Glass on supported OS versions.

WebKit renders the 3D scene and model annotations. The desktop header, sidebar and HTML editor panels are hidden; settings and editing controls are native. iPad retains a touch-enabled XYZ navigator for orbiting and standard views, while iPhone uses the native view controls. One renderer snapshot drives the native title, enabled tools, model list and sharing identity. State delivery is throttled rather than waiting for animation updates to stop.

On iPad, general sidebar actions stay at the bottom while the model tree scrolls independently. The 3D surface extends beneath the floating system bars; the navigator respects the control safe area. View, measurement, section and model tools have a secondary `UIToolbar` above the main toolbar: UIKit owns its glass backgrounds, three functional groups, selection states and system Done/Close buttons. At most five primary actions appear; secondary settings remain in native menus. Detailed editors open from the actual More item in a compact anchored popover, while file information opens from its Info item. Touch navigation remains available in the remaining viewport. File information presents dimensions and volume as adaptive metric tiles; larger accessibility text uses a single column.

Implemented operations include:

- Native multi-file import and document-type registration for STL, STEP/STP, IGES, BREP, OBJ, PLY, 3MF and GLB/GLTF; coordinated security-scoped reads and a 100 MiB per-file limit.
- Touch orbit, pan and pinch; model/component selection, hierarchy expansion, visibility, multiple selection and unloading through native model-list actions.
- Native forms for display/projection and standard views, background/grid, measurement options, section planes, explosion, position/docking, colors/textures, preferences and geometric print estimates.
- A native file-information sheet, local screenshots and sharing of the original imported file. Sharing does not export scene transformations/measurements or confirm printing.
- Local preference storage and nonpersistent WebKit storage. No automatic model upload, analytics, Bambu credentials or print submission.

## Build and test

Requirements: Node 22.12+, Xcode with an installed iOS simulator runtime, and XcodeGen. Run from the repository root:

```sh
npm ci
npm run build
xcodegen generate --spec mobile/project.yml
xcodebuild -project mobile/FormMobile.xcodeproj -scheme FormMobile \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath "$HOME/Library/Caches/Form/MobileRedesign" \
  CODE_SIGNING_ALLOWED=NO build
node mobile/renderer-bridge-test.mjs
node mobile/sidebar-test.mjs
node mobile/grid-test.mjs
```

For hosted simulator tests, list available destinations with `xcrun simctl list devices available`, then use the UUID of an installed device:

```sh
xcodebuild -project mobile/FormMobile.xcodeproj -scheme FormMobile \
  -destination 'platform=iOS Simulator,id=DEVICE_UUID' \
  -derivedDataPath "$HOME/Library/Caches/Form/MobileRedesign" \
  CODE_SIGNING_ALLOWED=NO test
```

The suite contains five hosted native/renderer integration tests and five native form/toolbar tests. The focused native-toolbar run passed seven tests on iPad Pro 13-inch (M5) and six on iPhone 17 Pro, both using iOS/iPadOS 26.1 Simulator; the iPad-specific layout test is intentionally skipped on iPhone. Earlier import tests cover the production native example command, continuous animation/state updates, synchronized UIKit title/tree/file identity and import-error recovery. UI checks cover a long scrolling model tree with pinned actions, native tool groups, current menu values and destructive availability, compact popover origins, ruler activation, file information and full-surface/safe-area geometry. Form tests exercise typed toggles, slider quantization and state updates during a drag. This is simulator evidence, not physical-device acceptance.

Open `mobile/FormMobile.xcodeproj`, select `FormMobile`, and choose a simulator. In Xcode 27, the simulator UI is **Device Hub**. For real-device installation, use an authorized development team and provision the separate `de.fdmwerk.form.mobile` identifier; these build commands do not create certificates or submit an app. Debug builds support `--example` to load the example at launch.

## Bundled example and licensing

The original `3DBenchy.stl` from MakerWorld 40146 is included under `Resources/Examples/`, with provenance and attribution: CreativeTools, shared by Bambu Lab, **CC BY-ND 4.0**. The model mesh is unchanged and is **not covered by Form's MIT code license**. Open it from the native empty state or model sidebar without a download. The in-app Privacy & Licenses page includes its credit; sharing this example also includes the attribution file. A test verifies the original SHA-256 and opens it through the production native command.

## Release gates

Real iPhone/iPad testing is still required for Mail attachments, Files/iCloud providers, native share destinations, physical touch/Apple Pencil, memory pressure/large CAD files, rotation and resizable windows, VoiceOver, larger text and accessibility display settings. An iOS 27 runtime needs separate validation. Native prototype strings are not yet fully localized in every viewer language. External dependencies of multi-file OBJ/GLTF imports require packaging work.

No supported direct local-file-to-Bambu-Handy print route has been verified, and this build does not slice or start prints. A validated machine/nozzle/profile catalogue, physical print acceptance, signing, TestFlight distribution and mobile Store review remain separate work. See [the Bambu handoff investigation](../docs/MOBILE_BAMBU_HANDOFF.md) and [current development status](../docs/MOBILE_DEVELOPMENT_STATUS.md).

Keep GitHub source-only: application binaries, preview media, signing material and private release packages stay outside the public repository. This document does not claim the latest local commits were pushed. Building the mobile prototype does not replace `/Applications/Form.app` or change the immutable macOS Store release.
