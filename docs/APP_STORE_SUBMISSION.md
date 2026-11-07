# App Store submission handoff

Status: **prepared review candidate, not submitted or approved**. Form is free; no accounts, advertising or in-app purchases are implemented.

## The correct build

Use the `AppStore` configuration, not the desktop `Release` preview. `FORM_APP_STORE` excludes external Bambu CLI execution and the Blender Python importer from the native binary. The bundled viewer, original-file handoff, geometric print estimate, screenshots and all other self-contained inspection features remain. The native capability handshake also hides the unavailable external calculation action.

Both configurations have been built as universal arm64/x86_64 previews. An ad-hoc signature is a local integrity signature and is not an Apple distribution identity. On the development Mac the check found valid Apple Development identities, but no suitable Developer ID Application or Apple/Mac App Distribution identity. Do not substitute a development certificate for production distribution.

`FORM_DEVELOPMENT_TEAM` and a valid account/distribution setup are required by `scripts/archive.sh`. That script selects `AppStore` and produces `distribution/Form-AppStore.xcarchive`. Before submission, validate the signed archive through Xcode Organizer/App Store Connect and resolve its actual findings.

## Publisher and App Store Connect

- Requested brand: **FDMwerk**; support: **support@fdmwerk.de**.
- Confirmed legal provider: **Christoph Kielhorn, sole proprietor trading as FDMwerk**. The publisher has confirmed an active Apple Developer membership; account type and team have not yet been verified.
- Verify the Apple account records, agreements and EU trader declaration. A GitHub organization does not establish an Apple organization account. Apple's permitted developer name depends on enrollment/account eligibility.
- Reserve/verify bundle ID **de.fdmwerk.form**, app name and SKU in the actual account. Current source version is **0.3.0**, build **4**; increase the build number for each uploaded replacement.
- Set price to free and choose the intended territories. Draft category: Graphics & Design.
- Complete the current age-rating, export-compliance and privacy questionnaires from actual behaviour. The source declares no non-exempt encryption; recheck the signed build and questionnaire before answering.
- Reviewer contact: Christoph Kielhorn. The supplied review telephone is retained locally for App Store Connect and excluded from the public repository/source archives.

## Listing and reviewer materials

- [German metadata](../distribution/APP_STORE_METADATA_DE.txt).
- [English review notes](../distribution/APP_STORE_REVIEW_NOTES_EN.txt).
- [Privacy policy](PRIVACY.md) and [public support](https://github.com/FDMwerk/Form/issues).
- Approved 1024px icon: [Form-Icon-1024.png](../distribution/Form-Icon-1024.png).
- Use screenshots of the final **AppStore** build and original demo geometry. The initial app size is 1280 × 800 points when the screen permits; 2560 × 1600 PNG captures meet one of Apple's Mac screenshot sizes. Capture the actual interface, not customer models or invented features. Final captures require an unlocked Mac and are a distinct remaining task when unavailable.
- Include clear examples of opening a model, hierarchy/visibility, measurements, sections, appearance and the optional geometric print estimate. Do not show the desktop-only Bambu calculation in Store marketing.

## Licenses and privacy

The original application source is MIT. Three.js, Lucide, fflate, occt-import-js, OCCT and model assets retain the licenses documented in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md). The source-package script includes the verified exact CAD-library source archives and their manifests. Retain source/rebuild rights and all notices for the actual distributed versions.

Apple's standard EULA contains an open-source-license exception; an LGPL component is not automatically prohibited solely by the existence of that EULA. Nevertheless review the actual distribution/EULA/DRM arrangement, corresponding-source availability and recipient modification/rebuild rights before release. This technical preparation does not certify the legal interpretation of a future submission.

The app includes a privacy manifest and app-local UserDefaults reason CA92.1. It uses non-persistent WebKit stores and bundled assets. No model upload, analytics or runtime AI service is implemented. Standard handoff occurs only when requested by the user; the receiving application's own behaviour is separate.

## Verification still needed before production

- Suitable Apple distribution identity, provisioning and actual signed-archive validation.
- Final publisher/account/trader data and live policy/support/marketing URLs.
- Final Store screenshots and manual VoiceOver/keyboard/physical-device checks.
- Actual Intel, minimum macOS 14 and MacBook compatibility/performance testing; a universal build is not evidence those systems were tested.
- Final dependency/license review and Apple's own review. No claim of App Store compliance certification or approval should be used in marketing before that outcome exists.

See [release readiness](RELEASE_READINESS.md), [verification](VERIFICATION.md), [manual QA](QA.md), [user guide](USER_GUIDE.md) and [developer guide](DEVELOPMENT.md).
