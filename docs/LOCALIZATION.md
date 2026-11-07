# Localization

The viewer and native menus share `Resources/Web/locales/{code}.json`. Each catalog has a `viewer` dictionary and a `native` dictionary. The English catalog defines the complete schema; all 41 catalogs must have identical keys and interpolation placeholders. Catalogs are bundled with the application and require no runtime translation service.

`i18n.js` resolves system languages in preference order, with region/base and Chinese script handling, then English fallback. Settings can override the system choice. Number formatting follows the resolved language. Arabic, Hebrew and Persian use RTL layout. Filenames and source component names are never translated; only generated component names change with the interface.

Static HTML uses `data-i18n`, `data-i18n-title` and `data-i18n-aria-label`. Dynamic viewer messages use `t(key, values)`. `{name}`, `{error}`, `{count}`, `{files}`, `{parts}`, `{type}` and `{unit}` must remain unchanged in translations. Values are assigned as text, never interpreted as HTML.

After adding/editing catalogs, run `npm test`. `scripts/locales.mjs` regenerates explicit JSON imports in `locale-catalogs.js`; it also runs automatically before bundling. `scripts/i18n-test.mjs` verifies complete language coverage, keys/placeholders, fallback behaviour and actual viewer DOM changes. Visual layout, native dialogs and translation fluency still need real-app review by speakers of the relevant language. License texts and third-party legal notices retain their authoritative source language.
