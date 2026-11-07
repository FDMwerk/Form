# Third-party components

- Three.js, pinned in package-lock.json — MIT. https://github.com/mrdoob/three.js
- Lucide, pinned in package-lock.json — ISC. All toolbar symbols come from Lucide. Form's approved folded-F app icon is an original generated asset; see design/APP_ICON.md. https://github.com/lucide-icons/lucide
- fflate 0.8.3 (bundled by Three.js 3MF loader) — MIT. https://github.com/101arrowz/fflate
- occt-import-js 0.0.23 — LGPL 2.1. NPM source gitHead c2148e54b456b571238d35cac037d304053d64b2. https://github.com/kovacsv/occt-import-js/tree/c2148e54b456b571238d35cac037d304053d64b2
- Open CASCADE compiled into the separate occt-import-js WASM binary — LGPL 2.1 with OCCT's applicable additional exception. Exact submodule revision: d2abb6d844231cb8f29be6894440874a4700e4a5. Exact source archives and SHA256 checksums are acquired in the separate vendor-source release package. Upstream OCCT licenses and all required source archives must accompany the release source distribution.

Full installed license texts live in Resources/Web/licenses and are accessible in-app under Datenschutz & Lizenzen. Build tools (esbuild, Sharp, glTF Transform, meshoptimizer) are not shipped as app executables; their pinned licenses remain in their NPM distributions.

## Replacement and rebuild

The CAD loader is deliberately shipped separately as `occt.js` and `wasm.js`. The WASM payload is base64 encoded, not encrypted or DRM-protected by Form. Replace `node_modules/occt-import-js/dist/occt-import-js.js` and `.wasm` with a modified build, then run `npm run build` and rebuild/re-sign the app with Xcode. Modification and reverse engineering for debugging changes to the LGPL components are not prohibited by Form's license.

**Release gate:** confirm the complete corresponding source of the exact distributed WASM (including submodule revision/build tools and OCCT exception) is packaged and reachable. Confirm App Store distribution terms do not remove recipients' LGPL rights. Merely linking to the current upstream repository is not treated as completion of this obligation.

## Reference apple

Generated for this project using Tripo Studio, Pro account verified in the account UI on 2026-11-07. Apple geometry + 4K texture cost 50 credits. The earlier, superseded banana used 50 credits; 100 credits total were used from the authorized 300-credit budget. Asset ID: 0f0757df-9396-47f8-b9d8-760b9294bf8a. No customer models were uploaded. Prompt describes one ordinary unbranded apple. The export is optimized with glTF Transform / meshoptimizer, preserving the supplied texture.

Tripo paid-user output terms: https://www.tripo3d.ai/terms section 5.2.2; commercial rights help: https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially . Archive evidence of Pro status and the applicable terms with the release records. The original Tripo export stays outside the source repository.

The reference asset is offered with Form under CC BY 4.0 to the extent the publisher holds licensable rights. Attribution: “Reference apple — FDMwerk, generated with Tripo AI; optimized for Form.” License: https://creativecommons.org/licenses/by/4.0/ . It is a visual reference, not a calibrated measurement standard. AI generation is not a warranty of copyright protection or non-infringement.
