# API protocol builds

The committed `GoAPIAuthEnabled` Boolean in the app's Info.plist is true. Default
builds use Go authentication and app API routing: `/app/auth/start`, the stateful
callback, and POST `/app/auth/renew` and `/app/twitch-token`.

For an explicit legacy compatibility build, set the Boolean to false in a
separate checkout:

```bash
/usr/libexec/PlistBuddy -c 'Set GoAPIAuthEnabled false' BurkeBlackApp/Info.plist
```

A missing key also selects the legacy protocol. Keep the value a Boolean, not a
string. Network failures never downgrade the protocol, and changing this setting
affects newly built apps only.

Go builds use a random, ten-minute nonce tied to the retained browser session,
verify state on success/error, explicitly renew authenticated API requests, and
use POST for Twitch refresh. The Go routing marker applies only to the HTTPS app
API; Twitch and other third-party requests remain unchanged. Callback credentials
are never logged.

CI tests the nonce contract, compiles unsigned Release simulator builds for the
unmodified default and explicit legacy setting, and builds the default Release
configuration for iPhone. It checks the actual built app's Info.plist Boolean.
These checks do not replace installed-device testing or distribution signing.

Use Xcode and the existing signing team to archive a distributed build. The app
and extensions must all have valid signing. Keep signing files and private build
configuration outside source control. Before distribution, check sign-in,
cancellation, account switching, session persistence, temporary errors, GIF
search and Twitch-token consumers. Restarting during sign-in must reject the old
callback and require a new attempt.

A backend rollback must retain the secure Go start/callback and POST renewal/
refresh routes for already-installed Go clients. PHP does not implement the
strict start route.
