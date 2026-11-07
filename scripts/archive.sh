#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
: "${FORM_DEVELOPMENT_TEAM:?Set FORM_DEVELOPMENT_TEAM to your Apple team ID}"
npm ci
npm run build
xcodegen generate
xcodebuild -project Form.xcodeproj -scheme Form -configuration AppStore -archivePath distribution/Form-AppStore.xcarchive -derivedDataPath build CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY='Apple Distribution' DEVELOPMENT_TEAM="$FORM_DEVELOPMENT_TEAM" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO archive
