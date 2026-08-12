#!/bin/sh
# SPDX-FileCopyrightText: 2026 Ariel Mendez
# SPDX-License-Identifier: GPL-3.0-only

set -eu

version="${1:-}"
if [ -z "$version" ]; then
    echo "Usage: $0 <version>" >&2
    exit 1
fi

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plist_version=$(plutil -extract CFBundleShortVersionString raw "$root_dir/support/Info.plist")

if [ "$version" != "$plist_version" ]; then
    echo "Release version $version does not match Info.plist version $plist_version" >&2
    exit 1
fi

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/kuati-release.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT

arm_build="$work_dir/arm64"
intel_build="$work_dir/x86_64"

cd "$root_dir"
swift build \
    --disable-sandbox \
    -c release \
    --product Kuati \
    --triple arm64-apple-macosx13.0 \
    --scratch-path "$arm_build"
swift build \
    --disable-sandbox \
    -c release \
    --product Kuati \
    --triple x86_64-apple-macosx13.0 \
    --scratch-path "$intel_build"

arm_bin=$(swift build \
    --disable-sandbox \
    -c release \
    --product Kuati \
    --triple arm64-apple-macosx13.0 \
    --scratch-path "$arm_build" \
    --show-bin-path)
intel_bin=$(swift build \
    --disable-sandbox \
    -c release \
    --product Kuati \
    --triple x86_64-apple-macosx13.0 \
    --scratch-path "$intel_build" \
    --show-bin-path)

app_dir="$work_dir/Kuati.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
lipo -create "$arm_bin/Kuati" "$intel_bin/Kuati" -output "$app_dir/Contents/MacOS/Kuati"
cp "$root_dir/support/Info.plist" "$app_dir/Contents/Info.plist"
cp "$root_dir/support/Kuati.icns" "$app_dir/Contents/Resources/Kuati.icns"
cp "$root_dir/LICENSE" "$app_dir/Contents/Resources/LICENSE"
codesign --force --deep --sign - "$app_dir"

dist_dir="$root_dir/dist"
archive="$dist_dir/Kuati-$version.zip"
mkdir -p "$dist_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"

codesign --verify --deep --strict "$app_dir"
lipo -archs "$app_dir/Contents/MacOS/Kuati"
shasum -a 256 "$archive"
