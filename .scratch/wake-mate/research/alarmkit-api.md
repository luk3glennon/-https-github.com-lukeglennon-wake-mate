# AlarmKit API research (for ticket 04: Alarm scheduling core)

Compiled 2026-09-13 from Apple's official AlarmKit documentation (fetched via
the `developer.apple.com/tutorials/data/documentation/...json` data endpoints,
which return the real structured doc content — plain page fetches of
`developer.apple.com/documentation/...` return only a JS-rendered shell with
no body text, so those were avoided) plus a few third-party AlarmKit articles
for gaps the official docs didn't cover in fetchable form. iOS 26.0+,
iPadOS 26.0+, Mac Catalyst 26.0+ throughout — no iOS 26.x point-release API
differences were found in official docs (see §10).

Confidence key: **[Official]** = fetched directly from an Apple docs JSON
endpoint. **[Blog]** = third-party article/forum, not independently verified
against Apple source — treat as lower confidence, verify on-device.

## 1. Authorization — [Official]

```swift
var authorizationState: AlarmManager.AuthorizationState { get }
func requestAuthorization() async throws -> AlarmManager.AuthorizationState
var authorizationUpdates: some AsyncSequence<AlarmManager.AuthorizationState, Never> { get }
enum AuthorizationState // cases seen in the wild: .notDetermined, .authorized, .denied [Blog-confirmed case names]
```

Typical pattern [Blog, matches official method/property shapes]:
```swift
switch AlarmManager.shared.authorizationState {
case .notDetermined:
    let state = try await AlarmManager.shared.requestAuthorization()
    // state == .authorized ?
case .authorized:
    // proceed
case .denied:
    // show a "go to Settings" message
@unknown default:
    break
}
```

## 2. Scheduling — [Official]

```swift
final class AlarmManager {
    static let shared: AlarmManager

    func schedule<Metadata>(
        id: Alarm.ID,                                    // Alarm.ID == UUID
        configuration: AlarmManager.AlarmConfiguration<Metadata>
    ) async throws -> Alarm

    func cancel(id: Alarm.ID) throws
    func stop(id: Alarm.ID) throws
    func countdown(id: Alarm.ID) throws   // manually trigger the countdown/snooze state on an alerting alarm
    func pause(id: Alarm.ID) throws       // only valid in countdown state
    func resume(id: Alarm.ID) throws      // only valid in paused state

    var alarms: [Alarm] { get async throws }
    var alarmUpdates: some AsyncSequence<[Alarm], Never> { get }  // an alarm missing from this stream is no longer scheduled
}
```

`AlarmManager.AlarmConfiguration<Metadata: AlarmMetadata>` — two initializer
shapes (the `appEntityIdentifier` ones are for App Shortcuts/Siri entity
linking, not needed here) and matching static factories `.alarm(...)` /
`.timer(...)`:

```swift
struct AlarmConfiguration<Metadata: AlarmMetadata> {
    init(
        countdownDuration: Alarm.CountdownDuration?,   // nil for a plain alert with no pre/post countdown UI
        schedule: Alarm.Schedule?,
        attributes: AlarmAttributes<Metadata>,
        stopIntent: (any LiveActivityIntent)?,
        secondaryIntent: (any LiveActivityIntent)?,
        sound: AlertConfiguration.AlertSound
    )
}
```
For a simple wake alarm (no countdown/paused UI), pass `countdownDuration: nil`
and only supply an `alert` in `AlarmPresentation` (§3).

## 3. Schedule, attributes, presentation

### `Alarm.Schedule` — [Official sample article + Blog for exact nested-type names]
```swift
enum Alarm.Schedule {
    case fixed(Date)                 // one-time, absolute; ignores timezone changes
    case relative(Alarm.Schedule.Relative)
}

struct Alarm.Schedule.Relative {
    struct Time { init(hour: Int, minute: Int) }
    enum Recurrence {
        case never
        case weekly([Locale.Weekday])   // Foundation's Locale.Weekday: .monday, .tuesday, ... .sunday
    }
    init(time: Time, repeats: Recurrence)
}
```
Usage:
```swift
let schedule = Alarm.Schedule.relative(.init(
    time: .init(hour: 7, minute: 0),
    repeats: repeatDays.isEmpty ? .never : .weekly(repeatDays)
))
```

