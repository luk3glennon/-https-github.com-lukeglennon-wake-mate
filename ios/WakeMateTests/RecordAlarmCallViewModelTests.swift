import XCTest
@testable import WakeMate

@MainActor
final class RecordAlarmCallViewModelTests: XCTestCase {
    func test_startRecording_whenPermissionGranted_beginsRecordingImmediately() async {
        let audioRecorder = MockAudioRecorder()
        audioRecorder.permissionStatusToReturn = .granted
        let viewModel = makeViewModel(audioRecorder: audioRecorder)

        await viewModel.startRecording()

        XCTAssertTrue(viewModel.isRecording)
        XCTAssertFalse(viewModel.isPresentingConsentSheet)
        viewModel.cancelRecording()
    }

    func test_startRecording_whenPermissionDenied_surfacesErrorWithoutRecording() async {
        let audioRecorder = MockAudioRecorder()
        audioRecorder.permissionStatusToReturn = .denied
        let viewModel = makeViewModel(audioRecorder: audioRecorder)

        await viewModel.startRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_startRecording_whenPermissionUndetermined_presentsConsentSheetWithoutRecording() async {
        let audioRecorder = MockAudioRecorder()
        audioRecorder.permissionStatusToReturn = .undetermined
        let viewModel = makeViewModel(audioRecorder: audioRecorder)

        await viewModel.startRecording()

        XCTAssertTrue(viewModel.isPresentingConsentSheet)
        XCTAssertFalse(viewModel.isRecording)
    }

    func test_confirmConsentAndRecord_logsConsent_thenRecordsWhenPermissionGranted() async {
        let audioRecorder = MockAudioRecorder()
        audioRecorder.requestPermissionResult = true
        let consentService = MockConsentService()
        let viewModel = makeViewModel(audioRecorder: audioRecorder, consentService: consentService)

        await viewModel.confirmConsentAndRecord()

        XCTAssertEqual(consentService.logCallCount, 1)
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertFalse(viewModel.isPresentingConsentSheet)
        viewModel.cancelRecording()
    }

    func test_confirmConsentAndRecord_surfacesError_whenConsentLoggingFails() async {
        let audioRecorder = MockAudioRecorder()
        let consentService = MockConsentService()
        consentService.logResult = .failure(TestError.boom)
        let viewModel = makeViewModel(audioRecorder: audioRecorder, consentService: consentService)

        await viewModel.confirmConsentAndRecord()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isRecording)
    }

