# Form product page

Static, dependency-free product page intended for `https://fdmwerk.de/form-3dviewer/`.

- `index.html`: standalone page, responsive styles, SEO title/description/canonical and SoftwareApplication structured data.
- `assets`: original Form imagery and Lucide ISC icons. See the repository's asset/license notices.
- No cookies, analytics, external fonts or visitor data collection are introduced by this page.
- Downloads link to the repository's Releases page; do not claim App Store availability or notarization before they actually exist.

For the existing WordPress site, upload the assets to its media library, replace asset URLs with those returned by WordPress, and insert the body fragment plus scoped CSS into a Custom HTML block. Use the slug `form-3dviewer`, a blank/canvas template if available, and the page title/description from `index.html`. Preserve the site's existing pages and navigation. Verify the public URL, mobile layout, download links and legal links after publishing. WordPress/theme analytics or cookies are separate from this static page and must be reviewed within the existing site's setup.

The source page is a release artifact, not proof that the custom-domain page has already been published. Record the actual deployment result in the release notes.
