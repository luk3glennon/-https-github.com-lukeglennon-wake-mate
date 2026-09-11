# Wake Mate — Domain Glossary

## Alarm Call
A recorded audio message (voice, song, joke, etc.) created by a user (the **Sender**). An Alarm Call is a reusable asset: one recording can be **Shared** to any number of friends independently. Per-tier send limits (e.g. free tier's "2 sends") count Shares, not distinct recordings.

## Alarm
A user's own scheduled wake-up entry: wake time, repeat days, snooze settings. A user may configure **multiple independent Alarms** (e.g. a weekday Alarm and a separate weekend Alarm). Each Alarm has its own Queue and Auto-play/Library Mode (see below). Distinct from an Alarm Call: an Alarm is the schedule; an Alarm Call is the audio it plays.

## Share
The act of sending an existing Alarm Call to a specific Friend Connection. One Alarm Call may have many Shares (fan-out to multiple friends).

## Friend Connection
A **mutual** relationship between two users, established only after both parties accept (Facebook-friend style, not one-directional following). Only connected friends can Share Alarm Calls with each other.

## Queue
Per-Alarm, FIFO-ordered list of received Alarm Calls not yet played, ordered by receipt time. **Locked**: the recipient cannot preview or listen to anything in the Queue before that Alarm actually fires.

## Library
Collection of Alarm Calls a user can pick from to Share or use in Library-override Mode. Includes both an Alarm Call the user created themselves (added the moment it's recorded) and one they received (auto-saved the moment it's played, i.e. the Alarm it was queued on fires). A single pool shared across all of a user's Alarms, not siloed per-Alarm — confirmed in ticket 10's data model. A Library Alarm Call can be attached to more than one of the user's own Alarms.

## Auto-play / Library Mode
Per-Alarm toggle deciding what plays when that Alarm fires:
- **Auto-play (default)**: plays the head of that Alarm's Queue (oldest unplayed received Alarm Call).
- **Library override**: plays a specific Alarm Call the user chose from their Library.

Receiving a new Alarm Call into an Alarm's Queue automatically resets that Alarm back to Auto-play mode.

## Wake Event
One occurrence of an Alarm firing: the span from its first ring through final dismiss (or snooze timeout with no tap-through), including every intermediate snooze re-ring. The Alarm Call resolved via `claim_queue_head` at the first tap-through into the app is fixed for the rest of the Wake Event — every snooze re-ring replays that same clip unchanged, never a fresh Queue head. See [ADR-0003](docs/adr/0003-native-alarmkit-snooze.md).
_Avoid_: "fire", "ring" alone to mean the whole cycle (ambiguous with a single bell/re-presentation within it).

## Handle

A unique, per-user identifying string, auto-generated at signup and editable later. Used to find and add a specific person via exact-match search, and to attribute a Friend Connection request (e.g. an Invite Link or a pending request names the sender's Handle).

## Invite Link

A permanent, personal link tied to one user's Handle, shared to invite someone into a Friend Connection. Works whether or not the recipient already has Wake Mate installed. Opening it never creates the connection by itself — it surfaces the same explicit-accept step as any other pending Friend Connection request.
