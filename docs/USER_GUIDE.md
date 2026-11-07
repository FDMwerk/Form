# Form user guide

Form is a free, local macOS viewer for CAD and mesh files. It opens models for inspection; it does not save edited CAD geometry or persistent assemblies. The preview requires macOS 14 or later.

## Open and select

Use **Open model**, ⌘O, Finder document opening, or drag files into the viewport. Multiple imports append to the scene. Supported extensions are STEP/STP, IGES/IGS, BREP/BRP, STL, OBJ, PLY, 3MF, GLB and self-contained glTF. Files are limited to 250 MB each. A rejected import leaves the existing scene in place.

The left tree initially shows collapsed file roots, each with a format badge. Expand a root to inspect groups and parts. Select a row, or double-click visible model geometry, to select a part. Select **All models** for the complete scene. Eye buttons hide/show parts and groups; a hidden ancestor also hides its children. Right-click a file root to remove that whole file from the scene. This does not delete the original file.

The information button opens the inspector with file type, size, triangle count, bounds, position and mesh volume. File units supplied by CAD, 3MF and glTF are respected. STL/OBJ/PLY start in millimetres; choose another unit in the inspector/footer when the source used a different unit. glTF metre coordinates are converted to millimetres.

## Navigate and display

The default Bambu-style mouse mapping uses left drag to orbit, right/middle drag to pan and the wheel to zoom. App Settings includes Fusion, Blender, SOLIDWORKS and Onshape mappings, adjustable speeds, reverse zoom and trackpad mode. Profiles reproduce basic gestures; unusual CAD gestures and hardware-driver features can differ.

The fit button and **0** focus the selected visible file/group/part. With **All models** selected, they fit the whole scene and enabled reference apple. A hidden selection falls back to the visible scene. New imports automatically use an overview fit so appended files remain discoverable.

The initial view is orthographic with edges. The small display menu at the upper left changes solid, solid-with-edges, wireframe and X-ray rendering. It also switches perspective/orthographic projection. The view cube at the upper right follows camera orientation; click a face for front/back/left/right/top/bottom, an edge for a 45-degree view, a corner for a spatial view, or Home for isometric. The faces show their signed X/Y/Z axes. Fit retains the chosen projection and viewing direction. The adjacent background icon offers light, dark and warm backgrounds, a custom color and a grid toggle. Background color and grid visibility are stored locally for future launches; app-default reset restores the light background and visible grid. The fine grid and reference apple also have separate bottom buttons. The apple's largest outer dimension is 80 mm; it is a visual scale reference, not a calibration object.

## Colors and settings

Original supported material colors, vertex colors and embedded textures are retained. CAD face colors become material groups. The default color applies to geometry without a source color. OBJ companion MTL/texture files and external glTF dependencies are not resolved; export a self-contained textured GLB where practical.

Settings have three levels, in priority order:

1. **App Settings** in the lower left stores defaults, language and navigation locally for future launches.
2. **Scene and file appearance** in the header changes the current scene for this session.
3. Choose **Selected file** in that panel to override only the selected file, including its nested parts.

File appearance takes priority over scene appearance, which takes priority over app defaults. **Use inherited settings** clears the current scope's overrides. The bottom palette button changes the scene's distinct-part-color setting; it does not rewrite app defaults. File overrides may still take priority. Turning overrides off restores original materials and textures.

Form follows the system language unless an explicit language is selected in App Settings. Menus and interface have 41 bundled languages, including RTL layout for Arabic, Hebrew and Persian. Filenames and source part names are preserved. Third-party license text retains its authoritative source language.

## Measure, move and inspect sections

**Outer dimensions** displays the scene's bounding width, depth and height in mm. **Measure** places two deliberate surface clicks to show their straight-line distance. Modified navigation gestures do not place points. Escape exits measuring. Measurements use the display triangles, with no analytic CAD snapping or tolerance certification. Moving/scaling/hiding geometry, changing sections or exploding clears obsolete measurements.

