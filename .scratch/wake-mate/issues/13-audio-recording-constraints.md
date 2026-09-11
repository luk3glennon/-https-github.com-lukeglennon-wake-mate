Status: resolved
Type: grilling

## Question

Decide Alarm Call recording constraints: audio format/codec, maximum duration, and compression/bitrate target, balancing recording quality against upload size over the temporary-cloud transfer (relevant to cellular data use and transfer speed).

## Answer

**Codec/format**: AAC-HE (`kAudioFormatMPEG4AAC_HE`), mono, 44.1kHz sample rate, in an `.m4a` container, recorded via `AVAudioRecorder`.
- Chosen over Opus (no first-party iOS encoder — would require bundling a third-party library like a `libopus` Swift wrapper, an added dependency/maintenance cost for a solo-dev 4-week build) and over AAC-LC (needs a meaningfully higher bitrate to sound comparable on voice; HE-AAC's SBR technique is purpose-built for low-bitrate speech).
- MP3 and ALAC/linear PCM were ruled out: Apple exposes no MP3 *encoder* on iOS (decode-only), and lossless formats multiply file size 5-10x for no perceptible benefit on a spoken/sung voice clip.
- Mono halves raw sample data vs. stereo with zero quality loss for a single-speaker recording.
- Basis: Alarm Calls are expected to be overwhelmingly spoken voice notes (per the human), not music — HE-AAC's low-bitrate speech advantage applies directly.

**Maximum recording duration**: **30 seconds**.
- Long enough for a real clip with personality (joke, song snippet, voice message); short enough to bound worst-case size/transfer time and keep the in-app playback window tight once AlarmKit's short teaser fires (ticket 06).

**Bitrate**: **32 kbps** — Apple's own HLS authoring guidance recommendation for speech-only HE-AAC content. Gives clean, intelligible mono voice quality.

**Worst-case file size**: ~120 KB per Alarm Call (30s x 32kbps + `.m4a` container overhead). Trivial even on poor cellular (~64kbps effective throughput downloads the full clip in well under 20 seconds) — bitrate choice barely moves real-world transfer time at this duration; it's primarily a quality-floor decision, not a size one.

**Priority basis**: transfer size/speed was weighted over marginal quality gains — a slow or failed download risks the same "no Alarm Call available" outcome ticket 04's default-tone fallback already exists to handle, so minimizing that risk matters more than headroom for edge cases (background noise, singing).
