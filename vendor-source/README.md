# Exact third-party corresponding sources

These two unchanged upstream source archives are included in Form's **source-only** repository so their availability does not depend on a draft application release. They are not Form applications, previews, installers or signing material. Their revision-addressed filenames must retain these exact bytes.

| Archive | Upstream revision | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `occt-import-js-c2148e5.tar.gz` | `c2148e54b456b571238d35cac037d304053d64b2` | 4399573 | `2bd3799b2ac56cbf3f0df6300a51c8890e137bd001462702b356f621e33ff192` |
| `OCCT-d2abb6d.tar.gz` | `d2abb6d844231cb8f29be6894440874a4700e4a5` | 48218968 | `2715d89a1bc44dfd34dab88f729c445ea93f6b57d6539b0c89614a80ae144a6c` |

Public repository-hosted immutable downloads, verified without authentication at commit `f16823fa15c7a84e09c0824e1b738033afde0a3a` on 2026-11-07:

- [Importer sources](https://raw.githubusercontent.com/FDMwerk/Form/f16823fa15c7a84e09c0824e1b738033afde0a3a/vendor-source/occt-import-js-c2148e5.tar.gz)
- [OCCT sources](https://raw.githubusercontent.com/FDMwerk/Form/f16823fa15c7a84e09c0824e1b738033afde0a3a/vendor-source/OCCT-d2abb6d.tar.gz)
- [Manifest](https://raw.githubusercontent.com/FDMwerk/Form/f16823fa15c7a84e09c0824e1b738033afde0a3a/vendor-source/manifest.json)

The links above are pinned to the published source commit rather than mutable `main`. Both archive downloads matched the manifest’s full byte counts and SHA-256 hashes; the manifest itself also matched. Keep the old files when adding a new upstream revision. `npm run vendor:sources` verifies hashes and lengths and refuses changed archives.

The importer's upstream source tree includes its own generated `dist/occt-import-js.wasm`. This is the dependency library, not a Form app. Its SHA-256 is `33391fc9d94ea5c869a6718488bf0a9a464222bac9bdc764dfe1690cef281952`; it was byte-for-byte equal to the pinned NPM runtime used by Form when checked. Retaining the unchanged upstream tarball preserves source/build provenance and the manifest digest.

Extract the importer and OCCT archives, populate the importer's `occt` submodule directory from the pinned OCCT tree, and follow the included importer build scripts/toolchain instructions. Preserve LGPL 2.1 and the applicable OCCT exception. See [replacement/rebuild instructions](../THIRD_PARTY_NOTICES.md#replacement-and-rebuild) and [publication/verification checklist](../docs/CORRESPONDING_SOURCE.md). A tested custom-library rebuild is still a separate release check; matching archive hashes alone do not prove it.

No private review records, credentials or application packages belong here. The ignore rules allow only these archives, their manifest and this README. The source packager includes this directory once and suppresses macOS AppleDouble metadata.
