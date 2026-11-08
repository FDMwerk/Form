# Store media typeface

`Manrope-Variable.ttf` is the unmodified Manrope variable font from the Google Fonts repository, licensed under SIL Open Font License 1.1. The full copyright and license notice is included in `OFL-Manrope.txt`.

Sources:
- https://github.com/google/fonts/tree/main/ofl/manrope
- https://github.com/google/fonts/blob/main/ofl/manrope/OFL.txt

The compositor registers this font only for its image-rendering process; it does not install a system font or add it to Form's runtime bundle.

Apple bezels are not bundled here or granted any rights by Form's MIT license. Obtain the official resource and publisher license authorization separately, keep the original private, and point the private composition manifest to it. The script never synthesizes Apple hardware. Only the source screenshot inside the designated screen opening is composed; the official bezel is resized proportionally without added shadow, recoloring, cropping or tilt.

FDMwerk V7 palette and typography were read from the active brand guide and its authored source. Brand artwork, model screenshots and third-party model credits remain independently governed; no rights to a customer's model are implied.

The final cropped-screen layout uses `presentation: "generic-screen"`: a plain rounded software-display border with no Apple logo, notch, chassis or other Apple hardware details. It does not read or modify Apple device artwork. Existing Lucide object icons provide the decorative motifs; their bundled ISC notice is under `Resources/Web/licenses/lucide.txt`. Real screenshots are supplied separately in a private manifest. Marketing captures and third-party demo meshes are not distributed by this source script.

Run `node scripts/store-media.mjs --example` for the manifest shape, or `node scripts/store-media.mjs --prepare private-manifest.json` for layout studies. The output is local only; the compositor performs no publishing. Source image hashes and a composition report accompany final renders.
