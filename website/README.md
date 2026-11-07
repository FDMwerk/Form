# Form product page

Finished static landing-page source for **https://fdmwerk.de/form/** on the existing FDMwerk WordPress site. Published on 2026-11-07 as WordPress page 1483. The live page was checked at desktop and 390px widths, with all images loaded, working screenshot tabs, canonical URL and search description.

- `index.html`: standalone responsive page; German copy, canonical/SEO/social metadata, SoftwareApplication structured data and local assets.
- `wordpress-fragment.html`: the same page content, scoped styles and screenshot-tab behavior for a WordPress Custom HTML block. No global body styles are included in the fragment.
- `assets/form-mark.png`: the approved transparent folded-F mark, copied from the app. `form-icon.png` remains the rounded favicon; the line icons are Lucide ISC assets, not custom drawings.
- Four actual UI captures from **actual Desktop and Store review bundles** are supplied by the main release task (the two section images were refreshed from Build 7 with filled section faces): `assets/form-overview.png` and `assets/form-section.png` show the hero model; `assets/form-parts.png` shows a different colored GLB assembly in the first feature card; `assets/form-measure.png` shows a different model with dimensions/section in the second card. No placeholder fallback or generated screenshot is used. The hero crops only the reserved OS sharing/titlebar strip through presentation CSS (`aspect-ratio: 5/3`, `translateY(-4%)`); the original screenshot files remain untouched. The browser-style frame is decorative; Form is a native Mac app, not a web application.
- The verified App Store Connect app record is **6831972349**, named **Form – CAD Viewer**. The preparation CTA and header icon link to `https://apps.apple.com/app/id6831972349`. The public listing is not yet live; “Bald im Mac App Store” and the link titles explicitly communicate preparation, not download availability or Apple approval. No official App Store badge is used. There are no GitHub binary or preview-release links. GitHub links lead to source code and documentation. Store binaries and test packages remain local until a real authorized release. The voluntary Donate link opens PayPal; this page contains no embedded payment widget.
- No external fonts, analytics, trackers or page-created cookies. Existing WordPress/theme services remain a separate deployment concern.

## WordPress deployment

1. Create or update the page with the **`form`** slug, using a blank/canvas, full-width template. Disable duplicate theme page title/header/footer for this page if the chosen template permits it. Preserve other pages and site settings.
2. Upload the files in `assets/` to the site's media storage or a page-specific static directory. Rewrite **every** `assets/` URL in the fragment, including CSS/HTML and JavaScript tab sources, to the resulting public base URL. If serving the whole directory directly at `/form/`, the existing relative URLs work without rewriting.
3. Add the fragment with an account permitted to retain its scoped `<style>` and `<script>`. If WordPress strips scripts, enqueue this exact behavior through the site's existing asset system; the initial screenshot and all links remain usable without it.
4. Use the title and description from `index.html` in the site's SEO settings, canonical `https://fdmwerk.de/form/`, and update the social-image URL to the actual hosted asset. The fragment deliberately does not duplicate document-head SEO tags.
5. Check 390px/1280px layouts, both screenshot tabs, keyboard focus, screenshot loading, the Store preparation links, GitHub, Donate and all legal/support links on the actual public URL. No publication or domain change is performed by merely preparing these files.

The page uses only original Form screenshots/branding plus Lucide assets. See the repository's third-party notices for their license.

## Current live deployment

`deployment.json` records the public asset mapping. WordPress converts the four screenshot PNG uploads to JPEG; the untouched PNG originals remain in this repository. The page uses a Custom HTML block (`<!-- wp:html -->`) to prevent automatic paragraph insertion. Its additional layout overrides are scoped to `body.page-id-1483` and hide only this page’s theme header/footer. The theme and all other pages remain unchanged. The standalone page does not need those overrides.
