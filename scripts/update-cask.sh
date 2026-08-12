#!/bin/sh
set -eu

version="${1:-}"
sha256="${2:-}"

if [ -z "$version" ] || [ -z "$sha256" ]; then
    echo "Usage: $0 <version> <sha256>" >&2
    exit 1
fi

case "$version" in
    *[!0-9.]* | "")
        echo "Invalid version: $version" >&2
        exit 1
        ;;
esac

case "$sha256" in
    *[!0-9a-f]* | "")
        echo "Invalid SHA-256: $sha256" >&2
        exit 1
        ;;
esac

if [ "${#sha256}" -ne 64 ]; then
    echo "SHA-256 must contain exactly 64 hexadecimal characters" >&2
    exit 1
fi

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cask_file="$root_dir/Casks/kuati.rb"

env \
    KUATI_RELEASE_VERSION="$version" \
    KUATI_RELEASE_SHA256="$sha256" \
    ruby -pi -e \
    'gsub(/^  version .+$/, "  version \"#{ENV.fetch("KUATI_RELEASE_VERSION")}\""); gsub(/^  sha256 .+$/, "  sha256 \"#{ENV.fetch("KUATI_RELEASE_SHA256")}\"")' \
    "$cask_file"
