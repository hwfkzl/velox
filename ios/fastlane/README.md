# Velox iOS Release

## Lanes
- tf_release: Build App Store IPA and upload to TestFlight
- supersign_release: Build AdHoc IPA for super-sign distribution

## Required env vars
- DEV_TEAM_ID
- IOS_APP_BUNDLE_ID
- RUNNER_APPSTORE_PROFILE
- TUNNEL_APPSTORE_PROFILE
- RUNNER_ADHOC_PROFILE
- TUNNEL_ADHOC_PROFILE

## For TestFlight
- ASC_API_KEY_JSON (path to App Store Connect API key json)

## For super-sign upload
- SUPERSIGN_UPLOAD_CMD (provider-specific upload command)
