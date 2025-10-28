#!/usr/bin/env bash
# Build and deploy the Flutter web demo to Firebase Hosting.
# Usage (from repo root):
#   cd example/flutter_web_demo
#   ./scripts/deploy_firebase.sh
set -euo pipefail

# Ensure firebase CLI is installed
if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase CLI not found. Install with: npm install -g firebase-tools"
  exit 2
fi

echo "Building Flutter web demo..."
flutter build web --release

# Deploy to the configured Firebase project in .firebaserc (default: ess-pdf-processor)
echo "Deploying to Firebase Hosting (project: ess-pdf-processor)..."
firebase deploy --only hosting --project ess-pdf-processor

echo "Deployment finished."
