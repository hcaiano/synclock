import AppKit
import SynclockCore
import SynclockMIDI

/// LSUIElement agent. Left-click the status item opens the designed popover;
/// right-click shows a small fallback menu. The popover (Phase 6) is the
/// primary surface; the Preferences/Devices window is Phase 7.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var engine: SyncEngine?
    private var engineError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            engine = try SyncEngine()
        } catch {
            engineError = "\(error)"
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "metronome", accessibilityDescription: "Synclock")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(statusButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if let engine {
            popover.behavior = .transient
            let vc = PopoverViewController(engine: engine)
            vc.openPreferences = { [weak self] in self?.openPreferences() }
            popover.contentViewController = vc
        }
    }

    @objc private func statusButtonClicked() {
        guard let button = statusItem.button else { return }
        if let event = NSApp.currentEvent, event.type == .rightMouseUp || engine == nil {
            showFallbackMenu(button)
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showFallbackMenu(_ button: NSStatusBarButton) {
        let menu = NSMenu()
        if engine == nil {
            let item = NSMenuItem(title: "MIDI unavailable", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            if let engineError {
                let d = NSMenuItem(title: engineError, action: nil, keyEquivalent: "")
                d.isEnabled = false
                menu.addItem(d)
            }
            menu.addItem(.separator())
        } else {
            menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",").target = self
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Quit Synclock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // restore click-to-popover behaviour
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared(engine: engine).show()
    }
}
