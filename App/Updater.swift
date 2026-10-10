import AppKit
import Combine
import Sparkle

/// One updater for the app lifetime, independent of whether Settings is open.
@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var ready = false
    @Published private(set) var canCheck = false
    @Published private(set) var checking = false
    @Published private(set) var automaticChecks = false
    @Published private(set) var automaticDownloads = false
    @Published private(set) var allowsAutomaticUpdates = false
    @Published private(set) var lastCheck: Date?
    @Published private(set) var availableVersion: String?
    @Published private(set) var status = L("Not checked yet")
    @Published private(set) var failure: String?
    private var controller: SPUStandardUpdaterController?
    private var observations: Set<AnyCancellable> = []
    private var started = false

    func start() {
        guard !started else { return }; started = true
        #if DEBUG
        guard ProcessInfo.processInfo.environment["HERDRX_ENABLE_UPDATES"] == "1" else {
            status = L("Updates are disabled in development builds."); return
        }
        #endif
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        guard Data(base64Encoded: key)?.count == 32 else {
            status = L("This build has no valid update signing key."); return
        }
        let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates).receive(on: RunLoop.main).sink { [weak self] in self?.canCheck = $0 }.store(in: &observations)
        updater.publisher(for: \.automaticallyChecksForUpdates).receive(on: RunLoop.main).sink { [weak self] in self?.automaticChecks = $0 }.store(in: &observations)
        updater.publisher(for: \.automaticallyDownloadsUpdates).receive(on: RunLoop.main).sink { [weak self] in self?.automaticDownloads = $0 }.store(in: &observations)
        updater.publisher(for: \.allowsAutomaticUpdates).receive(on: RunLoop.main).sink { [weak self] in self?.allowsAutomaticUpdates = $0 }.store(in: &observations)
        updater.publisher(for: \.lastUpdateCheckDate).receive(on: RunLoop.main).sink { [weak self] in self?.lastCheck = $0 }.store(in: &observations)
        do { try updater.start(); ready = true }
        catch { failure = error.localizedDescription; status = L("Could not start the updater.") }
    }
    func setAutomaticChecks(_ enabled: Bool) { controller?.updater.automaticallyChecksForUpdates = enabled }
    func setAutomaticDownloads(_ enabled: Bool) { controller?.updater.automaticallyDownloadsUpdates = enabled }
    func check() {
        guard ready, canCheck else { return }
        failure = nil; checking = true; status = L("Checking for updates…")
        controller?.checkForUpdates(nil)
    }
    func feedURLString(for updater: SPUUpdater) -> String? {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["HERDRX_UPDATE_FEED_URL"],
           let url = URL(string: value), url.scheme == "http", ["127.0.0.1", "localhost"].contains(url.host ?? "") { return value }
        #endif
        return Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    }
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        checking = false; failure = nil; availableVersion = item.displayVersionString
        status = LF("Version %@ is available", item.displayVersionString)
    }
    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        checking = false; availableVersion = nil; failure = nil
        let reason = (error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber
        switch reason?.intValue {
        case Int(SPUNoUpdateFoundReason.onLatestVersion.rawValue), Int(SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue): status = L("You’re up to date")
        default: status = L("No compatible update is available.")
        }
    }
    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) { status = LF("Downloading version %@…", item.displayVersionString) }
    func userDidCancelDownload(_ updater: SPUUpdater) {
        checking = false; failure = nil
        status = L("Update canceled. You can try again later.")
    }
    func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) { status = L("Update downloaded and verified") }
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem, immediateInstallationBlock: @escaping () -> Void) -> Bool {
        status = L("Update ready. It will install when you quit HerdrX.")
        return false
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let canceledCheck = checking && error == nil
        checking = false
        if canceledCheck { status = L("Update canceled. You can try again later.") }
        guard let error = error as NSError?, !(error.domain == SUSparkleErrorDomain && error.code == Int(SUError.noUpdateError.rawValue)) else { return }
        if error.domain == SUSparkleErrorDomain && error.code == Int(SUError.installationCanceledError.rawValue) {
            status = L("Update canceled. You can try again later."); return
        }
        status = L("Could not complete the update. Try again."); failure = error.localizedDescription
    }
}
