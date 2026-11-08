# Mobile printing and Bambu Handy handoff

Research checked **8 November 2026**. Scope: the new iPhone/iPad app only. This document does not change the submitted macOS 0.3.0 (11) release.

## Finding

The supported route documented by Bambu is **MakerWorld model + compatible print profile → Bambu cloud slicing → printer through Handy**. Bambu explains that the service combines model, process and filament inputs and generates printer-specific G-code. A bare STL has no slicing settings; an unsliced 3MF project is also not a finished print job. Choosing Generic PLA/PETG in Form cannot replace slicing. [Bambu: one-step printing](https://blog.bambulab.com/makerworld-one-step-printing/)

**A public, documented iOS interface that accepts an arbitrary local STL/3MF from another app into Handy and then starts its print was not found in the official sources checked.** This is an evidence limitation, not proof that every private capability is absent. No real iPhone/iPad transfer or print was performed during this research. The current Handy listing advertises printer control and MakerWorld printing, not a general third-party file-import API. The inspected US listing showed version 4.4.2; regional/device availability can differ. [Official Handy listing](https://apps.apple.com/us/app/bambu-handy/id1625671285), [Bambu Handy repository](https://github.com/bambulab/Bambu-Handy)

## Route assessment

| Route | What is established | Form implementation decision |
| --- | --- | --- |
| Mail / Files / Safari download → Form | iOS document handling and file sharing are platform capabilities. This needs Form's document-type registration and device verification. | Implement import of supported model files and retain their original contents. A model webpage alone is not a model download. |
| Form → iOS Share Sheet / Files / AirDrop | Apple's sharing API can offer a file to system-provided and compatible installed destinations. | Implement **Share file**. The user chooses the destination. Do not label the action **Print in Handy** or force Handy into the destination list. |
| Form → original MakerWorld model page | Standard HTTPS can reopen a known source page. Printing remains the site's/Handy's own profile-based workflow. | Offer **Open original model** only when the actual source URL is known. Do not infer a model ID from a filename. Whether the system opens Handy or the browser requires device testing. |
| Local STL/3MF → Handy → print | No general documented import/print contract verified. | Do not ship a claimed working direct-print button, guessed URL scheme, or fake success state. |
| Form → Bambu Studio / Connect on a computer | Bambu documents third-party slicer integration through Connect. This is a separate desktop workflow. | Share/AirDrop to the computer can be an interim route, followed by user-controlled slicing. No claim of a mobile-only or automatic handoff. |
| Native mobile slicer / private slicing service → supported printer integration | Would require another engineering and licensing phase plus official integration access or a supported transport. | Future work; do not upload files, deploy a service, or send a print in this research task. |

The Share Sheet decision follows [Apple's data-sharing API](https://developer.apple.com/documentation/uikit/collaborating-and-sharing-copies-of-your-data). The computer integration distinction follows [Bambu's Connect explanation](https://blog.bambulab.com/updates-and-third-party-integration-with-bambu-connect/). Connect must not be confused with an iOS Handy SDK.

## MVP to build now

1. Open supported files from Files/iCloud Drive and other apps; show the real model with touch orbit, pinch zoom, selection, measurements and file information.
2. Share the original imported file through iOS, including AirDrop/Save to Files when the system offers them. Exporting a model does not mean it is printable G-code.
3. Keep the manufacturer → printer → compatible nozzle → Generic PLA/Generic PETG setup local. Label it as preparation; do not imply that selecting it generated a sliced job. Do not invent universal temperatures, start G-code, bed dimensions or nozzle compatibility.
4. If a verified MakerWorld source accompanies the file, reopen that source page. Preserve Printables/Thingiverse source links as their own sources rather than converting them to MakerWorld links. Do not automatically publish anyone's private attachment to a model platform.
5. Keep print start outside Form until an end-to-end supported route is demonstrated. A successful share callback means the share activity completed, not that a printer accepted or started a job.

## Official integration path to pursue next

Bambu's Trust Center announcement explicitly describes integration documentation and a partnership process for SDK access. Its Connect announcement gives **devpartner@bambulab.com** for partnership enquiries. These establish a legitimate enquiry path, not guaranteed iOS SDK availability or approval. No enquiry has been sent. [Bambu Trust Center announcement](https://blog.bambulab.com/the-bambu-lab-trust-center-for-complete-security-and-privacy-transparency/), [Bambu partnership contact](https://blog.bambulab.com/updates-and-third-party-integration-with-bambu-connect/)

Questions for Bambu: Does Handy expose a supported iOS document-import contract, share extension or universal link for local models? Is there an approved third-party slicing API? Does the SDK support iOS/iPadOS or require a local desktop service? Which printer/firmware/nozzle combinations are supported? What licensing, redistribution and App Store conditions apply? Can Form hand over a prepared job for an explicit confirmation in Bambu's UI without storing Bambu credentials?

Do not use extracted cloud tokens, impersonate Studio/Handy, embed a proprietary network plugin without permission, or reverse-engineer endpoints for the MVP. The available official sources do not authorize those approaches.

## Device acceptance checklist before claiming direct printing

- Test current Handy on a real iPhone and iPad, recording OS, app version, printer model, firmware and nozzle. Simulator tests cannot establish installed-app interoperability or a physical print.
- Import a genuine STL attachment from Mail; repeat with a 3MF project, Files/iCloud and a legally downloaded model from each intended website. Verify geometry, units, multiple parts and source permissions.
- Open the Share Sheet for STL and 3MF separately. Record whether Handy is actually offered and what it does; test cancel, unavailable app and declined transfer. Never interpret disappearance of the sheet as printer success.
- For the original MakerWorld route, check supported and unsupported profiles/nozzles, missing profile, offline state and account/printer selection in the destination app.
- For any future slicing route, verify plate fit/orientation, selected machine and nozzle, material, supports, generated toolpath and print-time estimate. A file's `.3mf` extension alone cannot establish that it is sliced or compatible.
- Run only a deliberately confirmed prototype print after checking the physical printer and material. Record successful completion separately from file transfer and job submission.

## Research limits

The official Bambu blog, App Store listing and Bambu-owned repositories were readable. Direct Bambu Wiki/Trust Center pages returned access/fetch errors in this research environment; no claim here relies on unseen text from those pages. Community posts and third-party reverse-engineering projects were excluded as implementation authority. The findings should be refreshed when Handy or the official integration documentation changes.