Translation/rotation tools attach a gizmo to the selected object or group. The inspector also accepts world coordinates. **Dock** aligns outer bounding faces against another object; it does not create persistent CAD constraints. **Undo** or ⌘Z reverses supported positioning actions. There is no redo or saved assembly project in this preview.

**Exploded view** temporarily spreads multiple parts/files around their original assembly positions. Returning its slider to zero restores those positions. Moving/docking starts from assembled positions rather than baking an exploded layout into the operation.

**Section** offers three plane buttons, a position slider and a reverse button. It clips the display and measurement picking. Orange contours highlight the actual triangle/plane intersection on visible parts and follow transforms, explosion and plane changes. These contours are display helpers and cannot be picked or measured. For verified closed meshes, cut faces are filled and holes remain open. Open or ambiguous meshes show contours only. Caps and contours are display helpers, not new CAD solids or exported geometry. Colors and display modes preserve the active clipping plane.

## Volume and 3D printing

Volume is calculated from the current visible display mesh and shown in cm³. A closed, consistently wound mesh is required. Multiple mesh volumes are added; overlaps are counted more than once. Self-intersections are not detected. Treat this as inspection data rather than certified CAD volume.

If a supported slicer is installed, a printer icon beside Open with opens the dedicated **3D printing** sidebar. The geometric estimate accepts generic PLA/PETG/ABS/ASA/TPU/PA/PC profiles plus layer height, infill, walls, nozzle, speed and flow. Profiles are editable starting assumptions. The displayed range is a heuristic, not a calibrated sliced toolpath or guaranteed bound. It does not simulate supports, heat-up, acceleration, exact infill paths or every printer feature.

In the desktop build only, with Bambu Studio installed, a separately labelled calculation can run its local CLI for an original STL opened through the native file picker/Finder. It uses the stated **A1 mini, 0.4-mm nozzle, 0.2-mm layers, 15% infill** profile and PLA/PETG. This calculation uses the original STL and its chosen unit scale; viewport rotation and the geometric-estimate fields above it are not applied. It produces a slicer's estimated time/material, not a measured print duration. Selection/material/unit changes cancel stale calculations. It sends no print job and requires no cloud service.

The first entry in **Open with…** opens fdmwerk.de to request a printed part; it does not upload or transmit the model. Installed applications follow with their original app icons. **Open in slicer** or the header's **Open with…** hands the original file to a compatible installed application. The original file must still be available. Browser-style drag imports without a native source identity cannot use this handoff; reopen them with the file picker. In the desktop build, Blender mesh handoff uses a generated local import adapter where supported. The AppStore build excludes that adapter and Blender entries that require it. Native CAD formats are not converted to Blender meshes by that adapter.

## Screenshots and shortcuts

The camera button or ⇧⌘S saves a PNG of the viewport with visible measurement/dimension labels. Sidebars, menus and toolbars are excluded. Choose a destination in the native save dialog; cancel leaves no saved result.

| Shortcut | Action |
|---|---|
| ⌘O | Open models |
| ⌘, | App Settings |
| 0 | Fit selection or all models |
| Escape | Exit active measuring/transform mode and close transient panels |
| ⌘Z | Undo supported positioning actions |
| ⇧⌘S | Save viewport screenshot |

Viewport shortcuts ignore editable controls. Scene transforms, scoped appearance and inspection state are session-only. Test representative files and your mouse/trackpad before depending on a preview workflow; see [verification evidence](VERIFICATION.md) for automated checks and remaining platform/UI validation.

## Support Form

The desktop/GitHub edition includes an optional Donate button that opens PayPal in the browser for christoph@moinwerk.com. No payment is processed inside Form and no features require a contribution. The App Store build excludes this external payment action. Privacy & Licenses and Settings use matching sidebar rows with accessible icons.

**Request a feature** in the sidebar offers an email draft to support@fdmwerk.de or the GitHub feature-request form. Form does not send the request, attach models, or collect diagnostics automatically.
