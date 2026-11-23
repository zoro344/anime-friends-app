# Anime Friends implementation status

Updated: 2026-11-22

This document distinguishes source changes from work that still requires a configured backend, provider review, a physical Android device, or deployment approval.

## Data integrity rule

No demo anime source is included. No fake anime titles, users, posts or conversations are bundled. Empty states are shown when real backend/catalogue data is absent. See `REAL_DATA_AND_REALTIME_RULES.md`.

## Implemented in this source milestone

- Flutter app now starts with an account sign-in / registration gate instead of presenting local sample content as a live community.
- Backend URL is configurable in the app. Backend URLs must use HTTPS; cleartext HTTP is rejected by the client.
- JWT session tokens are stored using `flutter_secure_storage` rather than ordinary preferences.
- REST client provides request timeouts, JSON validation, bearer-token handling and user-facing API errors.
- Backend authentication uses bcrypt password hashes and JWT validation; auth routes are rate-limited.
- Production backend startup now requires a non-default JWT secret and an explicit CORS allowlist.
- Existing JSON database collections are retained. New collections are added additively when an older database is loaded.
- Profile username/bio/avatar URL update endpoint.
- Feed API integration for loading, creating, voting, pagination, editing and deleting posts. The current UI exposes loading/retry through refresh, creation and voting; edit/delete controls are not yet exposed.
- AniList search is connected to the existing backend endpoint.
- Library add/remove and status-update API endpoints.
- Friends list, request, accept/reject, remove and block/report API foundations.
- Direct-message REST endpoints with friend-only authorization, persisted message history, read timestamps and Socket.IO delivery events. The app refreshes the open conversation after a live message event. This is backend-backed live notification plus REST refresh, not a tested end-to-end realtime guarantee.
- Watch-room create/list/join/leave/close and host playback-state endpoints. Socket.IO supports authenticated room membership, host state events and persisted room chat events. The Flutter client now has a room chat screen: it loads persisted room history, joins the authenticated Socket.IO room, receives live room messages, and sends messages with server acknowledgements. AnymeX playback remains a deep-link handoff rather than an in-app player.
- Anime news list/filter and native article detail screens. Publisher pages open in an embedded HTTPS-only WebView; app back navigation remains in place.
- Android INTERNET and network-state permissions are declared.
- GitHub Actions checks backend JavaScript syntax and Flutter formatting, analysis, tests and debug APK build.

## Not complete yet — do not treat these as shipped features

| Area | Remaining work |
|---|---|
| Accounts | Password reset/recovery, account deletion/export, token refresh/revocation, profile image upload and privacy settings |
| Feed | Image upload/storage, edit/delete/comment UI, comment replies, richer reactions, pagination UI, moderation UI and stronger spam controls |
| Anime catalogue | Details, seasonal/trending discovery, genres/filters, recommendations and full library status controls |
| Anime providers | No production stream provider is registered. Each built-in provider must be individually reviewed for ownership, terms, lawful access, URL safety, parser maintenance and tests before inclusion. No extension APK/JAR/JS execution is used. |
| Player | No playback engine is selected or shipped. The interface remains abstract until MediaKit is benchmarked against Android Media3 on target devices. |
| Watch Together | Social room create/join and persisted/live room chat are implemented. AnymeX/Watchium handoff is conditional on external configuration. The app still lacks its own player, playback-state UI, heartbeat/reconnect, drift correction and lifecycle tests. |
| Chats/social | Block/report UI, typing/presence, reliable read-receipt UI, invitation controls and end-to-end runtime tests |
| News | RSS feeds must be configured on the backend. Publisher-specific rendering and accessibility testing remain. |
| Notifications | In-app notification UI, preferences, delivery rules and deduplication remain. Push notifications require a separately selected free service and setup. |
| Database | JSON storage is single-process only. Multi-instance hosting requires a separately approved database migration and a verified backup/restore process. |
| Security | Dependency audit, automated authorization tests, abuse testing, URL/DNS SSRF review, privacy review and production penetration testing remain. |
| Android/release | Realme 7 / Android 12 installation, lifecycle, memory, network interruption and release-signing tests remain. |
| Deployment | No cloud account, migration, or deployment was performed. A public HTTPS backend URL is still required before app sign-in can work outside development. |

## Data safety

The uploaded source archive intentionally did not include `backend/data/*.json`, `.env` files, backups, signing keys or APKs. No user database was copied into this working source. The original Termux project and its data were not modified.

The additive database loader does not delete existing arrays. Before using this code with the real database, take a fresh backup and test against a copy first. Do not point a deployed service at the production database until the backup/restore process is verified.

## Validation performed for this milestone

- Uploaded ZIP integrity: passed.
- Backend JavaScript syntax (`node --check backend/server.js`): passed after the current changes.
- Flutter/Dart format, analysis, widget tests and APK build: not run in this environment because the Flutter and Dart SDKs are not installed.
- Backend HTTP/Socket.IO integration tests: not run; dependency installation timed out in this environment. The room chat client/server source path was reviewed, but not executed end-to-end.
- Physical-device tests: not run.


## Mandatory acceptance matrix

| # | Category | Current milestone status |
|---:|---|---|
| 1 | Frontend/UI | **Partial** — existing visual layout and Feed-first tabs preserved; authentication gate, refresh and error states added; accessibility/responsive audit pending |
| 2 | Accounts/auth | **Partial** — signup/login, bcrypt/JWT backend, secure token storage, profile edit; recovery/deletion/refresh lifecycle pending |
| 3 | Feed | **Partial** — live load/create/vote, server pagination, post edit/delete endpoints; comments/replies/image upload/moderation UI pending |
| 4 | Anime catalogue | **Partial** — AniList search and result covers; detail/trending/seasonal/recommendations/filtering pending |
| 5 | Anime repository | **Not shipped** — provider review and registration pending; no unreviewed scraping or executable extensions |
| 6 | Player | **Not shipped** — MediaKit vs Media3 comparison documented; device benchmark and engine selection pending |
| 7 | Watch Together | **Partial** — room create/join, persisted room chat history and Socket.IO room chat client; AnymeX/Watchium requires external configuration; in-app player and sync recovery pending |
| 8 | Chats/social | **Partial** — friend request flows, direct message REST, read timestamps and basic thread UI; presence/typing/complete realtime UX pending |
| 9 | News/content | **Partial** — RSS API and category/search UI; native article summary plus HTTPS in-app WebView; publisher QA and configured feeds pending |
| 10 | Profile/library | **Partial** — profile edit, library add/remove and status API; complete status UI, history and privacy controls pending |
| 11 | Notifications | **Backend foundation only** — notification records and read API; complete app UI, preferences and push delivery pending |
| 12 | Backend/database | **Partial** — serialized atomic JSON writes, additive collections, core APIs; multi-instance database and migration pending |
| 13 | Security/privacy | **Partial** — HTTPS-only client URLs, secure token storage, production secret/CORS checks, rate limits, friend-only chat; security audit and abuse testing pending |
| 14 | Android | **Partial** — internet permissions, cleartext disabled, Android project config retained; Android 12 device/lifecycle/low-memory tests pending |
| 15 | Build/testing/release | **Partial** — CI workflow updated; backend syntax checked; Flutter CI, APK build, device tests and release signing not yet verified |

The acceptance target remains **all 15 categories passing**, not merely the subset marked partial or backend foundation.