### `AlarmAttributes<Metadata>` — [Official]
```swift
struct AlarmAttributes<Metadata: AlarmMetadata> {
    init(presentation: AlarmPresentation, metadata: Metadata, tintColor: Color)
}
```

### `AlarmMetadata` — [Official]
```swift
protocol AlarmMetadata: Decodable, Encodable, Hashable, Sendable {}
```
Can be an empty struct if no custom Live Activity content is needed — which
is the case here (no countdown/paused presentation, so no widget extension
content to feed). `struct WakeMateAlarmMetadata: AlarmMetadata {}` is enough.

### `AlarmPresentation` — [Official]
```swift
struct AlarmPresentation {
    init(alert: AlarmPresentation.Alert, countdown: AlarmPresentation.Countdown? = nil, paused: AlarmPresentation.Paused? = nil)
}
```
Only `alert` is required — omit `countdown`/`paused` entirely for a plain
alarm with no pre-alert countdown (this project's case: wake time fires
directly into the ring, no countdown phase).

### `AlarmPresentation.Alert` — [Official sample article, exact param list]
```swift
struct AlarmPresentation.Alert {
    init(
        title: LocalizedStringResource,
        stopButton: AlarmButton? = nil,        // omitting likely still needs *some* system-provided stop affordance — pass explicitly to control the label
        secondaryButton: AlarmButton? = nil,
        secondaryButtonBehavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = nil  // .countdown (re-arms a countdown/snooze) or .custom (runs secondaryIntent, e.g. open app)
    )
}
```

### `AlarmButton` — [Official]
```swift
struct AlarmButton {
    init(text: LocalizedStringResource, textColor: Color, systemImageName: String)
}
```
Note: some blog paraphrases show a shorthand `AlarmButton(label:)` — that is
**not** the real initializer; the official docs confirm `text`/`textColor`/
`systemImageName` are all required. Trust this signature over any blog
snippet that looks simpler.

## 4. Sound — [Official type existence confirmed; cases via WebSearch snippets, Blog-level confidence]

```swift
enum AlertConfiguration.AlertSound {  // actually lives under ActivityKit's namespace; AlarmKit re-exposes it as the `sound:` param type
    case `default`
    static func named(_ name: String) -> AlertConfiguration.AlertSound  // file must be in the app's main bundle or Library/Sounds
}
```
**Known bug, iOS 26.0**: multiple independent reports (developer forums,
Sept–Oct 2025) that `.named(_:)` plays a system error/timeout tone instead
of the custom file, regardless of format/location/size, on both simulator
and device. An Apple engineer confirmed a fix was planned for iOS 26.1. One
follow-up report (Oct 2025) said custom sounds played but didn't loop. This
predates the current date in this project's timeline by about a year, so it
has very likely shipped — **but verify the bundled default tone actually
loops/repeats correctly on the test device before relying on it**; if it
misbehaves, falling back to `.default` (system alarm tone) is a one-line
change isolated to the scheduler adapter.

## 5. Stop/snooze intents — [Official: the param type is `any LiveActivityIntent`; Blog: full example body]

