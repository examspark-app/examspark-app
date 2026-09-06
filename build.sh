#!/bin/bash
set -e

git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$PWD/flutter/bin"
cd examspark_frontend

CURRENT=$(grep '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+).*/\1/')
NEW=$((CURRENT + 1))
VERSION="1.0.0+$NEW"

sed -i -E "s/^version: .*/version: $VERSION/" pubspec.yaml
sed -i "s/BUILD_VERSION_PLACEHOLDER/$VERSION/g" web/index.html
echo "{\"version\": \"$VERSION\"}" > web/version.json

flutter build web --release --pwa-strategy=none \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=FASTAPI_BASE_URL="$FASTAPI_BASE_URL" \
  --dart-define=POSTHOG_API_KEY="$POSTHOG_API_KEY" \
  --dart-define=POSTHOG_HOST="$POSTHOG_HOST"