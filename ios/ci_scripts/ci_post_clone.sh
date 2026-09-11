#!/bin/sh
#
# Xcode Cloud runs every ci_scripts/ci_post_clone.sh right after cloning the
# repo, before it tries to resolve a project to build. WakeMate.xcodeproj
# isn't committed (see ios/README.md — it's generated from project.yml via
# XcodeGen, same as the ios-build.yml GitHub Actions job), so without this
# script Xcode Cloud would find nothing to build.
#
# Xcode Cloud's macOS images ship Homebrew and Xcode already; nothing else
# needs pre-installing.

set -eu

cd "$CI_WORKSPACE/ios"

echo "Installing XcodeGen..."
brew install xcodegen

echo "Writing ios/Secrets.xcconfig from Xcode Cloud environment variables..."
# Real values are set per-workflow in App Store Connect -> Xcode Cloud ->
# (workflow) -> Environment -> Environment Variables (mark anything
# sensitive as Secret there) — never committed, same rule as the local
# Secrets.xcconfig (see Secrets.xcconfig.example). Missing a var fails the
# build loudly instead of silently shipping a placeholder.
#
# xcconfig treats an unescaped "//" as a comment start, which breaks URLs;
# "$()" is an empty build setting that splits the slashes apart so Xcode
# doesn't read the rest of the line as a comment (see
# Secrets.xcconfig.example for the same trick used locally).
escape_url() {
  printf '%s' "$1" | sed 's#://#:/$()/#'
}

: "${SUPABASE_URL:?SUPABASE_URL not set — add it in the Xcode Cloud workflow's Environment Variables}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY not set — add it in the Xcode Cloud workflow's Environment Variables}"
: "${SENTRY_DSN:?SENTRY_DSN not set — add it in the Xcode Cloud workflow's Environment Variables}"
: "${TELEMETRYDECK_APP_ID:?TELEMETRYDECK_APP_ID not set — add it in the Xcode Cloud workflow's Environment Variables}"

cat > Secrets.xcconfig <<EOF
SUPABASE_URL = $(escape_url "$SUPABASE_URL")
SUPABASE_ANON_KEY = $SUPABASE_ANON_KEY
SENTRY_DSN = $(escape_url "$SENTRY_DSN")
TELEMETRYDECK_APP_ID = $TELEMETRYDECK_APP_ID
EOF

echo "Generating Xcode project..."
xcodegen generate

echo "Stamping build number from Xcode Cloud's CI_BUILD_NUMBER ($CI_BUILD_NUMBER)..."
# Ticket 02: "Build number auto-incremented by Xcode Cloud; marketing
# version bumped manually." agvtool needs VERSIONING_SYSTEM = apple-generic
# on the target (set in project.yml) and an already-generated project,
# which is why this runs last.
agvtool new-version -all "$CI_BUILD_NUMBER"
