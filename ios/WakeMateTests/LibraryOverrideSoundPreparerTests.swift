import XCTest
@testable import WakeMate

final class LibraryOverrideSoundPreparerTests: XCTestCase {
    private var soundsDirectory: URL!

    override func setUp() {
        super.setUp()
        soundsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: soundsDirectory)
        super.tearDown()
    }

    func test_prepareSoundFileName_returnsNil_forAnAutoPlayAlarm() async {
        let alarmCallService = MockAlarmCallService()
        let preparer = LibraryOverrideSoundPreparer(alarmCallService: alarmCallService, soundsDirectory: soundsDirectory)
        let alarm = makeAlarm(mode: .autoPlay, libraryOverrideAlarmCallID: nil)

        let fileName = await preparer.prepareSoundFileName(for: alarm)

        XCTAssertNil(fileName)
        XCTAssertFalse(alarmCallService.didFetchAlarmCall)
    }

    func test_prepareSoundFileName_returnsNil_forALibraryOverrideAlarmWithNoClip() async {
        let alarmCallService = MockAlarmCallService()
        let preparer = LibraryOverrideSoundPreparer(alarmCallService: alarmCallService, soundsDirectory: soundsDirectory)
        let alarm = makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: nil)

        let fileName = await preparer.prepareSoundFileName(for: alarm)

        XCTAssertNil(fileName)
        XCTAssertFalse(alarmCallService.didFetchAlarmCall)
    }

    func test_prepareSoundFileName_downloadsAndWritesTheClip_whenNotAlreadyCached() async {
        let clipID = UUID()
        let alarmCallService = MockAlarmCallService()
        alarmCallService.fetchResult = .success(
            AlarmCall(id: clipID, ownerID: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, createdAt: Date())
        )
        alarmCallService.downloadResult = .success(Data([0x01, 0x02, 0x03]))
        let preparer = LibraryOverrideSoundPreparer(alarmCallService: alarmCallService, soundsDirectory: soundsDirectory)
        let alarm = makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: clipID)

        let fileName = await preparer.prepareSoundFileName(for: alarm)

        XCTAssertEqual(fileName, "library-override-\(clipID.uuidString).m4a")
        XCTAssertTrue(alarmCallService.didFetchAlarmCall)
        XCTAssertEqual(alarmCallService.lastDownloadedStoragePath, "user/clip.m4a")
        let writtenData = try? Data(contentsOf: soundsDirectory.appendingPathComponent(fileName!))
        XCTAssertEqual(writtenData, Data([0x01, 0x02, 0x03]))
    }

    func test_prepareSoundFileName_skipsRedownloading_whenAlreadyCached() async throws {
        let clipID = UUID()
        let fileName = "library-override-\(clipID.uuidString).m4a"
        try FileManager.default.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)
        try Data([0xAA]).write(to: soundsDirectory.appendingPathComponent(fileName))
        let alarmCallService = MockAlarmCallService()
        let preparer = LibraryOverrideSoundPreparer(alarmCallService: alarmCallService, soundsDirectory: soundsDirectory)
        let alarm = makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: clipID)

        let resolvedFileName = await preparer.prepareSoundFileName(for: alarm)

        XCTAssertEqual(resolvedFileName, fileName)
        XCTAssertFalse(alarmCallService.didFetchAlarmCall)
    }

    func test_prepareSoundFileName_returnsNil_whenFetchingTheClipFails() async {
        let alarmCallService = MockAlarmCallService()
        alarmCallService.fetchResult = .failure(TestError.boom)
        let preparer = LibraryOverrideSoundPreparer(alarmCallService: alarmCallService, soundsDirectory: soundsDirectory)
        let alarm = makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: UUID())

        let fileName = await preparer.prepareSoundFileName(for: alarm)

        XCTAssertNil(fileName)
    }

    func test_prepareSoundFileName_returnsNil_whenDownloadingTheClipFails() async {
        let clipID = UUID()
        let alarmCallService = MockAlarmCallService()
        alarmCallService.fetchResult = .success(
            AlarmCall(id: clipID, ownerID: UUID(), storagePath: "user/clip.m4a", durationSeconds: 5, createdAt: Date())
        )
        alarmCallService.downloadResult = .failure(TestError.boom)
        let preparer = LibraryOverrideSoundPreparer(alarmCallService: alarmCallService, soundsDirectory: soundsDirectory)
        let alarm = makeAlarm(mode: .libraryOverride, libraryOverrideAlarmCallID: clipID)

        let fileName = await preparer.prepareSoundFileName(for: alarm)

        XCTAssertNil(fileName)
    }

    private func makeAlarm(mode: AlarmMode, libraryOverrideAlarmCallID: UUID?) -> Alarm {
        Alarm(
            id: UUID(),
            ownerID: UUID(),
            label: "Weekdays",
            wakeTime: WakeTime(hour: 7, minute: 0),
            repeatDays: [],
            mode: mode,
            libraryOverrideAlarmCallID: libraryOverrideAlarmCallID,
            snoozeEnabled: true,
            snoozeDurationMinutes: 9,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private enum TestError: Error, LocalizedError {
    case boom
    var errorDescription: String? { "Something went wrong." }
}

private final class MockAlarmCallService: AlarmCallServicing, @unchecked Sendable {
    var fetchResult: Result<AlarmCall, Error> = .failure(TestError.boom)
    var downloadResult: Result<Data, Error> = .failure(TestError.boom)
    private(set) var didFetchAlarmCall = false
    private(set) var lastDownloadedStoragePath: String?

    func upload(fileURL: URL, durationSeconds: Double) async throws -> AlarmCall {
        throw TestError.boom
    }

    func listLibrary() async throws -> [LibraryClip] {
        []
    }

    func fetchAlarmCall(id: UUID) async throws -> AlarmCall {
        didFetchAlarmCall = true
        return try fetchResult.get()
    }

    func downloadClipData(storagePath: String) async throws -> Data {
        lastDownloadedStoragePath = storagePath
        return try downloadResult.get()
    }
}
