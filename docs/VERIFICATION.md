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
