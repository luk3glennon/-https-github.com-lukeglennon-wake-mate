Status: resolved
Type: grilling

## Question

How do received Alarm Calls map onto a recipient's Alarm(s)? Specifically: how many independent Alarms does a user configure, can they preview a received Alarm Call before wake time, how is the Alarm Call to play chosen when multiple are queued, and does a played Alarm Call get saved for reuse?

## Answer

- A user may configure **multiple independent Alarms** (e.g. a weekday Alarm and a separate weekend Alarm), each with its own Queue and Auto-play/Library Mode.
- Each Alarm's **Queue** is FIFO-ordered by receipt time and **locked**: the recipient cannot preview/listen to anything in it before that Alarm fires.
- Per-Alarm **Mode** toggle: **Auto-play** (default) plays the head of the Queue; **Library override** plays a specific Alarm Call the user chose from their Library. Receiving a new Alarm Call resets the Alarm back to Auto-play mode.
- Once an Alarm Call is played (its Alarm fires), it is **automatically saved to the Library** for future reuse.
- If an Alarm fires in Auto-play mode with an empty Queue and an empty Library, it falls back to a bundled default alarm tone (see ticket 04).

See CONTEXT.md (Alarm, Queue, Library, Auto-play / Library Mode).
