#!/bin/bash

# Download libbox.aar for sing-box Android integration
# Usage: ./download_libbox.sh [version]
# Default version: 1.10.0

VERSION="${1:-1.10.0}"
LIBS_DIR="$(dirname "$0")/libs"
AAR_FILE="$LIBS_DIR/libbox.aar"

# Create libs directory if it doesn't exist
mkdir -p "$LIBS_DIR"

# Check if already downloaded
if [ -f "$AAR_FILE" ]; then
    echo "libbox.aar already exists in $LIBS_DIR"
    echo "Delete it first if you want to re-download"
    exit 0
fi

echo "Downloading libbox.aar version $VERSION..."

# Download URL for sing-box releases
# The AAR is typically named libbox-$VERSION.aar in releases
DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/libbox-${VERSION}.aar"

echo "URL: $DOWNLOAD_URL"

# Download using curl
if command -v curl &> /dev/null; then
    curl -L -o "$AAR_FILE" "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O "$AAR_FILE" "$DOWNLOAD_URL"
else
    echo "Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Check if download was successful
if [ -f "$AAR_FILE" ] && [ -s "$AAR_FILE" ]; then
    echo "Successfully downloaded libbox.aar to $LIBS_DIR"
    ls -lh "$AAR_FILE"
else
    echo "Error: Download failed. Please check the URL and try again."
    echo ""
    echo "Alternative: Build from source"
    echo "  1. Clone: git clone https://github.com/SagerNet/sing-box"
    echo "  2. Build: make lib_android"
    echo "  3. Copy libbox.aar to $LIBS_DIR"
    rm -f "$AAR_FILE"
    exit 1
fi
