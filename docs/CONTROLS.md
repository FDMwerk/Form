# Viewport controls

Use Form → Einstellungen (⌘,) or the settings button. Fundamental mouse profiles:

| Profile | Orbit | Pan | Zoom |
|---|---|---|---|
| Bambu Studio | Left drag | Right or middle drag | Wheel |
| Autodesk Fusion 360 | Shift + middle drag | Middle drag | Wheel |
| Blender | Middle drag | Shift + middle drag | Wheel / Ctrl + middle drag |
| SOLIDWORKS | Middle drag | Ctrl + middle drag | Wheel / Shift + middle drag |
| Onshape | Right drag | Middle drag / Ctrl + right drag | Wheel |

These presets emulate the fundamental gestures, not every special gesture, selection mode, pivot rule or hardware driver behaviour of the original applications. Product names describe familiar mappings and do not imply endorsement or affiliation. A separately enabled trackpad mode uses two-finger scrolling for pan, Option + two fingers for orbit, and pinch for zoom. Speeds and zoom direction are adjustable. Settings are saved locally in the app's UserDefaults.

A double click selects a component. Select a tree row to move a whole file or assembly group. Translation/rotation handles affect the selected group. While measuring, left clicks place measurement points; Escape exits measurement mode.

## Display

Original material colors, vertex colors and embedded textures are preserved where the supported loader provides them. CAD face colors are represented as material groups. Default color applies to geometry without assigned source colors. “Bauteile unterschiedlich einfärben” overrides component colors for inspection; turning it off restores originals. Texture display can be toggled independently. External OBJ MTL/texture files and external glTF dependencies are not resolved in this preview; use an embedded GLB or supported textured 3MF for a self-contained asset.

## Primary mapping references

- https://github.com/bambulab/BambuStudio/blob/master/src/slic3r/GUI/GLCanvas3D.cpp
- https://www.autodesk.com/products/fusion-360/blog/quick-tip-pan-zoom-orbit-preferences/
- https://docs.blender.org/manual/en/latest/editors/3dview/navigate/navigation.html
- https://help.solidworks.com/2021/english/SolidWorks/sldworks/r_Middle_Mouse_Button.htm
- https://cad.onshape.com/help/Content/View/view_navigation_and_the_view_cube.htm

## Language and screenshots

Form follows the system language by default. Select a language explicitly in Settings to override it; the choice is saved locally. A camera button or ⇧⌘S saves the viewport as PNG with visible dimension/measurement labels. The palette button toggles the same component-color preference as Settings. New files start collapsed in the tree; expand a file to see its nested parts.
