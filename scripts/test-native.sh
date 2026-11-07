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
