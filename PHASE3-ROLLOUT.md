# API migration client preparation

`GoAPIAuthEnabled` is an optional Boolean in the app's Info.plist, false when
absent. Do not enable a distributed build until `/app/auth/start`, the stateful
callback and POST `/app/auth/renew` and `/app/twitch-token` are live and privately
verified. There is no network-triggered fallback to a state-free sign-in.

An enabled build uses a random, ten-minute nonce tied to its retained browser
session, verifies state on success/error, explicitly renews authenticated API
requests, and uses POST for Twitch refresh. Existing release builds keep their
current PHP protocol. API request adaptation checks the host and path, leaving
Twitch and other third-party requests unchanged. It logs no callback credential.

CI tests the nonce contract and compiles unsigned simulator builds with both
protocol settings, plus an unsigned iPhone build with Go login enabled. It checks
the actual built app's Info.plist Boolean, not just the source setting. These are
compile/configuration checks; they do not prove physical-device login works.

## Prepare the installed iPhone preview

Use a dedicated checkout on a Mac with Xcode and the project's Apple signing
team available. Enable the opt-in only in that checkout:

```bash
/usr/libexec/PlistBuddy -c 'Add GoAPIAuthEnabled bool true' BurkeBlackApp/Info.plist
open BurkeBlackApp.xcodeproj
```

If the key already exists, inspect its type and value before changing it. Keep it
a Boolean, not a string. Select the BurkeBlackApp scheme, the connected iPhone,
and the existing signing team, then build and run. The app and its extensions
must have valid signing. An unsigned CI build cannot be installed on an iPhone.
Do not commit this local opt-in or distribute an enabled release before the
installed checks pass. The committed release default remains off.

## Installed checks

Before release, verify on an installed build: browser cookie round trip, cancellation,
account switching, failed login, duplicate/mismatched callback, app restart during
sign-in, session renewal, revoked sessions, temporary backend outages, GIF search,
and Twitch-token consumers. Restarting the app during sign-in must reject the old
callback and require a new attempt. Keep the last verified Go auth image for
rollback; PHP does not implement the strict start route.