    func test_confirmConsentAndRecord_surfacesError_whenOSPermissionDenied() async {
        let audioRecorder = MockAudioRecorder()
        audioRecorder.requestPermissionResult = false
        let consentService = MockConsentService()
        let viewModel = makeViewModel(audioRecorder: audioRecorder, consentService: consentService)

        await viewModel.confirmConsentAndRecord()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isRecording)
    }

    func test_stopRecording_entersReviewState_withoutUploading() async {
        let audioRecorder = MockAudioRecorder()
        audioRecorder.stopRecordingDuration = 4
        let alarmCallService = MockAlarmCallService()
        let viewModel = makeViewModel(audioRecorder: audioRecorder, alarmCallService: alarmCallService)
        await viewModel.startRecording()

        await viewModel.stopRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertTrue(viewModel.isReviewingClip)
        XCTAssertFalse(viewModel.didSave)
        XCTAssertFalse(alarmCallService.didUpload)
        XCTAssertEqual(viewModel.elapsedSeconds, 4)
    }

    func test_saveClip_uploadsWithTrimmedTitle_andMarksSaved_onSuccess() async {
        let audioRecorder = MockAudioRecorder()
        audioRecorder.stopRecordingDuration = 4
        let alarmCallService = MockAlarmCallService()
        alarmCallService.uploadResult = .success(
            AlarmCall(id: UUID(), ownerID: UUID(), storagePath: "user/clip.m4a", durationSeconds: 4, createdAt: Date())
        )
        let viewModel = makeViewModel(audioRecorder: audioRecorder, alarmCallService: alarmCallService)
        await viewModel.startRecording()
        await viewModel.stopRecording()
        viewModel.title = "  Morning pep talk  "

        await viewModel.saveClip()

        XCTAssertTrue(viewModel.didSave)
        XCTAssertEqual(alarmCallService.lastUploadDuration, 4)
        XCTAssertEqual(alarmCallService.lastUploadTitle, "Morning pep talk")
    }

    func test_saveClip_sendsNilTitle_whenTitleLeftBlank() async {
        let audioRecorder = MockAudioRecorder()
        let alarmCallService = MockAlarmCallService()
        alarmCallService.uploadResult = .success(
            AlarmCall(id: UUID(), ownerID: UUID(), storagePath: "user/clip.m4a", durationSeconds: 3, createdAt: Date())
        )
        let viewModel = makeViewModel(audioRecorder: audioRecorder, alarmCallService: alarmCallService)
        await viewModel.startRecording()
        await viewModel.stopRecording()

        await viewModel.saveClip()

        XCTAssertTrue(alarmCallService.didUpload)
        XCTAssertNil(alarmCallService.lastUploadTitle)
    }

    func test_saveClip_surfacesError_whenUploadFails() async {
        let audioRecorder = MockAudioRecorder()
        let alarmCallService = MockAlarmCallService()
        alarmCallService.uploadResult = .failure(TestError.boom)
        let viewModel = makeViewModel(audioRecorder: audioRecorder, alarmCallService: alarmCallService)
        await viewModel.startRecording()
        await viewModel.stopRecording()

        await viewModel.saveClip()

        XCTAssertFalse(viewModel.didSave)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_cancelRecording_stopsWithoutUploading() async {
        let audioRecorder = MockAudioRecorder()
        let alarmCallService = MockAlarmCallService()
        let viewModel = makeViewModel(audioRecorder: audioRecorder, alarmCallService: alarmCallService)
        await viewModel.startRecording()

        viewModel.cancelRecording()

        XCTAssertFalse(viewModel.isRecording)
        XCTAssertTrue(audioRecorder.didCancel)
        XCTAssertFalse(alarmCallService.didUpload)
    }

    func test_cancelRecording_duringReview_discardsClipAndTitle() async {
        let audioRecorder = MockAudioRecorder()
        let alarmCallService = MockAlarmCallService()
        let viewModel = makeViewModel(audioRecorder: audioRecorder, alarmCallService: alarmCallService)
        await viewModel.startRecording()
        await viewModel.stopRecording()
        viewModel.title = "Draft"

        viewModel.cancelRecording()

        XCTAssertFalse(viewModel.isReviewingClip)
        XCTAssertEqual(viewModel.title, "")
        XCTAssertFalse(alarmCallService.didUpload)
    }

    private func makeViewModel(
        audioRecorder: AudioRecording,
        alarmCallService: AlarmCallServicing = MockAlarmCallService(),
        consentService: ConsentServicing = MockConsentService()
    ) -> RecordAlarmCallViewModel {
        RecordAlarmCallViewModel(audioRecorder: audioRecorder, alarmCallService: alarmCallService, consentService: consentService)
    }
}

private enum TestError: Error, LocalizedError {
    case boom
    var errorDescription: String? { "Something went wrong." }
}

private final class MockAudioRecorder: AudioRecording, @unchecked Sendable {
    var maxDuration: TimeInterval = 30
    var permissionStatusToReturn: MicPermissionStatus = .granted
    var requestPermissionResult = true
    var startRecordingResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/test-clip.m4a"))
    var stopRecordingDuration: TimeInterval = 3
    private(set) var didCancel = false

    func permissionStatus() -> MicPermissionStatus {
        permissionStatusToReturn
    }

    func requestPermission() async -> Bool {
        requestPermissionResult
    }

    func startRecording() throws -> URL {
        try startRecordingResult.get()
    }

    func stopRecording() -> TimeInterval {
        stopRecordingDuration
    }

    func cancelRecording() {
        didCancel = true
    }
}

private final class MockAlarmCallService: AlarmCallServicing, @unchecked Sendable {
    var uploadResult: Result<AlarmCall, Error> = .failure(TestError.boom)
    private(set) var didUpload = false
    private(set) var lastUploadDuration: Double?
    private(set) var lastUploadTitle: String?

    func upload(fileURL: URL, durationSeconds: Double, title: String?) async throws -> AlarmCall {
        didUpload = true
        lastUploadDuration = durationSeconds
        lastUploadTitle = title
        return try uploadResult.get()
    }

    func listLibrary() async throws -> [LibraryClip] {
        []
    }

    func fetchAlarmCall(id: UUID) async throws -> AlarmCall {
        throw TestError.boom
    }

    func downloadClipData(storagePath: String) async throws -> Data {
        throw TestError.boom
    }
}

private final class MockConsentService: ConsentServicing, @unchecked Sendable {
    var logResult: Result<Void, Error> = .success(())
    private(set) var logCallCount = 0

    func logMicRecordingConsent() async throws {
        logCallCount += 1
        try logResult.get()
    }
}
