#!/usr/bin/env bash
# Build and deploy the Flutter web app to Firebase Hosting.
# Usage (from repo root):
#   cd web_app
#   ./scripts/deploy_firebase.sh
set -euo pipefail

# Ensure firebase CLI is installed
if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase CLI not found. Install with: npm install -g firebase-tools"
  exit 2
fi

echo "Building Flutter web app..."
flutter build web --release

# Deploy to the configured Firebase project in .firebaserc (default: ess-web-extractor)
echo "Deploying to Firebase Hosting (project: ess-web-extractor)..."
firebase deploy --only hosting --project ess-web-extractor

echo "Deployment finished."
