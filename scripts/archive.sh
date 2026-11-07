#!/bin/zsh
# Local Store archive only. Never uploads a build or creates a GitHub release.
set -eu
cd "$(dirname "$0")/.."
: "${FORM_DEVELOPMENT_TEAM:?Set FORM_DEVELOPMENT_TEAM to your Apple team ID}"
[[ -d node_modules ]] || npm ci
npm run build
xcodegen generate
archive_path=${FORM_ARCHIVE_PATH:-"$HOME/Library/Caches/Form/Form-AppStore.xcarchive"}
derived_data=${FORM_DERIVED_DATA:-"$HOME/Library/Caches/Form/DistributionBuild"}
identity=${FORM_CODE_SIGN_IDENTITY:-'Apple Distribution'}
[[ ! -e "$archive_path" ]] || { print -u2 'Archive already exists; choose a new FORM_ARCHIVE_PATH to preserve it.'; exit 1; }
signing=("DEVELOPMENT_TEAM=$FORM_DEVELOPMENT_TEAM" "CODE_SIGN_IDENTITY=$identity")
if [[ -n "${FORM_PROVISIONING_PROFILE:-}" ]]; then
 signing+=("CODE_SIGN_STYLE=Manual" "PROVISIONING_PROFILE_SPECIFIER=$FORM_PROVISIONING_PROFILE")
else
 signing+=("CODE_SIGN_STYLE=Automatic")
fi
xcodebuild -project Form.xcodeproj -scheme Form -configuration AppStore \
 -archivePath "$archive_path" -derivedDataPath "$derived_data" \
 "${signing[@]}" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO archive
