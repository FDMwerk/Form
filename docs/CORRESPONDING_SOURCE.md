# Corresponding-source publication and retention

The exact dependency archives are now publicly hosted in the source-only repository at commit `f16823fa15c7a84e09c0824e1b738033afde0a3a` and were anonymously downloaded and hash-verified. This document also records the remaining final-wrapper/rebuild checks. It preserves the current channel restriction: GitHub may contain application/dependency source and original source assets, but no installable Form application, preview, DMG/ZIP/PKG or Xcode archive. No publishing action is authorized by this document.

## Evidence checked on 2026-11-07

- `vendor-source-manifest.json` pins occt-import-js **0.0.23**, importer commit `c2148e54b456b571238d35cac037d304053d64b2`, and OCCT commit `d2abb6d844231cb8f29be6894440874a4700e4a5`.
- The two local dependency archives match both the byte counts and SHA-256 digests in that manifest. They total approximately 53 MB. The two archives, `manifest.json` and `README.md` are explicitly allowlisted under `vendor-source/` for source-only Git hosting; other local contents remain ignored. Public commit `f16823fa15c7a84e09c0824e1b738033afde0a3a` now contains them; anonymous archive downloads and the manifest were verified successfully.
- The existing local `Form-0.3.0-source.tar.gz` identifies application commit `71a0437e29fb5184f610e7aa9658be147ed57003` in `SOURCE_RELEASE.json` and contains both pinned dependency archives. It does **not** represent later uncommitted source changes.
- The immutable raw URLs linked in [vendor-source/README.md](../vendor-source/README.md) returned HTTP 200. Downloaded sizes were **4399573** and **48218968** bytes, and both SHA-256 digests exactly matched the manifest. Full-commit URL HEAD checks also returned 200 for both archives and the manifest.
- The former public source URL under the withdrawn `v0.3.0-preview` release returned **HTTP 404** during an unauthenticated HEAD check. Making that whole release a draft also removed public access to its source archive. A draft release, local file, private authenticated download or Actions artifact is not a durable public corresponding-source location.
- No tracked app/installable/signing files were found in the examined Git tree. The local source tarball contained AppleDouble `._` metadata entries, which should be excluded from new source packages. Do not publish private review contacts, local withdrawal records, credentials or Finder metadata.

## Prepare the final source package

1. Commit the intended audited source tree, including new source/tests/docs. The packager uses `git archive HEAD`; untracked files are not included. Its dirty check covers tracked changes, not a guarantee that every intended new source file was committed.
2. Run `npm run vendor:sources`. Verify the exact pinned archives against the checked-in manifest. Preserve their upstream license files, applicable OCCT exception and importer build scripts/submodule revision.
3. Run `npm run package:source` from the clean committed tree. The output is a source tarball, not an application download. The source packager now uses `COPYFILE_DISABLE=1` for final `tar`, copies only the manifest-listed archives and manifest, and includes the tracked `vendor-source` directory once. Inspect the resulting entry list before publication.
4. Record the application commit, version, archive SHA-256 and dependency manifest. For public retention, give the artifact an immutable commit-specific name such as `Form-0.3.0-source-<commit>.tar.gz`; do not replace an older archive in place with different source merely because the marketing version stayed the same.
5. Verify the archive contains the matching application source, native and viewer build configuration, lockfile, dependency source archives, complete notices and practical importer/WASM replacement/rebuild instructions. The upstream source commits alone do not demonstrate that a modified dependency has been rebuilt and successfully used by Form; record that test before claiming a validated replacement workflow.

## Durable source-only hosting

The implemented primary location is the **source-only repository itself**: see [the exact archives and download URLs](../vendor-source/README.md). Both files are under [GitHub’s 100 MiB per-file limit](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github); they are unchanged upstream source archives, not installable Form packages. Use commit-pinned raw URLs after the reviewed commit is public, and retain old revision-named files. A distinct source-only release/tag can additionally host a complete wrapper source package, but is not required just to make these dependency sources independently reachable. Do not republish the withdrawn preview or attach an app binary in order to restore source access. A source-only release may contain the source tarball, manifest/checksums and license/rebuild information; its description must say it contains source and no application downloads.

Retain the source package for the earlier actually distributed preview independently of the final Store package. Its earlier application commit `71a0437e29fb5184f610e7aa9658be147ed57003` remains part of repository history; both dependency revisions are now reachable independently of that withdrawn binary release. Withdrawing its binary does not make it safe to discard the exact source/provenance needed by people who already received it. The final Store candidate needs its own package tied to that candidate's commit and dependency payload. Preserve old immutable source artifacts instead of silently updating them.

After source-only publication:

- Verify the exact archive and checksum URLs without GitHub authentication; download and hash them independently.
- Record the public URL, application commit, digest and publication date in the release evidence. Link it from the Store's source/notices information and the repository's third-party notices.
- Test the documented rebuild/replacement path from that downloaded package. Include instructions for re-signing a modified local Mac app without requiring the publisher's private key or instructing users to disable system protection.
- Retain equivalent public access to the matching sources while distributing the corresponding application and preserve obligations to existing recipients. If a written-offer route is chosen instead, review its separate LGPL 2.1 section 6 requirements, including its minimum three-year offer period; this checklist does not silently substitute such an offer.

## Rights assessment

The bundled LGPL 2.1 text, especially section 6, requires notices and appropriate modification/relinking rights. Form's MIT application license and separate importer resources help support those rights but do not alone prove complete corresponding source or Store compliance. Apple's [Standard EULA section (a)](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) includes an exception for permissions supplied by open-source component licenses. Its [Developer Program agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) still requires applicable FOSS compliance and compatibility with signing/content-protection provisions. Evaluate the actual final distribution and replacement process; neither a blanket LGPL prohibition nor automatic compliance is assumed.

See [third-party notices](../THIRD_PARTY_NOTICES.md), [development instructions](DEVELOPMENT.md), [submission handoff](APP_STORE_SUBMISSION.md) and [readiness](RELEASE_READINESS.md).
