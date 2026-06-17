import AppKit
import SynclockCore
import SynclockMIDI

// Synclock — LSUIElement menubar agent. No Dock icon, no main window;
// everything lives in the status item + popover.
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // agent: menu bar only (also LSUIElement in the bundle)

// Hidden dev path: SYNCLOCK_POPOVER_SELF_TEST=1 instantiates the real popover
// controls, clicks them through AppKit target/action, asserts SyncEngine
// effects, and exits. External AX automation cannot reliably enumerate
// NSStatusItem popovers, so this gives deterministic regression proof.
if ProcessInfo.processInfo.environment["SYNCLOCK_POPOVER_SELF_TEST"] == "1" {
    let temp = FileManager.default.temporaryDirectory
        .appendingPathComponent("synclock-popover-self-test-\(UUID().uuidString)", isDirectory: true)
    let store = SettingsStore(directory: temp)
    do {
        try store.save(SynclockSettings(virtualPortName: "Synclock Self Test"))
        let engine = try SyncEngine(store: store)
        let vc = PopoverViewController(engine: engine)
        let checks = try vc.runControlSelfTest()
        print("OK: popover controls self-test passed (\(checks.count) checks)")
        for check in checks { print("- \(check)") }
        try? FileManager.default.removeItem(at: temp)
        exit(0)
    } catch {
        fputs("FAIL: popover controls self-test failed: \(error)\n", stderr)
        try? FileManager.default.removeItem(at: temp)
        exit(1)
    }
}

// Hidden dev path: SYNCLOCK_UISHOT=<path> renders the popover offscreen to PNG
// for design verification, then exits. Not part of the shipped app.
if let shotPath = ProcessInfo.processInfo.environment["SYNCLOCK_UISHOT"],
   let engine = try? SyncEngine() {
    let vc = PopoverViewController(engine: engine)
    let v = vc.view
    vc.viewWillAppear()
    v.layoutSubtreeIfNeeded()
    v.setFrameSize(v.fittingSize)
    v.layoutSubtreeIfNeeded()
    if let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: shotPath))
    }
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
