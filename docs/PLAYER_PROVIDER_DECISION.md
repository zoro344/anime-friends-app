# Anime provider and player selection

## Provider policy

Anime Friends will use only built-in, individually reviewed providers. It will not execute arbitrary extension APKs, JARs, JavaScript bundles or downloaded code.

A provider may be enabled only after review of:
- Provider ownership and terms of service.
- Whether access is lawful and permitted in the target regions.
- Supported catalogue, episode and source metadata.
- HTTPS requirements, redirect behavior and private-network URL rejection.
- Parser stability, timeouts, cancellation and graceful failure.
- Audio, subtitle and quality metadata where supplied.
- Version pinning, maintenance owner and regression tests.

No production provider is currently registered. The existing `DemoAnimeSource` is test scaffolding only and must not be represented as a real catalogue or playback provider.

## Player comparison

| Criterion | MediaKit / MPV | Android Media3 (ExoPlayer) |
|---|---|---|
| Platform fit | Cross-platform engine with native MPV bindings | Android-native playback stack; Flutter integration through plugins/platform code |
| Stream formats | Broad MPV format/protocol support; exact codec support depends on packaged build | Strong Android streaming support; exact HLS/DASH/codec support depends on Media3 modules and device |
| Binary footprint | Typically larger because native MPV libraries are packaged | Can be smaller for an Android-only app, depending on modules/codecs |
| Android integration | Flutter plugin/native bridge and lifecycle integration required | Strong platform lifecycle, audio focus and media-session integration |
| Subtitle/audio controls | Broad MPV capability, but Flutter UI/control integration still required | Supported controls depend on selected Media3 modules and plugin surface |
| Device compatibility | Must validate packaged native ABI and codecs on target devices | Uses Android platform/media stack and device decoder capabilities |
| Maintenance | MPV version and native artifacts must be updated and reviewed | AndroidX Media3/plugin versions must be maintained |
| License review | MPV and included libraries require a separate license notice review | Media3 and Flutter plugin dependencies require their own license review |

## Decision

**No engine is selected yet.** The repository currently keeps the `AnimePlayer` abstraction without binding it to MediaKit or Media3. This is deliberate: neither engine has been benchmarked on the user's Realme 7 / Android 12 in this environment.

Before selecting an engine, run the same permitted test clips and stream types on the target device and record:
- cold-start time and first-frame time;
- memory and APK-size impact;
- sustained playback stability and thermal behavior;
- HLS/DASH/MP4 behavior where licensed test media is available;
- subtitle rendering, audio-track selection, seeking and playback-speed behavior;
- app background/foreground and audio-focus behavior;
- recovery after network loss and decoder errors.

Only after that comparison should one engine be selected and integrated. Do not claim player support until these device tests pass.
