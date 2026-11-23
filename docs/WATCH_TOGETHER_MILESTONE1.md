# Watch Together Integration — Milestone 1

## Included
- Flutter Watch Together creation form for room name, anime title, provider, provider user ID, anime ID, episode number and public stream URL.
- Server-side call to `/api/watchium/rooms`; Watchium secrets remain on the backend.
- Creation of a matching Anime Friends social room with the Watchium code and AnymeX deep link attached.
- Opening AnymeX through `anymex://watchium/join/<CODE>` after creation.
- Joining a social room first, then opening its saved AnymeX deep link.
- Backend environment template and setup documentation.

## Not included / requirements
- No modifications to AnymeX source code.
- No automatic scraper-to-stream selection; the host supplies a public HTTP(S) stream URL.
- No guarantee that every stream provider is shareable; local/private proxy URLs are rejected by the backend.
- Watchium server URL/token and exact verified provider identity allowlist must be configured by the backend operator.
- Watchium synchronization and AnymeX playback require compatible server configuration and a supported stream.

## Validation performed
- `node --check backend/server.js`: PASS.
- Source conflict-marker scan: PASS (the source archive contained unresolved merge markers; the committed/upstream side was retained for those conflicted files before this integration).
- Flutter/Dart format, analyze, tests and APK build: NOT RUN; Flutter SDK is not installed in this execution environment.
- Device test with AnymeX and a live Watchium server: NOT RUN.


## Real-time status (important)

The backend contains authenticated Socket.IO handlers for joining a social room, host playback-state updates and persisted room chat broadcasts. The current Flutter app does **not** yet subscribe to these room events with a complete room detail/player UI, reconnect handling or playback drift correction. Therefore this milestone is a room-creation/AnymeX handoff foundation, not a fully working synchronized watch-party release.


## Real room chat in the app

After joining a social room, the app opens its room chat screen. The screen requests the latest 100 persisted room messages from `GET /api/watch/rooms/:code/messages`, then joins the authenticated Socket.IO room using `watch:join`. New messages are persisted by the backend and broadcast with `watch:chat-message`. Sending uses the `watch:chat` acknowledgement; the composer reports failure if the server does not confirm delivery. A disconnected socket is shown as an unavailable live connection rather than silently queueing messages.

This is real-time room chat, not video synchronization. AnymeX playback remains an external deep-link handoff through the configured Watchium service. No built-in video player or playback drift correction is claimed.
