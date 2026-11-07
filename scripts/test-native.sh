#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ "$(uname -s)" != Darwin ]; then
  printf '%s\n' 'SKIP native macOS checks: these require macOS and the Xcode Swift compiler.'
  exit 0
fi
form_native_run_dir=$(mktemp -d "${TMPDIR:-/tmp}/form-native-checks.XXXXXX")
trap 'rm -rf "$form_native_run_dir"' EXIT HUP INT TERM
form_native_module_cache="${FORM_NATIVE_TEST_CACHE:-${TMPDIR:-/tmp}/form-native-swift-module-cache}"
mkdir -p "$form_native_module_cache"
swiftc -parse-as-library Sources/NativePolicies.swift scripts/native-policy-tests.swift \
  -module-cache-path "$form_native_module_cache" -o "$form_native_run_dir/run"
"$form_native_run_dir/run"
swiftc -parse-as-library -typecheck Sources/App.swift Sources/NativePolicies.swift \
  -module-cache-path "$form_native_module_cache"
printf '%s\n' 'PASS native AppKit/WebKit integration source typecheck'

form_webkit_app="$form_native_run_dir/NativeWebKitTests.app"
mkdir -p "$form_webkit_app/Contents/MacOS" "$form_webkit_app/Contents/Resources"
cp Sources/App.swift "$form_webkit_app/Contents/Resources/ProductionApp.swift"
cat > "$form_webkit_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>de.fdmwerk.form.native-webkit-tests</string><key>CFBundleExecutable</key><string>NativeWebKitTests</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
cat > "$form_webkit_app/Contents/Resources/bridge.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"></head><body><script>
window.openModel = async (name, bytes, sourceID) => {
 if (name === 'rejected.stl') return false;
 window.activeSourceID = sourceID;
 return true;
};
window.selectedSourceID = () => window.activeSourceID || null;
</script></body></html>
HTML
swiftc -parse-as-library Sources/NativePolicies.swift scripts/native-webkit-tests.swift \
 -module-cache-path "$form_native_module_cache" -o "$form_webkit_app/Contents/MacOS/NativeWebKitTests"
codesign --force --sign - --entitlements Resources/Form.entitlements "$form_webkit_app"
"$form_webkit_app/Contents/MacOS/NativeWebKitTests"

swiftc -D FORM_APP_STORE -parse-as-library Sources/NativePolicies.swift scripts/native-store-tests.swift \
 -module-cache-path "$form_native_module_cache" -o "$form_native_run_dir/store-policy"
"$form_native_run_dir/store-policy"
swiftc -D FORM_APP_STORE -parse-as-library Sources/App.swift Sources/NativePolicies.swift \
 -module-cache-path "$form_native_module_cache" -o "$form_native_run_dir/store-app"
if strings "$form_native_run_dir/store-app" | grep -Eq -- 'read_factory_settings|--load-settings|Contents/MacOS/BambuStudio'; then
 printf '%s\n' 'FAIL AppStore flavor still contains external execution adapter payloads' >&2
 exit 1
fi
printf '%s\n' 'PASS actual AppStore executable: no Blender Python or Bambu launch payloads'
