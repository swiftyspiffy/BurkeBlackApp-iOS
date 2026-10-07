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

CI tests the nonce contract and compiles an unsigned simulator build. Before
release, verify on an installed build: browser cookie round trip, cancellation,
account switching, failed login, duplicate/mismatched callback, app restart during
sign-in, session renewal, revoked sessions, temporary backend outages, GIF search,
and Twitch-token consumers. Restarting the app during sign-in must reject the old
callback and require a new attempt. Keep the last verified Go auth image for
rollback; PHP does not implement the strict start route.
