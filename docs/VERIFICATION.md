# Verification evidence

This file describes the repeatable automated checks. It does not certify an App Store release or every real-world file using a listed format.

## Automated checks

- `npm run test:native`: compiles the actual native policies, runs policy test groups for bounded file reading, PNG validation, preferences validation and language resolution, local bridge boundaries and serialized import queue/error/recents behaviour, and Swift-typechecks the native app sources. This check explicitly skips non-macOS platforms.
- `npm test`: native policy tests, locale catalog/DOM/screenshot checks, 15 expected mouse gestures and the OrbitControls modifier adapter; source-authored format fixtures; reversible materials and resource disposal; 12 actual-source interaction scenarios; known STL box dimensions and finite crease normals; textured apple GLB integrity and display-mesh triangle bound.
- `scripts/formats-test.mjs` loads the original fixtures using the same pinned Three.js loaders used by Form. It verifies original OBJ/PLY vertex colors and 20×30×40 dimensions; two named, differently colored glTF/GLB parts with total 0.05×0.03×0.04 metre dimensions; and 3MF face colors with mm/inch normalization to 20×30×40 mm. The 3MF unit parser is evaluated directly from the current viewer source, not replaced with a test-only unit implementation.
- `npm run test:cad`: verifies SHA256 checksums for the exact occt-import-js and OCCT source archives, extracts the pinned upstream 10 mm STEP/IGES cube fixtures and an 18-mesh BREP assembly into `.tmp/cad-fixtures`, then checks successful tessellation, finite vertices and valid mesh indices. These upstream CAD fixtures are not used as original Form demo art.

`scripts/materials-test.mjs` also evaluates the actual viewer material helpers in an isolated context: fallback color, CAD per-face groups, reversible component palette, original material/texture restoration and deduplicated resource disposal.

`scripts/interaction-regression.mjs` executes the full current `viewer.js`, its DOM handlers and a real Three.js scene. The harness substitutes WebGL, native window services and control hardware adapters. Its 12 passing scenarios cover import selection/hierarchy, measurement/transform exclusivity, stale measurement clearing, hidden/clipped picking, section preservation through appearance changes, 32 unique inspection colors, preferences validation and native bridge round-trip, fixed-baseline explosion/docking/undo/reset, nonfinite/unsupported/empty imports preserving the scene and pre-read drop rejection, input-aware keyboard shortcuts, and last-file cleanup. This is logic evidence, not rendered UI or hardware-input evidence.

`scripts/i18n-test.mjs` checks exact catalog keys and interpolation placeholders, regional/script/secondary-language fallback, manual versus system-language selection, real viewer DOM text/inspector changes, filename preservation, RTL switching, scene palette versus persistent app defaults and the actual screenshot composition/native-message flow with a substituted 2D canvas. GPU output and native save dialogs still require app checks.

## Expanded feature tests

The full `npm test` completed with exit 0 on 2026-11-07 after the scoped-appearance, source-handoff, print and viewport-display integrations. In addition to the earlier interaction suite:

- `scripts/ui-regression.mjs`: seven actual-DOM flows for file roots/badges/selection/visibility, keyboard focus restoration, three section normals/slider/reverse, delayed hover/focus tooltip dismissal/localization/RTL, and native source IDs despite identical filenames.
- `scripts/scoped-regression.mjs`: four flows for file-over-scene-over-default precedence/reset, no preference writes from scene edits, selected/all-model fit and hidden/reference fallbacks, and context removal/last-file cleanup.
- `scripts/print-ui-test.mjs`: four flows for known cm³ volume, installed-slicer gating, parameter-sensitive heuristic output, request/source-bound Bambu results, cancellation and late callbacks, explicit unit scale, and additive/hidden mesh handling. It substitutes native responses; it does not run Bambu Studio.
- `scripts/display-ui-test.mjs`: three flows for material/metrics preservation across modes, clipping edges, active camera/control/transform references, seven Z-up views, projection-preserving fit and exact-once edge-helper disposal.
- `scripts/mesh-print-test.mjs`: six actual-geometry groups for known cube volume/areas, transforms/units, additive overlap and visibility, invalid/open/nonmanifold meshes, cache invalidation and heuristic parameter behaviour.
- `scripts/viewport-display-test.mjs`: four actual-Three.js groups for source material restoration, shared edge ownership/disposal, appearance/clipping interaction and camera scale/views/resize/fitting.