`stopIntent` and `secondaryIntent` on `AlarmConfiguration` are typed
`(any LiveActivityIntent)?` **[Official]** — confirmed directly from the
`AlarmConfiguration` init signature, not inferred. `LiveActivityIntent`
**[Official]**:
```swift
protocol LiveActivityIntent: AppIntent /* : SystemIntent, PersistentlyIdentifiable, Sendable */
```
It's a plain `AppIntent` marked so the system can run it out-of-process
(app doesn't need to be foregrounded) and optionally start/update a Live
Activity. No extra required members beyond standard `AppIntent` conformance.

Shape confirmed by a working example [Blog]:
```swift
struct StopIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop"
    static var openAppWhenRun = false        // stop should NOT force-open the app

    @Parameter(title: "alarmID")
    var alarmID: String

    init(alarmID: String) { self.alarmID = alarmID }
    init() { self.alarmID = "" }             // parameterless init is required by AppIntent

    func perform() async throws -> some IntentResult {
        try AlarmManager.shared.stop(id: UUID(uuidString: alarmID)!)
        return .result()
    }
}
```
No source shows an explicit "snooze" method on `AlarmManager` — the pattern
is: the *secondary* button's behavior is set to `.countdown` in
`AlarmPresentation.Alert`, which makes tapping it call `AlarmManager.shared
.countdown(id:)` (or does so implicitly — no source shows the secondary
button's system action calling `countdown` explicitly, but `countdown(id:)`
existing as a distinct method alongside `stop`/`pause`/`resume`, plus
`.countdown` being a `secondaryButtonBehavior` case, strongly implies the
system wires the button to it automatically). A `secondaryIntent` alongside
`secondaryButtonBehavior: .countdown` most likely runs *in addition to* that
system-managed transition (e.g. for your own bookkeeping), not instead of
it — **this exact interaction (does the system call `countdown(id:)`
itself, or must `secondaryIntent.perform()` call it explicitly) was not
found in any fetched source and should be verified empirically on-device**:
schedule a test alarm, tap the secondary button, and check whether the
alarm re-alerts on its own with an intent that does nothing but log, versus
one that explicitly calls `AlarmManager.shared.countdown(id:)`.

## 6. Cancel — [Official]
`AlarmManager.shared.cancel(id: Alarm.ID) throws` — id is the same `UUID`
passed to `schedule(id:configuration:)`.

## 7. Observing state — [Official]
```swift
for await alarms in AlarmManager.shared.alarmUpdates {
    // alarms: [Alarm]; an alarm id missing from this array is no longer scheduled
}
```
`Alarm.State` **[Official existence confirmed, exact case names not
retrieved from a fetchable source — Blog/inference only]**: likely includes
something like `.scheduled`, `.countdown`, `.paused`, `.alerting` (this
matches the four presentation states — alert/countdown/paused, plus an
idle/scheduled state — but the literal case names were not confirmed
against Apple's JSON; grep the actual `Alarm.State` symbol once Xcode's
local docs are available, or check the compiler's error/autocomplete on
first build).

## 8. Widget extension — [Official + Blog, consistent across sources]
Only required if you supply `countdown`/`paused` `AlarmPresentation`
content for custom Live Activity / Dynamic Island / Lock Screen display —
those need a Widget Extension target implementing `ActivityConfiguration(for:
AlarmAttributes<Metadata>.self)`. A plain `alert`-only presentation (this
ticket's case — wake time fires straight into the ring, no pre-alert
countdown) does **not** need a widget extension for the ticket's stated
requirements (full-screen/Lock Screen alert UI is the system's own default
alert presentation, not custom Live Activity content). One source warns
that omitting the extension when you *do* use countdown presentations can
cause the system to unexpectedly dismiss alarms — not applicable here since
we're not using countdown presentations, but flagging in case ticket 20
(snooze/dismiss) or a later ticket ever wants a custom countdown UI.

## 9. Info.plist / entitlements — [Official + forum-confirmed]
Only `NSAlarmKitUsageDescription` (String) in Info.plist is required —
**confirmed via Apple's own
`documentation/BundleResources/Information-Property-List/NSAlarmKitUsageDescription`
page**. No entitlement exists or is needed:  a developer-forum thread
(Aug 2025) about a `com.apple.developer.alarmkit` entitlement build failure
turned out to be caused by an LLM having fabricated that entitlement key
into the project's `entitlements.plist`; removing the fake entry fixed the
build. **Do not add any `com.apple.developer.alarmkit` entitlement** — it
does not exist in Apple's developer portal and is not needed.

## 10. iOS 26.x version differences
No official changelog/diff was found in fetchable form. The one concrete
known point-release-relevant fact is the §4 custom-sound bug (iOS 26.0,
fix targeted for 26.1). Nothing else version-specific surfaced.

## Practical implication for ticket 04's design

Given the above, `AlarmManager`/`AlarmConfiguration`/`Alarm.Schedule`/
`AlarmPresentation` calls should be isolated behind one narrow protocol
(mirroring this codebase's existing `AuthServicing`/`FriendServicing`
pattern), so that (a) view models stay unit-testable without AlarmKit, and
(b) if any signature above turns out to be slightly off once compiled on a
real Mac/CI, the fix is contained to one file rather than scattered through
view models and tests.
