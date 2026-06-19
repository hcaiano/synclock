import AppKit
import Sparkle
import SynclockCore
import SynclockMIDI

/// LSUIElement agent. Left-click the status item opens the designed menu panel;
/// right-click shows a small fallback menu. The panel is the primary surface;
/// the Preferences/Devices window is Phase 7.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menuPanel: MenuBarPanel?
    private var popoverViewController: PopoverViewController?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var engine: SyncEngine?
    private var engineError: String?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            engine = try SyncEngine()
        } catch {
            engineError = "\(error)"
        }
        configureUpdater()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = menubarGlyph(playing: false)
            button.action = #selector(statusButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        if let engine {
            let vc = PopoverViewController(engine: engine)
            vc.openPreferences = { [weak self] in self?.openPreferences() }
            vc.checkForUpdates = { [weak self] in
                self?.closeMenuPanel()
                self?.updaterController?.checkForUpdates(nil)
            }
            popoverViewController = vc
        }
    }

    private func configureUpdater() {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let feed = info["SUFeedURL"] as? String, !feed.isEmpty,
              let key = info["SUPublicEDKey"] as? String, !key.isEmpty else {
            return
        }
        updaterController = SPUStandardUpdaterController(startingUpdater: true,
                                                        updaterDelegate: nil,
                                                        userDriverDelegate: nil)
        PreferencesWindowController.checkForUpdates = { [weak self] in
            self?.updaterController?.checkForUpdates(nil)
        }
    }

    /// The locked app template glyph from the app bundle, falling back to an
    /// SF Symbol when running outside a bundle (e.g. `swift run`).
    private func menubarGlyph(playing: Bool) -> NSImage? {
        let name = playing ? "menubar-playing" : "menubar-idle"
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            if let url2 = Bundle.main.url(forResource: "\(name)@2x", withExtension: "png"),
               let rep2 = NSImageRep(contentsOf: url2) {
                image.addRepresentation(rep2)
            }
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }
        let symbol = NSImage(systemSymbolName: playing ? "metronome.fill" : "metronome",
                             accessibilityDescription: "Synclock")
        symbol?.isTemplate = true
        return symbol
    }

    @objc private func statusButtonClicked() {
        guard let button = statusItem.button else { return }
        if let event = NSApp.currentEvent, event.type == .rightMouseUp || engine == nil {
            closeMenuPanel()
            showFallbackMenu(button)
            return
        }
        if menuPanel?.isVisible == true {
            closeMenuPanel()
        } else {
            showMenuPanel(relativeTo: button)
        }
    }

    private func showMenuPanel(relativeTo button: NSStatusBarButton) {
        guard let vc = popoverViewController,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen else { return }

        let panel = menuPanel ?? makeMenuPanel(contentViewController: vc)
        menuPanel = panel

        let content = vc.view
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let gap: CGFloat = 6
        let inset: CGFloat = 8
        let visible = screen.visibleFrame
        var origin = NSPoint(
            x: buttonFrame.midX - size.width / 2,
            y: buttonFrame.minY - size.height - gap
        )
        origin.x = min(max(origin.x, visible.minX + inset), visible.maxX - size.width - inset)
        if origin.y < visible.minY + inset {
            origin.y = buttonFrame.maxY + gap
        }

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()
        button.highlight(true)
        DispatchQueue.main.async { [weak self] in
            guard self?.menuPanel?.isVisible == true else { return }
            self?.installDismissalMonitors()
        }
    }

    private func makeMenuPanel(contentViewController vc: PopoverViewController) -> MenuBarPanel {
        let panel = MenuBarPanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.delegate = self
        panel.contentViewController = vc
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        return panel
    }

    private func closeMenuPanel() {
        guard let panel = menuPanel, panel.isVisible else { return }
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        removeDismissalMonitors()
    }

    private func installDismissalMonitors() {
        guard localMouseMonitor == nil, globalMouseMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            if self.isStatusButtonEvent(event) {
                self.closeMenuPanel()
                return nil
            }
            if self.shouldCloseMenuPanel(forLocalEvent: event) {
                self.closeMenuPanel()
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.closeMenuPanel()
        }
    }

    private func removeDismissalMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func shouldCloseMenuPanel(forLocalEvent event: NSEvent) -> Bool {
        guard menuPanel?.isVisible == true else { return false }
        if event.window === menuPanel { return false }
        return true
    }

    private func isStatusButtonEvent(_ event: NSEvent) -> Bool {
        if let button = statusItem.button,
           event.window === button.window,
           button.bounds.contains(button.convert(event.locationInWindow, from: nil)) {
            return true
        }
        return false
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
            addUpdaterItem(to: menu)
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Quit Synclock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // restore click-to-popover behaviour
    }

    @objc private func openPreferences() {
        closeMenuPanel()
        PreferencesWindowController.shared(engine: engine).show()
    }

    private func addUpdaterItem(to menu: NSMenu) {
        guard let updaterController else {
            let item = NSMenuItem(title: "Check for Updates…", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }
        let item = NSMenuItem(title: "Check for Updates…",
                              action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                              keyEquivalent: "")
        item.target = updaterController
        menu.addItem(item)
    }
}

private final class MenuBarPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === menuPanel else { return }
        closeMenuPanel()
    }
}
