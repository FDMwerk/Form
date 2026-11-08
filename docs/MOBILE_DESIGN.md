# Mobile UI and Liquid Glass

Reviewed 8 November 2026 against Apple's current [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) and [UIKit design adoption](https://developer.apple.com/videos/play/wwdc2025/284/) guidance.

## Decisions

- Render models in a quiet content layer; reserve the system material for navigation and actions. Do not add artificial glass shaders to geometry, grid, labels or information text.
- Use real UIKit `UINavigationBar`, `UIToolbar`, `UIBarButtonItem` and `UIMenu` above the WKWebView. On iOS/iPadOS 26+ the system supplies Liquid Glass; earlier supported systems use their own standard appearance. No custom bar background, blur shader or tint overlay overrides the system material.
- Replace the imported desktop header/tool rows with native bars; all renderer commands remain routed to the same underlying actions. Keep frequently used Fit, Measure and Section controls direct on iPhone, with contextual secondary commands in a More menu. On wider iPads also expose Screenshot, Dimensions, Move and Explode directly. Keep three logical groups in the bottom toolbar.
- Use SF Symbols, source-language accessibility labels and selected/disabled states that follow the actual scene. Native document/share sheets provide familiar system interactions. Units are a checked native menu rather than an extra strip over the model.
- Keep model tree/information readable as content panels, using overlays in compact layouts. Touch controls have a 44pt target. Native safe-area constraints, adaptive widths and UIScene lifecycle support phone rotation and iPad windows; each scene owns its model session.
- Retain detailed measurement, section, display/background and scene controls. These remain web content controls for now. Native primary bars and menus follow system accessibility/material behavior; custom panels still need full physical-device and VoiceOver review. Reduced motion and increased contrast rules cover custom mobile controls.

## Boundaries

This is a tested development adaptation, not Apple certification or a complete accessibility audit. Real-device VoiceOver, larger text, Reduce Transparency/Increase Contrast, light/dark appearance, small and resizable iPad windows, Pencil, external keyboard and long measurement sessions remain release gates. Native toolbar menus expose the current actions; full native inspector/sheet conversion can be refined without changing geometry behavior. There is no direct Bambu print claim.

## Mobile workspace pass

The bottom bar now separates View (six focused commands), Measurement options (dimensions, selection box, clearing and units) and Model tools (move, rotate, explode, undo, scene settings, position/docking). Settings, feedback, legal and the example remain in the model sidebar. The former general-purpose More menu and duplicate top-left view/background buttons are removed. Empty-scene model actions are disabled.

File information uses a native grouped table in a system sheet with medium/large detents and readable wrapping labels/values. Position and docking remain separate editing controls. Web subpanels for display, background and scene settings have explicit close controls; all detailed panels are bounded and scrollable, with portrait/landscape rules and 44pt fields. These improvements retain the existing model operations and detailed measurement controls.

Mobile grid spacing uses 1/2/5 mm steps selected from camera span and CSS viewport height, with hysteresis and stronger major lines. Desktop spacing and radial fading are retained. Tests cover camera zoom, grid visibility/background, all original toolbar commands, opening/closing detailed panels, unit changes and native information-sheet content. Simulator checks remain distinct from real-device touch/accessibility acceptance.

## Native iPad sidebar

The iPad model sidebar now uses `UICollectionView` with Apple's `.sidebar` list appearance, native large navigation title, SF Symbols, selection indicators and Dynamic Type text. The former HTML desktop sidebar is hidden on iPad only; its model state remains the renderer bridge. Opening files/example, hierarchy disclosure, selecting All Models or multiple parts, measurement focus, visibility, root-file removal, settings, feedback and legal actions remain connected to the original operations.

Wide iPad windows show a separate 292pt native sidebar; it can be hidden using the sidebar button. Compact iPad windows open the same list as a dismissible native sheet, preserving viewport space. Visibility and removal use native swipe actions and context menus; full-swipe deletion is disabled. The native sidebar is not installed on iPhone. Real-device resizing/VoiceOver acceptance remains outstanding.

References: [Apple Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [UIKit sidebar appearance](https://developer.apple.com/documentation/uikit/uicollectionlayoutlistconfiguration-swift.struct/appearance-swift.enum/sidebar).
