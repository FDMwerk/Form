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