Native tests cover source identity, external-app filtering, safe Blender adapter generation, bounded slicer result parsing, preset inheritance and cancellation/timeout policies. Separate sandboxed native probes reported actual Bambu Studio PLA/PETG slicing without network entitlement; final production-app save/handoff/slicer UI still needs an integrated pass for the current bundle. Neither the geometric range nor the slicer estimate establishes physical print duration.

## Original fixtures

`node scripts/format-fixtures.mjs` regenerates `tests/fixtures` from original geometry and data authored for Form. They have no customer source and are covered by Form's original-code/demo-geometry license:

| Fixture | Expected contents |
|---|---|
| `colored-box.obj` / `colored-box.ply` | 20×30×40 mm box, original vertex colors |
| `colored-box.3mf` | Same dimensions in mm, two source face colors |
| `inch-box.3mf` | Same physical dimensions expressed in inches; detects missing 3MF unit conversion |
| `two-colored-parts.gltf` / `.glb` | Two named boxes with coral/blue materials, 0.05×0.03×0.04 m total bounds |

The fixture generator uses the pinned Three.js exporters where appropriate. The glTF and 3MF containers are authored directly in the generator to retain known geometry, units, material colors and hierarchy.

## Earlier integrated preview checks on the development Mac

Before the later scope/display/slicer additions, on 2026-11-07 `npm test`, CAD fixture checks and a universal Release build passed on Apple Silicon/macOS 27. The installed bundle's ad-hoc signature and both executable architectures were verified. The native app opened the original two-part GLB fixture with correct Z-up bounds (50 × 40 × 30 mm), initially collapsed file roots, its format badge and file inspector. Switching between source and inspection colors preserved an active clipping plane. The textured reference apple rendered beside the model.

The native PNG save dialog wrote a 1500 × 1640 image, then the saved image was decoded and visually inspected: model, fading grid and all three dimension labels were present, without application navigation/toolbars. `distribution/Form-Viewport.png` is that original-fixture export, not a customer model or an App Store screenshot.

German system-language selection and manual English switching were verified in the app, including native menus. The same bundled viewer was checked in the local browser at 1040 × 600 with both sidebars: all three groups fit inside the viewport with 32 px bottom spacing. Arabic RTL layout was also rendered and checked at that size. Native macOS window-resize behaviour, physical mouse/trackpad variants and all translations have not received exhaustive manual validation.

## Current release candidate — 2026-11-07

