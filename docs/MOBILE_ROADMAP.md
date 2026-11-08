# Planned iPhone and iPad version

This is a planned mobile workflow, not functionality included in the macOS release.

- Open supported 3D attachments from Mail through Share → Form, and files selected from Files/iCloud Drive.
- Open model files legitimately downloaded from MakerWorld, Printables, Thingiverse and similar providers. A webpage URL is not itself a model file.
- Choose manufacturer, printer model and a supported nozzle variant, then confirm. The catalogue should cover common FDM manufacturers and model-specific compatibility.
- Offer two simple prototype presets based on Generic PLA and Generic PETG. Temperature, cooling, retraction and machine limits must come from a validated compatible slicer profile; do not invent a universal machine configuration.
- A model/preset is not sliced G-code. The eventual mobile print route still needs a supported slicer and a verified handoff. Official Bambu documentation establishes MakerWorld/profile-based Handy printing, but no arbitrary STL/3MF inter-app import API has been verified. Do not show a working “Print in Handy” promise until a real device test proves the route.
- User confirmation is required before sending a model to a service or starting a print. No automatic model upload is part of the current Form privacy model.

References checked 8 November 2026: [Apple document sharing](https://developer.apple.com/documentation/uikit/enabling-document-sharing), [Bambu one-step printing](https://blog.bambulab.com/makerworld-one-step-printing/), [Bambu Handy listing](https://apps.apple.com/us/app/bambu-handy/id1625671285).
