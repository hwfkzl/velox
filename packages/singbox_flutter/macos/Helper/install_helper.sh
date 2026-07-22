#!/bin/sh
# install_helper.sh
# Installs the VeloxHelper privileged daemon.
# Run with root privileges via AuthorizationExecuteWithPrivileges (once only).
#
# Usage: install_helper.sh <helper_binary> <launchd_plist>

set -e

HELPER_SRC="$1"
PLIST_SRC="$2"

HELPER_DEST="/Library/PrivilegedHelperTools/com.velox.app.helper"
PLIST_DEST="/Library/LaunchDaemons/com.velox.app.helper.plist"

# Unload existing daemon if present (bootout for macOS 10.15+)
/bin/launchctl bootout system "$PLIST_DEST" 2>/dev/null || true

# Install helper binary
/bin/mkdir -p /Library/PrivilegedHelperTools
/bin/cp "$HELPER_SRC" "$HELPER_DEST"
/bin/chmod 755 "$HELPER_DEST"
/usr/sbin/chown root:wheel "$HELPER_DEST"

# Install LaunchDaemon plist
/bin/mkdir -p /Library/LaunchDaemons
/bin/cp "$PLIST_SRC" "$PLIST_DEST"
/bin/chmod 644 "$PLIST_DEST"
/usr/sbin/chown root:wheel "$PLIST_DEST"

# Load daemon (bootstrap for macOS 10.15+)
/bin/launchctl bootstrap system "$PLIST_DEST"

exit 0
