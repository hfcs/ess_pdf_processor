ESS Flutter Web demo

This is a minimal Flutter web demo that shows how to call a browser-side PDF.js helper (available as `extractPdfArrayBuffer`) from Dart/Flutter web.

Run locally:

```bash
cd web_app
flutter pub get
flutter run -d chrome
```

The demo's `web/index.html` includes pdf.js from a CDN and defines `window.extractPdfArrayBuffer(ArrayBuffer)` which returns a Promise resolving to an array of extracted text lines. The Flutter app calls this function via `dart:js_util` (see `lib/main.dart`).

Notes:
- For production, bundle pdf.js assets with your app or host them under your control rather than using the CDN.
- This demo is intentionally small; use it as a starting point to wire the browser extractor into your app and parse coordinates into structured rows.

Debug logging
 - The demo and the browser-side extractor include optional debug logging guarded by a flag so the production build remains quiet.
 - To enable verbose logging in your local development session, open the browser DevTools Console and set the global flag before loading the app or by running it in the console while the demo page is open:

```js
window.__ESS_DEBUG__ = true
```

 - The Dart-side debug messages are enabled only in debug builds via Dart `assert` semantics; they are disabled in release builds automatically, so you don't need to change anything for production.

 - IMPORTANT: do not enable `window.__ESS_DEBUG__` in production or CI environments. It's intended for local troubleshooting only.

Quick toggle script

If you'd like to enable debug mode quickly for local development, there's a tiny helper that creates a `web/debug.js` file which sets the flag before the app loads. From the `web_app` folder run:

```bash
./scripts/generate_debug_js.sh
```

This writes `web/debug.js`. Remove `web/debug.js` (or commit ignoring it) before creating production builds.

Firebase Hosting (optional)
 - You can deploy this Flutter web demo to Firebase Hosting. The repo includes a sample Firebase config and a helper deploy script under `web_app`.

Prerequisites:
 - A Firebase project named `ess-pdf-processor` (or change `.firebaserc`).
 - Firebase CLI installed and authenticated: `npm install -g firebase-tools` then `firebase login`.

Quick deploy (from repo root):

```bash
cd web_app
# optional: generate debug.js for local debugging
./scripts/generate_debug_js.sh
# build web
flutter build web --release
# deploy (will use project in .firebaserc)
./scripts/deploy_firebase.sh
```

Notes:
 - The Firebase config (`firebase.json`) expects `web_app/build/web` as the public directory (Flutter's web build output).
 - Make sure the Firebase project exists and you have permission to deploy to it. You can create a project in the Firebase Console or with `firebase projects:create ess-pdf-processor`.
