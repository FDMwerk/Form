# App interaction and usability checks

Automated logic checks are in `scripts/interaction-regression.mjs`. They execute the full current viewer source and handlers with a real Three.js scene and DOM. GPU rendering, OrbitControls/TransformControls hardware input and native window services are substituted. They cannot establish visual quality, accessibility, physical input behaviour or macOS file handling. Complete this checklist in the built app; record platform/build and observed outcomes separately.

| Flow | Expected result |
|---|---|
| System language → explicit language → restart | Menus, settings, inspector, hints and errors follow the chosen language; unsupported system languages fall back to English; Arabic/Hebrew/Persian layout is mirrored; filenames stay unchanged. |
| Screenshot with dimensions and measurements | Saved PNG contains the 3D viewport and visible labels, at sharp display resolution; no sidebar/toolbar; cancel does not report success. Test native menu and camera button. |
| Empty app → open STL → inspect | Unavailable geometry tools disabled initially; file selected after import, STL badge on root, roots initially collapsed; expand reveals indented parts and survives rebuilds; file info and dimensions match the known fixture. |
| Open several files rapidly, then invalid/empty file | Valid files remain; error explains failed import; previous scene and selection survive; app stays responsive. |
| Inspector + collapse tree + select group | Tree collapse retains objects; group selection updates inspector and attached transform; root and component selection are distinguishable. |
| Measure → orbit/pan gesture → measure | Modified navigation gestures produce no measurement points; only deliberate unmodified surface clicks do. Escape cancels a pending point. |
| Measure → move/rotate/dock/change unit/hide/cut/explode | Old measurements disappear when geometry or pickable surfaces change; there are no floating stale markers. Transform and measuring input modes do not overlap. |
| Section → component palette → textures off/on | Cut remains active through all material changes; only the retained visible half is measurable. Section is a visual uncapped plane. |
| Source colors → palette → default color → originals | 12+ parts have distinct inspection colors; returning to source mode restores original colors/textures; default only affects uncolored parts. |
| Explosion 50 → 100 → 50 → 0 | Repeat positions are stable; zero returns exactly to assembly. Docking or transforming starts from assembled positions, undo restores the previous assembly placement. |
| Translate/rotate → undo; coordinate edit → undo | Selected parent/group moves its children; one undo reverses the action; typing in coordinates does not trigger viewport keyboard shortcuts. |
| Remove one of several files → remove last | Surviving scene remains useful; last removal clears inspector, gizmo, dimensions, section, reference and measurement mode; open affordance returns. |
| Change navigation, color and texture settings → relaunch | Values and visible behaviour restore; reset returns documented defaults. Verify every preset with a physical mouse and trackpad. |
| Open from Finder, native multi-select and drag/drop | Supported formats open in the same app; multiple files append; file access errors explain what failed. Test app launch by opening a document. |
| Resize to minimum window size, sidebar + inspector open | Three bottom groups (view/inspect/arrange) remain reachable with clear spacing; cut/explosion panels avoid overlap; labels and coordinate inputs remain legible. |
| Keyboard, VoiceOver and focus | Buttons expose helpful names; active modes announce state; focus stays visible; settings close and reopen; shortcuts ignore editable controls. |
| Apple reference + fit + section + remove last file | Apple has textured appearance and a documented fixed size; fit includes reference; reference does not interfere with model measurements; last-file removal hides reference. |

Also check a large real assembly, malformed geometry, low-memory behaviour, minimum supported macOS 14 and an Intel Mac before claiming those as validated. No automated suite measures physical CAD accuracy or verifies every format variant.
