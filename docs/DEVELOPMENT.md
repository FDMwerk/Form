# Developing Form

## Structure

Form is a native AppKit/WebKit macOS shell around an offline Three.js viewer. `Sources/App.swift` owns windows, menus, file access, native dialogs and the guarded JavaScript bridge. `Sources/NativePolicies.swift` contains testable file, preferences, language, source-identity and external-application policies. The native import coordinator serializes startup and multi-file operations.

`viewer.js` owns scene state, file/group selection, hierarchy, transforms, measurements, sections, scoped appearance, screenshots and inspector UI. `navigation.js` defines familiar navigation profiles. `viewport-display.js` manages material display styles and perspective/orthographic cameras. `mesh-metrics.js` evaluates mesh topology/volume/area; `print-estimate.js` supplies explicitly heuristic FFF estimates. Their limitations and equations are in [MESH-METRICS-AND-PRINT-ESTIMATES.md](MESH-METRICS-AND-PRINT-ESTIMATES.md).

`Resources/Web/index.html` supplies the UI. Fonts are system fonts; interface icons come from Lucide. The original Form/FDMwerk mark is separate from those interface icons. The textured apple is bundled as GLB. CAD tessellation uses the pinned OCCT importer/WASM; see [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).

## Build locally

Use macOS 14+, Xcode, XcodeGen and Node.js 22.12+. No Tripo account or API key is needed to build/run.

```sh
npm ci
npm test
npm run build
npm run icon
xcodegen generate
xcodebuild -project Form.xcodeproj -scheme Form -configuration Release -derivedDataPath build ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
```

`npm run build` generates explicit locale imports, bundles viewer modules and copies the local OCCT WASM/license resources and apple data. Generated viewer/engine payloads are ignored in Git; edit the root source modules. `npm run icon` uses the approved original master icon. `scripts/brand.mjs` exports the related branding separately.

The local project uses ad-hoc signing and app sandboxing. A successful universal build is not evidence of Intel hardware testing, notarization or App Store approval.

## Verify changes

`npm test` runs native policy compilation/tests plus native source typechecking, navigation mappings, original model fixtures, material/disposal regressions, actual Three.js mesh/print and display-camera tests, all-language catalog validation and full-viewer DOM/state interaction suites. The VM harness executes the actual source and handlers with real Three.js geometry; it substitutes GPU rendering, physical controls, layout geometry and native window services. It cannot prove real WebKit rendering or hardware input behaviour.

`npm run test:cad` verifies the exact dependency-source archives, extracts pinned upstream STEP/IGES/BREP fixtures and checks real tessellation/indices. `npm run fixtures` regenerates original OBJ/PLY/3MF/glTF fixtures; these contain no customer geometry. Native tests use temporary files and isolated defaults. External application tests avoid starting print jobs. Review the current native test script and [verification notes](VERIFICATION.md) for the exact evidence.

Before release, follow [QA.md](QA.md) on the built app: Finder opening, drag/drop, native save/open dialogs, display modes, sections/materials, source handoffs, actual slicer cancellation, language/RTL layout, minimum window size and large-file responsiveness. Record untested macOS/Intel configurations explicitly.

## Scene state and material ownership

File roots in `assets` live under `model`. `meshes` contains actual model meshes, excluding reference/measurement/display helpers. A selected child resolves its source file through `owner()`. All-models selection is `null`; fit and metrics then operate on the scene. Hidden ancestors exclude children from measurement picking and visible metrics.

Appearance resolves file overrides over scene overrides over persistent app defaults. Scene/file edits never write UserDefaults. Retained source materials restore original colors/maps; disposable display clones receive palette/texture/clipping changes. Call the viewport display controller after restoring source-based appearance. Detach its helper objects before recursive host disposal to avoid disposing shared edge resources twice. Clipping plane identity must survive material copying.

Display camera changes must update the active `camera`, OrbitControls' object and TransformControls' camera together. Labels, picking, fitting and screenshots use that same active camera. Projection changes preserve apparent scale; standard views follow the app's Z-up convention.

## Native bridge and source identities

The bridge accepts only the app's main local document/frame/view. Navigation is constrained to the bundled document root; imported model URLs are never treated as trusted application pages. Avoid adding network loading or unvalidated external URLs.

Native opening passes `openModel(name, base64, sourceID)` after the viewer's ready gate. `sourceID` is an opaque UUID mapped to the native URL after successful import. `selectedSourceID()` resolves the selected root/child. Match that identity rather than filenames: different paths may have identical names. JavaScript drag imports can lack a native identity and therefore cannot request external-file handoff.

Native-to-viewer setup includes `applySystemLanguages`, `applyViewportSettings` and installed-slicer discovery through `applyPrintSoftware`. Preferences are allowlisted and sanitized natively and in the viewer. The screenshot bridge carries PNG data to a size/type/dimension validator and a user-chosen save panel. Open With/slicer requests resolve only native source mappings and installed compatible apps.

The optional Bambu calculation has request/source IDs and a fixed, labelled original-STL profile. UI accepts only the current request and current selected source. Selection, material and model changes cancel obsolete work; late callbacks are ignored. Keep native cancellation, timeout, temporary-output cleanup and bounded parsing intact. The editable geometric estimate is a separate implementation and must never be labelled as an actual slicer result.

## Localization

English defines `viewer` and `native` dictionaries in `Resources/Web/locales/en.json`. Every catalog must contain the same keys and placeholders. See [LOCALIZATION.md](LOCALIZATION.md). Put `data-i18n` directly on HTML options; nested spans inside `<option>` are invalid in real WebKit even if a test DOM preserves them. Tooltips read localization metadata, remove native duplicate titles and update on language changes. Customer filenames/source names remain untouched.

## Release and licensing

See [RELEASE_READINESS.md](RELEASE_READINESS.md), [PRIVACY.md](PRIVACY.md) and [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). Original code is MIT; third-party components/assets have their own terms. OCCT/importer corresponding-source obligations require the exact dependency sources and notices alongside an appropriate source distribution. App Store signing and distribution terms need their own final review.

```sh
npm run vendor:sources
# After committing the audited, clean release tree:
npm run package:source
```

The source packager archives committed Git content and adds checksum-verified pinned source archives. It deliberately rejects a dirty tree instead of packaging arbitrary untracked files. Keep credentials, customer files, signing keys and local build outputs out of Git. Version/source/binary provenance should be recorded together. Only publish a notarized/App Store release after those separate processes actually succeed; an ad-hoc preview build does not establish them.
