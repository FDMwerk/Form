<img src="Resources/FormIconMaster.png" width="96" alt="Form folded-F app icon">

# Form — Free CAD, STEP & STL Viewer for macOS

**Open 3D models locally. Inspect the shape, hide parts, measure, and get back to work.**

Form is a free, open-source CAD viewer for Mac with a quiet interface, a fading grid and a collapsible assembly tree. It opens STEP, IGES, BREP, STL, OBJ, PLY, 3MF and self-contained glTF/GLB files without uploading your models.

**Preview 0.3.0.** The source is available here; this version has not been released or approved in the Mac App Store. Public signed/notarized application downloads are not available yet. You can build it with Xcode using the instructions below.

[Controls](docs/CONTROLS.md) · [Privacy](docs/PRIVACY.md) · [Release readiness](docs/RELEASE_READINESS.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)

## Features

- Open several CAD files, meshes or assemblies together; inspect their component hierarchy and file-type badges.
- Orbit, pan, zoom, fit to view and hide/show individual parts or groups.
- Use familiar basic mouse profiles for Bambu Studio, Autodesk Fusion 360, Blender, SOLIDWORKS and Onshape, plus optional trackpad controls.
- Preserve original material colors, CAD face colors, vertex colors and supported embedded textures. Choose a fallback color or switch to different component colors.
- Inspect file information, overall dimensions and two-point surface measurements in millimetres.
- Translate and rotate components or groups with handles and numeric world positions.
- Align outer bounding faces, undo transformations and create a reversible exploded view.
- Move a planar clipping section through the model.
- View models with studio lighting, smoother STL surfaces and ground shadows.
- Toggle a textured apple size reference, normalized to an 80 mm maximum bounding dimension.
- Work without an account, advertising, analytics, model uploads or runtime AI services. Preference settings are saved locally.

## File formats

| Type | Extensions | Notes |
|---|---|---|
| CAD exchange | `.step`, `.stp`, `.iges`, `.igs` | CAD geometry is tessellated for display; names, hierarchy and colors are retained where the importer supplies them. |
| Open CASCADE BREP | `.brep`, `.brp` | Local geometry import. BREP has no reliable universal unit declaration; verify your source units. |
| Triangle meshes | `.stl`, `.obj`, `.ply` | Unitless files default to mm. Select the correct per-file unit; OBJ/PLY vertex colors are supported. |
| 3D printing | `.3mf` | Mesh/component display and supported material/texture data; source units are normalized to mm. Slicer settings and toolpaths are not a slicer workspace. |
| 3D scenes | `.gltf`, `.glb` | Self-contained/embedded resources. glTF metre units are converted to mm. |

Native proprietary CAD formats such as SolidWorks, CATIA or Parasolid are not imported. External OBJ material/texture files, external glTF dependencies and Draco-compressed geometry are not resolved in this preview. Export a self-contained supported file from the originating tool.

## Important limits

Measurements use display triangles rather than exact CAD topology. Validate manufacturing-critical dimensions in the original CAD system. The apple is a visual size reference, not a measurement standard.

Docking aligns axis-aligned bounding faces and centres the other two axes. It creates no persistent mates, constraints or collision checks. Sections are uncapped display clipping and do not produce new exportable solids. Explosions are reversible visual offsets. Scene transforms and measurements last for the current session; scene save/export is not implemented. Original files are read-only.

CAD triangulation currently runs synchronously, so large imports may temporarily pause interaction. Native file opening has a 250 MB per-file guard. This is not a guarantee of memory use or a malformed-file security certification.

## Build with Xcode

Requires macOS 14 or later, Xcode, **Node.js 22.12+** and XcodeGen. The application is a universal Intel/Apple Silicon binary when built with both architectures below. No API keys, Tripo account, paid service or AI generation is needed to build or run it.

```sh
npm ci
npm test
npm run build
npm run icon
xcodegen generate
xcodebuild -project Form.xcodeproj -scheme Form -configuration Release \
  -derivedDataPath build ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
open build/Build/Products/Release/Form.app
```

Ad-hoc signing is the local preview default. Public macOS distribution needs the publisher's valid signing/notarization setup; App Store distribution needs valid App Store signing and Apple's review. Do not bypass Gatekeeper or disable system protections to distribute the app.

## Languages

Form follows your Mac’s language by default, with a manual language choice in Settings. The interface and native menus include 41 languages; Arabic, Hebrew and Persian use a right-to-left layout. Translation catalogs are bundled locally. Filenames and source part names are preserved.

## Tests and release sources

`npm test` compiles and tests native file/queue/preferences policies on macOS and checks navigation gestures, original OBJ/PLY/glTF/GLB/3MF fixtures, known dimensions, original colors, 3MF unit normalization, STL normals and the bundled textured reference asset. It also runs the actual viewer source through 12 interaction scenarios covering mode changes, invalid imports, sections and appearance, visibility, explosion/docking/undo, preferences and last-file cleanup. Locale catalog completeness, language switching and screenshot composition are covered as well. These tests do not replace real-device UI, performance or compatibility tests. Original format fixtures are in `tests/fixtures`; see [verification details](docs/VERIFICATION.md) and the [manual app checklist](docs/QA.md).

```sh
# Obtain and verify exact CAD-library sources, then test pinned CAD fixtures:
npm run test:cad

# After committing the final release tree, create an archive with project source
# plus the verified CAD importer and OCCT corresponding-source archives:
npm run package:source
```

Downloaded library source archives remain in `vendor-source/`, outside the normal Git tree. Their pinned commits and SHA256 hashes are in `vendor-source-manifest.json`. Attach the corresponding-source package to any binary release and retain the LGPL replacement/rebuild instructions. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License and support

Form's original application code is **MIT licensed**. Bundled libraries keep their own licenses; the apple reference is separately attributed under CC BY 4.0 to the extent the publisher holds licensable rights. The approved folded-F icon is an original generated asset; toolbar icons are Lucide.

Published by [FDMwerk](https://github.com/FDMwerk). Support: **support@fdmwerk.de**. Use [Issues](https://github.com/FDMwerk/Form/issues) for reproducible bugs and feature requests. Do not attach confidential customer models or credentials to public issues.

## Deutsch

**Form ist ein kostenloser CAD-, STEP- und STL-Viewer für den Mac.** Öffne CAD-Dateien, Baugruppen und 3D-Druckmodelle lokal, drehe sie frei, blende einzelne Bauteile aus und prüfe Maße oder Schnittansichten. Eine reduzierte Oberfläche, vertraute Steuerungsprofile und eine übersichtliche Baumstruktur helfen beim schnellen Prüfen von 3D-Modellen.

Der eigene Anwendungscode ist unter MIT frei verfügbar. Die aktuelle Version ist eine Vorschau; eine Freigabe im Mac App Store steht noch aus. Form ist ein Viewer mit Anordnungswerkzeugen, keine parametrische CAD-Konstruktion.
