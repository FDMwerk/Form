#!/bin/bash
# Package an already-built, reviewed app. Does not build, sign, notarize or publish.
set -euo pipefail
umask 022

fail() { printf '%s\n' "Preview packaging stopped: $*" >&2; exit 1; }
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
app="$project_dir/build/Build/Products/Release/Form.app"
output_dir="$project_dir/distribution"
readme="$output_dir/TESTBUILD_README_DE.txt"
[[ $# -eq 0 ]] || fail 'This script takes no arguments.'
[[ $(uname -s) == Darwin ]] || fail 'Run this script on macOS.'
for utility in node ditto codesign lipo hdiutil shasum unzip; do
  command -v "$utility" >/dev/null || fail "Required utility is missing: $utility"
done
[[ -d "$app" && -f "$app/Contents/Info.plist" ]] || fail 'Build the reviewed Release app first.'
[[ -f "$readme" ]] || fail 'The German preview installation README is missing.'
version=$(node -e 'const fs=require("fs");process.stdout.write(JSON.parse(fs.readFileSync(process.argv[1],"utf8")).version)' "$project_dir/package.json")
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || fail 'Invalid package version.'
plist="$app/Contents/Info.plist"
bundle_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build_number=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")
executable_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")
minimum_macos=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")
[[ "$bundle_version" == "$version" ]] || fail 'App and package versions differ.'
[[ "$build_number" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || fail 'Invalid app build number.'
[[ "$identifier" == de.fdmwerk.form ]] || fail 'Unexpected app bundle identifier.'
[[ "$executable_name" == Form ]] || fail 'Unexpected app executable.'
executable="$app/Contents/MacOS/$executable_name"
[[ -f "$executable" ]] || fail 'The app executable is missing.'
architectures=$(lipo -archs "$executable")
[[ " $architectures " == *' arm64 '* && " $architectures " == *' x86_64 '* ]] || fail 'The app must contain arm64 and x86_64.'
# A File Provider can immediately reattach Finder metadata to a build in iCloud.
# Verify the identical signed payload after a metadata-free copy to local staging.
# Only the finished app is copied. Source trees, user documents and key material
# are never staged. Reject common accidental private/development payloads too.
node - "$app" <<'JS'
const fs=require('fs'),path=require('path'),root=process.argv[2];
function walk(directory){for(const entry of fs.readdirSync(directory,{withFileTypes:true})){
 const name=entry.name;
 if(/^(?:\.git|\.DS_Store|\.env(?:\..*)?|.*\.(?:pem|p12|pfx|key|keychain|mobileprovision))$/i.test(name))throw Error('Private/development payload found in the app.');
 const child=path.join(directory,name);
 if(entry.isSymbolicLink()){const target=fs.readlinkSync(child),resolved=path.resolve(path.dirname(child),target);if(path.isAbsolute(target)||!(resolved===root||resolved.startsWith(root+path.sep)))throw Error('External or absolute symlink found in the app.');}
 if(entry.isDirectory())walk(child);
 // Emscripten's fixed in-memory /home/web_user is a virtual path, not a host account.
 else if(entry.isFile()&&/\.(?:html?|js|json|txt|plist|map)$/i.test(name)&&/\/Users\/|\/home\/(?!web_user(?:\b|\/))|\/private\/var\//.test(fs.readFileSync(child,'utf8')))throw Error('Private absolute path found in a packaged text resource.');
}}
walk(root);
JS
zip_name="Form-$version-macOS-universal-preview.zip"
dmg_name="Form-$version-macOS-universal-preview.dmg"
for name in "$zip_name" "$dmg_name" SHA256SUMS.txt; do
  [[ ! -e "$output_dir/$name" ]] || fail "Output already exists: $name (archive it explicitly before rerunning)."
done

temp_base=${TMPDIR:-/tmp}
temp_base=${temp_base%/}
work_dir=$(mktemp -d "$temp_base/form-preview.XXXXXX")
cleanup() {
  if [[ -n "${work_dir:-}" && -d "$work_dir" && "$work_dir" == "$temp_base"/form-preview.* ]]; then
    /bin/rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
clean_app="$work_dir/clean/Form.app"
zip_stage="$work_dir/Form-$version-preview"
dmg_stage="$work_dir/disk"
artifacts="$work_dir/artifacts"
mkdir -p "$work_dir/clean" "$zip_stage" "$dmg_stage" "$artifacts"
ditto --norsrc "$app" "$clean_app"
codesign --verify --deep --strict --all-architectures "$clean_app"
ditto --norsrc "$clean_app" "$zip_stage/Form.app"
ditto --norsrc "$clean_app" "$dmg_stage/Form.app"
cp "$readme" "$zip_stage/TESTBUILD_README_DE.txt"
cp "$readme" "$dmg_stage/TESTBUILD_README_DE.txt"
printf 'Form %s\nBuild: %s\nArchitecture: arm64 + x86_64\nMinimum macOS: %s\nPreview only; disk image unsigned; not notarized.\n' "$version" "$build_number" "$minimum_macos" > "$zip_stage/BUILD_INFO.txt"
cp "$zip_stage/BUILD_INFO.txt" "$dmg_stage/BUILD_INFO.txt"
ln -s /Applications "$dmg_stage/Applications"
ditto --norsrc -c -k --keepParent "$zip_stage" "$artifacts/$zip_name"
unzip -tq "$artifacts/$zip_name"
hdiutil create -volname 'Form Preview' -fs HFS+ -format UDZO -srcfolder "$dmg_stage" "$artifacts/$dmg_name"
hdiutil verify "$artifacts/$dmg_name"
cp "$readme" "$artifacts/TESTBUILD_README_DE.txt"
(
  cd "$artifacts"
  shasum -a 256 "$zip_name" "$dmg_name" TESTBUILD_README_DE.txt > SHA256SUMS.txt
)
# Publish only these explicit artifacts into the local distribution directory.
# Nothing is uploaded and no existing output is overwritten.
for name in "$zip_name" "$dmg_name" SHA256SUMS.txt; do
  [[ ! -e "$output_dir/$name" ]] || fail "Output appeared while packaging: $name"
  mv -n "$artifacts/$name" "$output_dir/$name"
done
printf 'Prepared local preview artifacts:\n%s\n%s\n%s\n' "$zip_name" "$dmg_name" SHA256SUMS.txt
