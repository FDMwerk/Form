# App interaction and usability checks

Automated logic checks are in `scripts/interaction-regression.mjs`. They execute the full current viewer source and handlers with a real Three.js scene and DOM. GPU rendering, OrbitControls/TransformControls hardware input and native window services are substituted. They cannot establish visual quality, accessibility, physical input behaviour or macOS file handling. Complete this checklist in the built app; record platform/build and observed outcomes separately.

| Flow | Expected result |
|---|---|
| App defaults → scene appearance → selected-file appearance → reset | Higher scopes take priority, resetting inherits; session edits do not rewrite app defaults; selection updates fields; file scope disables with All models selected. |
| Selected fit → All models fit → hidden selection | Fit/0 focuses the selected visible part, overview includes reference, hidden selection falls back; importing another file fits an overview. |
| File context menu → remove → remove last | Only the scene root unloads; original source file remains; menus close on Escape/outside input; selection and inspector recover. |
| Solid → edges → wireframe → X-ray with section/palette active | Source colors/maps and clipping survive; return to solid restores transparency/depth/wire flags; removal does not leave edge helpers. |
| Orthographic/perspective → seven views → fit/measure/screenshot | Apparent scale and Z-up orientation remain sensible; the active camera is shared by controls, transforms, labels and picking. |
| Native file → Open With / slicer → duplicate filenames | The selected native source is handed off; matching names do not confuse identities; unknown/unavailable sources report a useful error. |
| Print parameters → heuristic estimate → Bambu calculation → cancel/change selection | Heuristic and fixed-profile actual CLI estimates are labelled separately; changing material/model cancels stale work; no print job is sent; failure keeps heuristic available. |
| System language → explicit language → restart | Menus, settings, inspector, hints and errors follow the chosen language; unsupported system languages fall back to English; Arabic/Hebrew/Persian layout is mirrored; filenames stay unchanged. |
| Screenshot with dimensions and measurements | Saved PNG contains the 3D viewport and visible labels, at sharp display resolution; no sidebar/toolbar; cancel does not report success. Test native menu and camera button. |
| Empty app → open STL → inspect | Unavailable geometry tools disabled initially; file selected after import, STL badge on root, roots initially collapsed; expand reveals indented parts and survives rebuilds; file info and dimensions match the known fixture. |
| Open several files rapidly, then invalid/empty file | Valid files remain; error explains failed import; previous scene and selection survive; app stays responsive. |
| Inspector + collapse tree + select group | Tree collapse retains objects; group selection updates inspector and attached transform; root and component selection are distinguishable. |
| Measure → orbit/pan gesture → measure | Modified navigation gestures produce no measurement points; only deliberate unmodified surface clicks do. Escape cancels a pending point. |
| Measure → move/rotate/dock/change unit/hide/cut/explode | Old measurements disappear when geometry or pickable surfaces change; there are no floating stale markers. Transform and measuring input modes do not overlap. |
| Section → component palette → textures off/on | Cut remains active through all material changes; only the retained visible half is measurable. Verified closed meshes show filled cut faces with holes preserved; open/ambiguous meshes show contours only. No CAD geometry is exported. |
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

Section-cap regression check: use a closed cube, a closed ring with a hole and an open surface. Verify the cube cut is filled, the ring hole remains open and the open surface receives contours only. Change section axis/flip/position, hide parts, transform/explode, switch palette/textures/display mode and clear the section; cap/contour helpers must update or disappear without stale geometry and must not be selectable as model surfaces. This is a manual check to perform on the rebuilt candidate, not a record that it already passed.
