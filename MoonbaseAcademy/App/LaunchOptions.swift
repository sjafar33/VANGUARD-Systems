import Foundation

/// Launch arguments used only by UI tests: `-uiTesting` keeps test progress apart from a real player's save,
/// and `-resetProgress` starts that test save fresh.
enum LaunchOptions {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }
    static var isUITesting: Bool { arguments.contains("-uiTesting") }

    static func makeStore() -> SaveStore {
        guard isUITesting else { return SaveStore() }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = base.appendingPathComponent("MoonbaseAcademyUITest", isDirectory: true).appendingPathComponent("save.json")
        if arguments.contains("-resetProgress") {
            try? FileManager.default.removeItem(at: url)
        }
        return SaveStore(fileURL: url)
    }
}
