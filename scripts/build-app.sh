#!/bin/sh
# SPDX-FileCopyrightText: 2026 Ariel Mendez
# SPDX-License-Identifier: GPL-3.0-only

set -eu

configuration="${1:-release}"
root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$root_dir"
swift build -c "$configuration" --product Kuati
bin_dir=$(swift build -c "$configuration" --show-bin-path)

app_dir="$root_dir/build/Kuati.app"
contents_dir="$app_dir/Contents"
macos_dir="$contents_dir/MacOS"
resources_dir="$contents_dir/Resources"

mkdir -p "$macos_dir" "$resources_dir"
cp "$bin_dir/Kuati" "$macos_dir/Kuati"
cp "$root_dir/support/Info.plist" "$contents_dir/Info.plist"
cp "$root_dir/support/Kuati.icns" "$resources_dir/Kuati.icns"
cp "$root_dir/LICENSE" "$resources_dir/LICENSE"

codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
