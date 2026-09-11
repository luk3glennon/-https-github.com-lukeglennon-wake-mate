Status: resolved
Type: grilling

## Question

The brief overloads "alarm" for both the scheduled wake-up entry and the recorded audio content. Should these be split into two distinct terms, and can a single recorded Alarm Call be sent to (and reused across) multiple friends/Alarms, or does each send need its own distinct recording?

## Answer

Split into two terms:
- **Alarm**: the scheduled wake-up entry (time, repeat days, snooze settings).
- **Alarm Call**: the recorded audio content, created once by a Sender.

An Alarm Call is a reusable asset: one recording can be Shared to any number of friends (fan-out), and once saved to a recipient's Library, that same Alarm Call can be attached to more than one of the recipient's own Alarms. Per-tier send limits (post-MVP monetization concern) would count Shares, not distinct recordings.

See CONTEXT.md (Alarm, Alarm Call, Share, Library).
