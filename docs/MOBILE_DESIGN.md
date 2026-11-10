# Native iPhone and iPad design — Form 0.2.0 (2)

10 November 2026. This is a simulator testing build, not an App Store or TestFlight release.

## Native navigation and controls

The mobile application uses UIKit throughout its application UI. `MobileWorkspaceController` is a standard double-column `UISplitViewController` with navigation controllers for the model library and viewer. iPad adapts its sidebar automatically as windows change; iPhone uses the system's compact navigation. There are no hand-positioned replacement navigation bars or sidebar frames.

Navigation bars, toolbar item groups, menus, grouped inspector forms, alerts, selection lists, sliders, switches, color pickers, document pickers and sharing sheets use Apple components and SF Symbols. iOS/iPadOS 26 provides Liquid Glass automatically; the supported older OS versions use their system appearance. Colors and text use semantic UIKit styles and Dynamic Type. The toolbar separates viewing, inspection and model operations instead of collecting every function in one More menu.

The local WKWebView is solely a 3D renderer and annotation surface. Desktop HTML headers, sidebars, settings, toolbars, tooltips, inspectors and orientation controls are hidden. Native typed panel descriptors retain real geometry, material, projection, measurement, section, positioning and docking handlers. Standard orientation is selected in a native menu; model rotation remains available through touch gestures. Long-press measurement annotations uses a native action sheet for deletion.

## Native editors

- View: display style, orthographic/perspective projection, standard orientation, grid/reference, background and screenshots.
- Measure: distance, path and angle modes; point snapping; dimensions and selection bounds; finish/cancel/delete and units.
- Section: plane, position and direction.
- Model: translation, rotation, explosion, undo, XYZ position and docking.
- Appearance: scene/file scope, colors and textures.
- Settings: language, navigation speeds and display defaults.
- Information: grouped geometry/file values, with a separate local geometric printing estimate. No direct-print promise or generated G-code.
- Legal/support: native text and menus, locally bundled library licenses, user-initiated external support links.

## Correctness and validation

The previous native metadata could remain stale while a mesh rendered because a debounce was restarted by every animation-frame accessibility mutation. Native state now uses bounded throttling, semantic deduplication and explicit import notifications. It includes the committed renderer title, model count and source identity. Hosted tests verify native UI and source-file registration under continuous rendering, not merely the presence of a mesh.

Four hosted integration tests and three native form tests pass on both iPhone 17 Pro and iPad Pro 13-inch (M5), iOS/iPadOS 26.1: 14 successful runs. They cover native example loading, error recovery, selection/visibility/unload, production editor routes, units and measurement controls, native info, form values and native safe-area/canvas geometry. Node tests cover typed bridge validation, update starvation and actual renderer operations. The full existing regression suite also passed. Native screenshots and geometry diagnostics were visually checked and stored privately under `Dokumentation/Mobile-Entwicklung/Neudesign-2026-11-10`.

Simulator evidence is separate from real-device acceptance. Mail/Files-provider transfers, sharing to installed apps, low-memory behavior on large CAD assemblies, VoiceOver, Pencil, OS 17/27 behavior and actual print handoff still require physical-device verification. TestFlight and Store submission are not part of this build.

## Apple references

[Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [UISplitViewController](https://developer.apple.com/documentation/uikit/uisplitviewcontroller).
