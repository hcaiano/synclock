import AppKit
import SynclockMIDI

// Synclock — LSUIElement menubar agent. No Dock icon, no main window;
// everything lives in the status item + popover.
let app = NSApplication.shared
app.setActivationPolicy(.accessory) // agent: menu bar only (also LSUIElement in the bundle)

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
