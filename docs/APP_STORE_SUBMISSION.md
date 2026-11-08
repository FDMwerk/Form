# App Store submission handoff

Status: **Build 9 is the current locally tested and signed candidate. Apple validation is recorded for Build 7 only; no binary upload, review submission or approval is claimed**. Form is free, with no account, advertising, subscriptions or in-app purchases. This review does not certify App Store acceptance.

## Verified publisher and distribution policy

The Apple Developer portal was inspected in the current working session: **Individual membership, Christoph Kielhorn, Team D5VE86DJ5H**, with renewal date **2027-08-05**. FDMwerk is the product/publisher brand; support is **support@fdmwerk.de**. The Individual account's legal seller is Christoph Kielhorn. Do not promise FDMwerk as an organization seller or silently create/convert an Apple organization account. Apple's [enrollment](https://developer.apple.com/help/account/membership/program-enrollment/) and [developer-name rules](https://developer.apple.com/help/app-store-connect/create-an-app-record/set-your-developer-name) apply.

**GitHub is source-only. Neither App Store binaries nor desktop preview binaries may be uploaded to the repository, GitHub Releases, Git LFS, Actions artifacts or other GitHub download channels.** This includes installable application ZIP/DMG/PKG files, `.app` bundles and `.xcarchive` archives. Corresponding-source archives, build scripts, notices and original source assets remain part of the source distribution. Keep signing identities, keys, profiles and private reviewer contact data out of source packages.

The previously public preview has been returned to a non-public draft by the session owner. This is not authorization to publish another release. Confirm removal of old public binary links/assets before describing downloads as withdrawn. App Store delivery belongs in Apple's distribution workflow; local test artifacts remain local unless a separate permitted channel is explicitly authorized.

## The correct build

Use configuration **AppStore**, not desktop **Release**. `FORM_APP_STORE` removes the external Bambu CLI runner, Blender Python import adapter and native PayPal donation URL/action. Native capabilities default to false in the viewer and keep those unavailable actions hidden. Standard original-file handoff, self-contained model inspection, labelled geometric print estimates and screenshot export remain. No external engine, Python interpreter or executable code is downloaded. A read-only scan of the existing AppStore executable found none of the Blender factory-reset script marker, Bambu CLI launch/settings markers, PayPal host or desktop donation recipient. Recheck the final archive rather than relying on this local-product scan.

`project.yml` currently defaults to local ad-hoc signing. `scripts/archive.sh` explicitly selects AppStore, requests Apple Distribution signing and requires `FORM_DEVELOPMENT_TEAM`; the verified value is `D5VE86DJ5H`. Do not run it as a substitute for establishing the correct distribution credentials. The authorized session owner subsequently created the required signing/installer assets and completed local archive/export. No private signing material is placed in source. No Apple upload, server validation, submission or approval is established by those local results.

## Signed-candidate evidence — local checks 2026-11-07, validation 2026-11-08

| Evidence | Current result | Remaining step |
| --- | --- | --- |
| Verified account/team | Individual / Christoph Kielhorn / `D5VE86DJ5H` | Keep legal seller and trader details accurate. |
| New AppStore archive | Archive log ends with `ARCHIVE SUCCEEDED`; archived app is `0.3.0 (7)`, x86_64 and arm64, with `TeamIdentifier=D5VE86DJ5H`. | Preserve exact archive/source provenance. |
| Strict actual-bundle verification | `codesign --verify --deep --strict --all-architectures` succeeds. | Recheck the actual exported installer and app after export. |
| Signed archive entitlements | Sandbox enabled; `get-task-allow` absent/false. | Confirm the submitted candidate is this production flavor. |
| Local export/package | Log ends with `EXPORT SUCCEEDED`; exported Form.pkg signature independently verified through the 3rd Party Mac Developer Installer/WWDR/Apple Root chain for D5VE86DJ5H. Expired account-session warnings belonged to an earlier export; they are historical rather than evidence that the new build 7 export failed. | The user reauthenticated and exact Build 7 passed actual Organizer validation on 8 November. Binary upload remains pending. |

Earlier ad-hoc local products failed because of metadata and carried debug task access. They are historical findings, not the status of the new signed archive. Local signing/export is not Apple server validation, App Store upload, review approval, notarization or a public release. No new direct binary publication is authorized here.

The marketing page **https://fdmwerk.de/form/** is live and its four actual screenshots/SEO were verified by the session owner. The Store destination remains explicitly labelled in preparation.

## Submission fields still to complete

- The session owner verified the created Mac app record **6831972349**, named **Form – CAD Viewer**, for bundle ID **de.fdmwerk.form**. Its intended public link is https://apps.apple.com/app/id6831972349; a created record does not mean the listing is live or approved. Confirm the remaining SKU/app-information fields in that actual record.
- Confirm current agreements, banking/tax requirements if applicable, EU trader status and required trader/contact information. Do not copy private review telephone/address data into the public repository.
- Set free pricing, intended territories and category; the prepared category is Graphics & Design.
- Complete the current age-rating, export-compliance and privacy questionnaires for the actual Store binary. Source declares no non-exempt encryption; final answers still require review of the uploaded build and included dependencies.
- Review [German metadata](../distribution/APP_STORE_METADATA_DE.txt) and [English reviewer notes](../distribution/APP_STORE_REVIEW_NOTES_EN.txt), live support/privacy/marketing URLs and final screenshots. Capture the **AppStore** interface with owned demo models; do not show desktop-only Bambu CLI or donation controls.

## Privacy, services and source licenses

Models are parsed locally, original files are not rewritten, and no telemetry, account backend or runtime AI service is implemented. The native bridge accepts only the bundled main document; WebKit storage is non-persistent. The privacy manifest declares app-local UserDefaults reason CA92.1, no tracking and no collected data types. User-selected write access is for explicit PNG saves. The network-client entitlement is retained for WKWebView operation; it is not evidence of model upload.

Feature requests open the user's email client or a public GitHub issue composer; the app does not submit a message or attach a model automatically. The optional physical-print-service action opens the public FDMwerk website without uploading the selected model. Review the actual website, receiving services and voluntary support handling when answering Apple's [app privacy questions](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/). A local-only parser alone does not settle every downstream support/privacy disclosure.

Donation is unavailable in the Store build. The external physical-goods link is distinct from payment for digital viewer features. Relevant [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) include Mac sandbox/self-contained bundles (2.4.5), executable-code boundaries (2.5.2), physical goods/services (3.1.3(e)) and privacy (5.1). This architecture reduces specific review risks; Apple makes the actual decision.

Application source is MIT; dependencies and model assets retain their own notices. Preserve exact importer/OCCT corresponding sources, rebuild instructions, replaceability and recipient rights. Review the chosen App Store EULA/content-protection arrangement for the actual LGPL distribution rather than assuming MIT licensing of Form resolves dependency obligations. Retain the reference-apple provenance and asset notice. See [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) and the [durable corresponding-source checklist](CORRESPONDING_SOURCE.md). The former preview source URL returns HTTP 404. Exact dependency archives are now allowlisted under `vendor-source/` for independent public repository hosting; commit `f16823fa15c7a84e09c0824e1b738033afde0a3a` is now public, and anonymous immutable-URL downloads matched both archive hashes/lengths and the manifest.

## Final review gates

1. Authorized binary upload, processing and build selection in App Store Connect. Organizer validation of exact Build 7 succeeded on 8 November; upload and review submission remain separate pending actions.
2. Preserve the now-explicit Desktop-only qualification for Blender/Bambu in the final Store legal/reviewer material.
3. Final Store screenshots and manual keyboard/VoiceOver, RTL, contrast and minimum-size/MacBook checks. Tests and universal architecture do not prove physical Intel or macOS 14 compatibility.
4. Current dependency/license check and completed privacy/export/age-rating/trader metadata.
5. Source-only GitHub publication check, with no application/preview binaries or signing material attached.
6. Authorized Apple submission and Apple's actual review. No upload or approval is implied by these preparation documents.

## Latest metadata checkpoint

The active session saved age rating 4+ and no-data-collected privacy answers. After explicit user legal confirmation, privacy answers were published and the portal confirmed publication. The user submitted the requested DSA address proof directly to Apple. The last verified Business portal observation, on 7 November 2026, listed “Gesetz über digitale Dienste”, 27 countries, status “In Prüfung”; no new DSA check is claimed. Provider/trader verification is under Apple review, not approved; no missing user upload is currently recorded. The replacement Store screenshots JPEG01 and filled-cap JPEG03 (1280×800) now render as actual images with no error indicators and persist after reload as 2 of 10. Earlier failed PNG entries were removed from this version, with media-library copies still recoverable. Manual release after review was saved and confirmed after reload. Build 7 archive/package verification, full tests, universal Desktop/Store builds and native visual GLB-cap/STL-hole checks passed. The release agent confirmed Desktop build 7 installed locally, with strict signature/architecture/icon/sandbox checks, and a verified private MacBook-test ZIP. The Store 7 installer’s expanded payload was independently confirmed as build 7/AppStore/team D5VE86DJ5H with a valid strict signature. These packages stay local; the earlier build 6 installation is historical. These earlier checkpoints did not themselves establish Apple validation. The separately observed 8 November validation is recorded below; binary upload, review submission and approval are still not claimed.

## Validated candidate — 2026-11-08

On **8 November 2026**, the user reauthenticated the existing Apple account in Xcode and downloaded the manual profiles. Organizer opened the exact signed **Form 0.3.0 (7)** archive. The custom validation used the app certificate dated 7 November, profile **Form Mac App Store 2026**, and unchanged build 7. The final actual UI displayed **“Form 0.3.0 (7) validated”** and **“Your app successfully passed all validation checks.”** This is successful Apple validation, **not a binary upload, App Review submission, review approval or public release**. The earlier component-installation and expired-session blockers are resolved/historical.

On **8 November 2026**, the user reported that the MacBook test completed successfully and accepted the local test. This is a user-reported smoke-test result; it does not identify a specific processor/minimum macOS version or establish exhaustive hardware/accessibility testing.

DSA provider verification remains at its last observed **7 November 2026 “In Prüfung”** state, not newly rechecked or approved.


## Current media and package checkpoint — 8 November 2026

The current Desktop build 9 is installed locally; a private MacBook-test ZIP and signed Store installer were verified after extraction. The complete test suite and universal Desktop/AppStore builds passed. These newer local checks do not inherit build 7’s Apple validation.

Private Store media now comprise four German and four English 2560×1600 images made from real Store-flavor build 9 captures, plus a 28-second 1920×1080/30-fps H.264/AAC preview of actual use. The preview has German chapter text and English subtitles. Footage is edited and the orbit segment is slowed, with those changes labelled. The example is the unchanged CreativeTools Benchy geometry from MakerWorld 40146, credited under the source’s CC BY-ND 4.0 terms; it is not bundled in Form.

The latest local image revision rounds the actual capture corners and places the light-gray credit inside the screenshot near its bottom center without a footer band. Logo and headline share the vertical center of the space above the screen. Its large cropped presentation uses a generic software-display border, without an Apple device image, logo, notch or chassis. Official Apple artwork remains private and is not modified or distributed in GitHub source.

German revision 3 images were visibly loaded without upload-error icons and one preview was uploaded but still processing. English version metadata was saved and its media upload was initiated. Reauthentication was required when reloading for persistence verification. Revision 5 replaces the local image design; do not claim that replacement or the final post-reload check succeeded until the authenticated portal is checked again. All media and application installers remain private; the public repository contains source only.