Code commit `71a0437` passed the complete automated suite and both universal configurations in [GitHub Actions](https://github.com/FDMwerk/Form/actions/runs/42360030322). Native tests include a sandboxed real WKWebView test executing the actual production import/selection function bodies; this specifically prevents the missing-JavaScript-return bug discovered during app checks. Current tests also cover native capabilities, Store exclusion of external execution adapters, request/source correlation, UUID fallback, cancellation and last-model print-state cleanup.

The actual desktop app showed the new folded-F sidebar mark, wider two-column application preferences and refined tree. An original 20 × 20 × 20 mm STL showed 8 cm³ volume; the geometric print range was 13–30 min with the displayed generic settings. The edges/orthographic view and right-click removal of the last file were exercised. The stalled native print/handoff discovered in that check was fixed and covered by the real WebKit regression; a final manual rerun after that fix remains pending because the development Mac was locked.

ZIP and DMG preview artifacts were built from the final desktop payload. The clean staged app passed strict signature checks for both architectures, ZIP integrity and DMG checksums passed, and their explicit SHA256 manifest was published with [the preview release](https://github.com/FDMwerk/Form/releases/tag/v0.3.0-preview). They are not notarized or App Store distribution-signed. The exact corresponding-source archive is attached to the same release.

The dependency-free product page was checked locally at desktop and 390px mobile widths, with all images loaded and no horizontal overflow. Its custom-domain WordPress publication is separate and still needs authenticated access. Final App Store interface screenshots also require the unlocked Mac; a model-only PNG export is not a substitute for those listing captures.

## Remaining validation

Follow [QA.md](QA.md). Run real-app checks after the final source changes and packaging: native multi-file opening, file dialogs and drag/drop, color restoration, settings persistence, measurements, transforms, undo, docking, explosion, clipping and reference placement. Validate malformed and large files, minimum supported macOS, and an Intel Mac before presenting them as tested platforms. See `docs/RELEASE_READINESS.md` for the actual application/release review status.

## Build 7 checkpoint — 2026-11-07

The active session completed the full automated suite and universal Desktop/AppStore builds. The session owner checked actual native rendering: filled section caps on the colored GLB model and an STL ring with its true hole preserved both passed. Independent read-only checks of the new 0.3.0 (7) archived app passed strict/deep/all-architecture signature verification, x86_64+arm64, sandbox enabled and debug task entitlement absent. The exported installer passed signature-chain verification for team D5VE86DJ5H. The release agent confirmed Desktop build 7 installed locally, with signature/architecture/icon/sandbox checks. A private MacBook-test ZIP was created and its extracted app verified. The Store 7 installer was fully expanded in temporary storage and its actual payload confirmed as build 7/AppStore/team D5VE86DJ5H with strict verification. These local packages were not published. Earlier build 6 evidence remains historical. These checks are not Apple server validation, upload, submission, approval or physical Intel/macOS 14 testing.

Store metadata/image checkpoint: the session owner verified actual loaded thumbnails for JPEG01 and filled-cap JPEG03, both 1280×800, without error icons; both persisted after reload (2 of 10). Manual release after review also persisted after reload. The old failed PNG version entries were removed recoverably. At that earlier checkpoint Xcode validation/upload had not occurred. The official-component/account blockers were subsequently resolved; see the actual 8 November validation below. DSA address proof was submitted directly by the user; the last verified Business portal observation on 7 November 2026 showed “Gesetz über digitale Dienste”, 27 countries, “In Prüfung”; no new DSA check is claimed. Apple provider verification remains under review, not approved.

## Apple validation and user MacBook test — 2026-11-08

On **8 November 2026**, the user reauthenticated the existing Apple account in Xcode and downloaded the manual profiles. Organizer opened the exact signed **Form 0.3.0 (7)** archive. The custom validation used the app certificate dated 7 November, profile **Form Mac App Store 2026**, and unchanged build 7. The final actual UI displayed **“Form 0.3.0 (7) validated”** and **“Your app successfully passed all validation checks.”** This is successful Apple validation, **not a binary upload, App Review submission, review approval or public release**. The earlier component-installation and expired-session blockers are resolved/historical.

On **8 November 2026**, the user reported that the MacBook test completed successfully and accepted the local test. This is a user-reported smoke-test result; it does not identify a specific processor/minimum macOS version or establish exhaustive hardware/accessibility testing.

DSA remains last observed 7 November 2026 “In Prüfung”; this is not a fresh portal verification.


## Build 9 selection and navigation checkpoint — 2026-11-08

The full automated suite, including seven integrated selection scenarios, passed. Both Desktop and AppStore products were built for arm64 and x86_64. The separate signed AppStore archive and the fully expanded installer were checked for build 9, the existing distribution team/profile, sandboxing and absence of get-task-allow or external execution payloads. The extracted private Desktop test ZIP passed strict signature checks. This is local build/package verification; Apple Organizer validation remains recorded for build 7 only. No build 9 upload, App Review submission or approval is claimed.

Real native QA used an isolated Store-flavor build 9 window and the unchanged MakerWorld Benchy mesh: opening initially showed no selection box; explicit tree selection enabled the violet box; Measure displayed 60 × 31 × 48 mm outer dimensions. Cmd-click selected two files and displayed 140 × 31 × 48 mm; All models expanded the selection to 220 × 31 × 48 mm across three files. Navigation cube faces displayed large signed axes, with no visible direction words. Fresh German and English app captures were taken for private Store media. Native QA did not replace the user's other open app sessions.


## Build 10 measurements and camera checkpoint — 2026-11-08

The full automated suite passed, including native Desktop/AppStore/WebKit bridge tests, eight selection scenarios including the box toggle, measurement interaction tests, three snapping/transform math scenarios and six cube-drag scenarios. The last formatting-only change adds locale-aware angle labels and was checked with a real 57.9946-degree measurement: German 57,99° and English 57.99°, in both the label and sidebar; all nine measurement scenarios then passed. GPU/native APIs are substituted in the JavaScript harness, so they do not establish rendering quality on their own.

Actual native QA in a separate build 10 window verified distance, path completion by Enter and double-click, three-point angle, individual/all measurement visibility, deletion through label and sidebar context menus, measurement focusing, selection-box hiding without losing file selection, and cube dragging/face clicks while a measurement point remained pending. A private screenshot records that successful UI test before the angle decimal-separator correction. The final format correction was independently tested and rebuilt. The user's earlier isolated test session was untouched.

Both final Desktop/AppStore products contain identical generated viewer SHA256 f2c4448cc60cf9ea6b486c3709e2c89b4dbfa4b6a92a4097a75f4165d61ae070. The final Store installer SHA256 is b4cbf594be286cfbf97a99e94caf6aa7fc8f2b3800c1517eff3bd20fed2ce700. It was fully expanded; actual payload build 10, Store flavor, arm64+x86_64, strict signature, sandbox and absence of debug entitlements were checked. Desktop build 10 was installed only while the production app was closed, preserving the previous build and active QA windows. No minimum-OS/Intel hardware test or Apple review approval is inferred from these checks.

Xcode Organizer then validated the exact final signed Form 0.3.0 (10) archive, bundle de.fdmwerk.form and the existing team distribution certificate/profile. The actual success dialog confirmed that all validation checks passed. No Distribute/Upload or review action was taken.


## Build 11 final Mac candidate — 2026-11-08

The full automated suite passed, including 12 measurement UI cases, seven snapping/math cases, eight selection cases, six cube cases and the top-center status regression. Coverage includes visible neighbor features outside the hit triangle, perspective-correct edge interpolation, same-mesh/foreground occlusion, clipping, reflected transforms, constant marker size under both camera projections, real RAF pointermove with button -1, preview-to-click identity and hidden sidebar value updates. Native QA separately verified an exact 80 mm model edge, contrast markers, top-center instructions and hidden 80→800→80 mm unit changes. Hover-only motion itself is covered in the production-code harness because the native control API exposes click/drag rather than a standalone hover action.

Universal Desktop/AppStore builds and strict signed package checks passed. Product resource SHA256 a45eaaf6211c1c0919336fa0a4dc5123ad9a4b1131be863e485b22022e8e2198 matches the fully expanded Store installer payload. Installer SHA256: ec36958bea7aecab00a23435dbb44d6fa532bdf1cf162ba6abfc19555e562a86. The production app was updated only while closed; active isolated QA sessions were preserved. Apple's validation/upload/submission status is tracked independently in the handoff.

The exact final signed build 11 archive passed all Xcode Organizer validation checks. Upload was started only after that success, under the owner's explicit release instruction.
