import Foundation
import AlarmKit
import SwiftUI
import os

/// No custom Live Activity/Dynamic Island content is needed for this ticket
/// (alert-only presentation, see .scratch/wake-mate/research/alarmkit-api.md
/// §8) so this carries nothing.
struct WakeMateAlarmMetadata: AlarmMetadata {}

/// The real AlarmKit-backed implementation of the two protocols
/// AlarmSyncCoordinator depends on (AlarmSyncCoordinator.swift). Every
/// `import AlarmKit` call in this app lives in this one file, by design —
/// see AlarmSyncCoordinator's header comment. Note this file also defines
/// our own `Alarm` model (Alarm.swift); wherever the AlarmKit framework type
/// is meant instead, it's written out as `AlarmKit.Alarm` to avoid the two
/// colliding.
///
/// API shapes below come from .scratch/wake-mate/research/alarmkit-api.md.
/// Two things there are flagged as not confirmed from an official source and
/// should be checked against the first real compiler/CI run:
///  - whether tapping the alert's secondary (.countdown-behavior) button
///    already re-arms the ring on its own, making SnoozeAlarmIntent's
///    explicit `countdown(id:)` call redundant-but-harmless, or necessary
///  - the exact case names on `AlarmKit.Alarm.State`; `isActiveState` below
///    only relies on `.scheduled` existing, and treats every other case as
///    mid-Wake-Event so it fails on the safe side of ADR-0003.
final class AlarmKitScheduler: AlarmSchedulingServicing, AlarmActivityTracking, Sendable {
    /// Must match the file added at ios/WakeMate/Sounds/default_alarm_tone.wav
    /// (bundled into the app target). This is a placeholder tone — there's
    /// no real designed alarm sound yet, see the ticket write-up. Used for
    /// every non-library_override alarm, and as the fallback for a
    /// library_override alarm whose clip couldn't be prepared in time (see
    /// `soundPreparer`).
    ///
    /// Unlike UNNotificationSoundName, AlertConfiguration.AlertSound.named(_:)
    /// requires the file extension in the name — omitting it silently falls
    /// back to the system's own alarm tone instead of erroring. (Confirmed
    /// on-device 2026-09-13: playing the system default tone, not the bundled
    /// one, was this bug, not the separate iOS 26.0 .named(_:) issue noted
    /// below, since the device was already on 26.6.1.)
    private let soundName = "default_alarm_tone.wav"

    /// Per ADR-0003, snooze duration is fixed/global for the MVP, not
    /// per-alarm — matches the `snooze_duration_minutes` default in
    /// supabase/migrations/20260913090000_alarms.sql. `postAlert` is what
    /// actually governs the re-ring length once the alert's secondary
    /// (.countdown-behavior) button is tapped; `preAlert` stays nil since
    /// this app has no pre-alert countdown UI.
    ///
    /// Risk flagged during review, not yet verifiable without a compiler/
    /// device: some sources say a non-nil countdown duration expects a
    /// widget extension (custom Live Activity content for the countdown
    /// state) — this app deliberately has none, since the ticket only asks
    /// for the system's own alert UI. If the first real device/CI run shows
    /// snooze doesn't re-ring without one, adding a minimal widget
    /// extension is the fix; nothing else here should need to change.
    private let snoozeDuration: AlarmKit.Alarm.CountdownDuration = .init(preAlert: nil, postAlert: 9 * 60)

    private let soundPreparer: LibraryOverrideSoundPreparing
    private let activeIDs = OSAllocatedUnfairLock(initialState: Set<UUID>())
    private let observeTask: Task<Void, Never>

    init(soundPreparer: LibraryOverrideSoundPreparing) {
        self.soundPreparer = soundPreparer
        let activeIDs = self.activeIDs
        observeTask = Task {
            for await alarms in AlarmManager.shared.alarmUpdates {
                let active = Set(alarms.filter(Self.isActiveState).map(\.id))
                activeIDs.withLock { $0 = active }
            }
        }
    }

    deinit {
        observeTask.cancel()
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return true
        case .notDetermined:
            let state = try? await AlarmManager.shared.requestAuthorization()
            return state == .authorized
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func scheduledAlarmIDs() async -> Set<UUID> {
        let alarms = (try? await AlarmManager.shared.alarms) ?? []
        return Set(alarms.map(\.id))
    }

    func schedule(_ alarm: Alarm) async throws {
        let schedule = AlarmKit.Alarm.Schedule.relative(
            .init(
                time: .init(hour: alarm.wakeTime.hour, minute: alarm.wakeTime.minute),
                repeats: alarm.repeatDays.isEmpty ? .never : .weekly(alarm.repeatDays.compactMap(Self.weekday(forRepeatDay:)))
            )
        )

        let title: LocalizedStringResource = {
            guard let label = alarm.label, !label.isEmpty else { return "Wake up" }
            return LocalizedStringResource(stringLiteral: label)
        }()

        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
                secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz"),
                secondaryButtonBehavior: .countdown
            )
        )

        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: WakeMateAlarmMetadata(),
            tintColor: .accentColor
        )

        // A library_override alarm gets its own recorded clip as the actual
        // alert sound (materialized into Library/Sounds by soundPreparer)
        // rather than only ever hearing this fall back to the placeholder
        // tone when preparation fails or hasn't happened yet. This is the
        // iOS 26.0 .named(_:) issue referenced in soundName's doc comment
        // above: a reported bug where a custom file plays a system error/
        // timeout tone instead, with a fix only targeted (not confirmed
        // shipped) for 26.1 — see .scratch/wake-mate/research/alarmkit-api.md
        // §4. Needs on-device confirmation, same as everything else about
        // fire-time playback in this ticket.
        let resolvedSoundName = await soundPreparer.prepareSoundFileName(for: alarm) ?? soundName

        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: snoozeDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: alarm.id.uuidString),
            secondaryIntent: SnoozeAlarmIntent(alarmID: alarm.id.uuidString),
            sound: .named(resolvedSoundName)
        )

        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration)
    }

    func cancel(alarmID: UUID) async throws {
        try AlarmManager.shared.cancel(id: alarmID)
    }

    func isActive(alarmID: UUID) -> Bool {
        activeIDs.withLock { $0.contains(alarmID) }
    }

    /// See `AlarmActivityTracking.refreshActiveAlarms` — this exists so a
    /// caller isn't at the mercy of `alarmUpdates`' first emission arriving
    /// before it needs a trustworthy `isActive` answer (e.g. a cold-launch
    /// sync racing the stream's setup).
    func refreshActiveAlarms() async {
        let alarms = (try? await AlarmManager.shared.alarms) ?? []
        let active = Set(alarms.filter(Self.isActiveState).map(\.id))
        activeIDs.withLock { $0 = active }
    }

    /// See the file header: only `.scheduled` is relied on as "not yet
    /// fired"; every other (unconfirmed-by-name) state is treated as
    /// mid-Wake-Event so a naming surprise fails toward never touching a
    /// ringing/snoozed alarm.
    private static func isActiveState(_ alarm: AlarmKit.Alarm) -> Bool {
        if case .scheduled = alarm.state {
            return false
        }
        return true
    }

    /// Our `Alarm.repeatDays` numbering matches `Calendar.Component.weekday`
    /// (1 = Sunday ... 7 = Saturday), documented on the `Alarm` model itself.
    private static func weekday(forRepeatDay day: Int) -> Locale.Weekday? {
        switch day {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
}
