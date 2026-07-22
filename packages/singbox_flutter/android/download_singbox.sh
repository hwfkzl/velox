#!/bin/bash

# Download sing-box binaries for Android
# Usage: ./download_singbox.sh [version]
# Default version: 1.10.7

VERSION="${1:-1.10.7}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/../../../android/app/src/main/assets"

# Create assets directory if it doesn't exist
mkdir -p "$ASSETS_DIR"

echo "Downloading sing-box v${VERSION} for Android..."
echo "Assets directory: $ASSETS_DIR"

# Base URL for sing-box releases
BASE_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}"

download_arch() {
    local arch="$1"
    local filename="$2"
    local output_name="$3"
    local url="${BASE_URL}/${filename}"

    echo ""
    echo "Downloading $arch..."
    echo "URL: $url"

    # Download and extract
    temp_dir=$(mktemp -d)
    if curl -L -o "${temp_dir}/${filename}" "$url" 2>/dev/null; then
        # Extract the binary
        cd "$temp_dir" || exit
        tar -xzf "$filename" 2>/dev/null

        # Find and copy the binary
        binary_path=$(find . -name "sing-box" -type f | head -1)
        if [ -n "$binary_path" ]; then
            cp "$binary_path" "${ASSETS_DIR}/${output_name}"
            chmod +x "${ASSETS_DIR}/${output_name}"
            echo "✓ Downloaded $output_name"
            ls -lh "${ASSETS_DIR}/${output_name}"
        else
            echo "✗ Failed to find binary in archive for $arch"
        fi

        cd - > /dev/null || exit
    else
        echo "✗ Failed to download $arch"
    fi

    rm -rf "$temp_dir"
}

# Download for each architecture
download_arch "arm64" "sing-box-${VERSION}-android-arm64.tar.gz" "sing-box-arm64"
download_arch "arm" "sing-box-${VERSION}-android-armv7.tar.gz" "sing-box-arm"
download_arch "x86_64" "sing-box-${VERSION}-android-amd64.tar.gz" "sing-box-x86_64"

# Also create a copy for the default binary (arm64)
if [ -f "${ASSETS_DIR}/sing-box-arm64" ]; then
    cp "${ASSETS_DIR}/sing-box-arm64" "${ASSETS_DIR}/sing-box"
    echo ""
    echo "Created default sing-box (arm64)"
fi

echo ""
echo "Done! Binaries are in: $ASSETS_DIR"
ls -lh "$ASSETS_DIR"/sing-box* 2>/dev/null || echo "No binaries found"
echo ""
echo "Note: Make sure to add these to your .gitignore as they are large binary files:"
echo "  android/app/src/main/assets/sing-box*"
