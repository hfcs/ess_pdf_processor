ESS Flutter web app

This Flutter web app demonstrates client-side fetching and parsing of ESS competition pages.

Run locally:

```bash
cd web_app
flutter pub get
flutter run -d chrome
```

What it does
- The app fetches a competition ``Competition URL`` (for example `https://hkg.as.ipscess.org/portal?match=21`), discovers division result links, fetches each division with `&group=stage`, and parses the server-rendered HTML stage tables into the repository's `ResultRow` format.
- The UI exposes a `Competition URL` text field, a `Fetch web results` button, per-division progress, and an `Export CSV` button to download the consolidated CSV.

Notes
- The web app requires that the target ESS site allow cross-origin requests (CORS). If the site allows fetches from the browser, the app can operate entirely client-side and no files are uploaded to any server.
- The in-browser PDF upload flow has been removed. Use the CLI for PDF-based extraction or the headless Node/Puppeteer helper for JS-rendered pages when required.

Debug logging
- The web app supports an optional `window.__ESS_DEBUG__` flag to enable verbose console logs for development. Do not enable this in production.

Firebase Hosting
- The repository includes Firebase config and a CI workflow that can deploy the built `web_app/build/web` artifact to Firebase Hosting. See the repo root `README.md` for CI and deployment notes.
