#!/bin/sh
# uninstall_helper.sh
# Removes the VeloxHelper privileged daemon.
# Run with root privileges via AuthorizationExecuteWithPrivileges.

PLIST_DEST="/Library/LaunchDaemons/com.velox.app.helper.plist"
HELPER_DEST="/Library/PrivilegedHelperTools/com.velox.app.helper"

/bin/launchctl bootout system "$PLIST_DEST" 2>/dev/null || true

/bin/rm -f "$PLIST_DEST"
/bin/rm -f "$HELPER_DEST"

exit 0
