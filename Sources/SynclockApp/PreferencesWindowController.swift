import AppKit
import ServiceManagement
import SynclockCore
import SynclockMIDI

/// Preferences window: General · Devices · Link · About. The Devices tab is the
/// gear table (per-device enable / nickname / sync delay / transport / status).
final class PreferencesWindowController: NSWindowController {
    private static var instance: PreferencesWindowController?
    static func shared(engine: SyncEngine?) -> PreferencesWindowController {
        if let instance { return instance }
        let wc = PreferencesWindowController(engine: engine)
        instance = wc
        return wc
    }

    private let engine: SyncEngine?
    private let devicesVC: DevicesViewController

    init(engine: SyncEngine?) {
        self.engine = engine
        self.devicesVC = DevicesViewController(engine: engine)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Synclock Preferences"
        window.center()
        super.init(window: window)

        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab(GeneralViewController(engine: engine), "General", "gearshape"))
        tabs.addTabViewItem(tab(devicesVC, "Devices", "pianokeys"))
        tabs.addTabViewItem(tab(LinkViewController(engine: engine), "Link", "link"))
        tabs.addTabViewItem(tab(AboutViewController(), "About", "info.circle"))
        window.contentViewController = tabs
    }
    required init?(coder: NSCoder) { fatalError() }

    private func tab(_ vc: NSViewController, _ label: String, _ symbol: String) -> NSTabViewItem {
        let item = NSTabViewItem(viewController: vc)
        item.label = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        return item
    }

    func show() {
        devicesVC.reload()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Devices tab (the gear table)

final class DevicesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let engine: SyncEngine?
    private let table = NSTableView()
    private var rows: [OutputSettings] = []

    init(engine: SyncEngine?) { self.engine = engine; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))

        let title = NSTextField(labelWithString: "Devices")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let sub = NSTextField(labelWithString: "Choose what receives clock. New gear stays off until you enable it.")
        sub.font = .systemFont(ofSize: 11); sub.textColor = .secondaryLabelColor

        for (id, w) in [("status", 70), ("device", 220), ("enabled", 60), ("delay", 90), ("transport", 80)] {
            let col = NSTableColumn(identifier: .init(id))
            col.title = id.capitalized
            col.width = CGFloat(w)
            table.addTableColumn(col)
        }
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 38

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let panic = NSButton(title: "Panic — Stop & All Notes Off", target: self, action: #selector(panic))
        panic.bezelStyle = .rounded
        let refresh = NSButton(title: "Refresh", target: self, action: #selector(refresh))
        refresh.bezelStyle = .rounded
        let buttons = NSStackView(views: [refresh, NSView(), panic])
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [title, sub])
        header.orientation = .vertical; header.alignment = .leading; header.spacing = 2
        header.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(header); container.addSubview(scroll); container.addSubview(buttons)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        view = container
    }

    func reload() {
        rows = engine?.sortedDevices ?? []
        table.reloadData()
    }

    override func viewWillAppear() { super.viewWillAppear(); reload() }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = rows[row]
        switch tableColumn?.identifier.rawValue {
        case "status":
            let status = engine?.status(for: device.uniqueID) ?? .off
            return NSTextField(labelWithString: status.label)
        case "device":
            return NSTextField(labelWithString: device.displayName)
        case "enabled":
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            cb.state = device.enabled ? .on : .off
            cb.tag = Int(device.uniqueID)
            return cb
        case "delay":
            let label = NSTextField(labelWithString: "\(Int(device.syncDelayMs)) ms")
            let stepper = NSStepper()
            stepper.minValue = -50; stepper.maxValue = 200; stepper.increment = 1
            stepper.doubleValue = device.syncDelayMs
            stepper.tag = Int(device.uniqueID)
            stepper.target = self; stepper.action = #selector(changeDelay(_:))
            let s = NSStackView(views: [label, stepper]); s.spacing = 4
            return s
        case "transport":
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleTransport(_:)))
            cb.state = device.sendTransport ? .on : .off
            cb.tag = Int(device.uniqueID)
            return cb
        default: return nil
        }
    }

    @objc private func toggleEnabled(_ s: NSButton) { engine?.setDeviceEnabled(s.state == .on, id: Int32(s.tag)); reload() }
    @objc private func toggleTransport(_ s: NSButton) { engine?.setDeviceSendTransport(s.state == .on, id: Int32(s.tag)) }
    @objc private func changeDelay(_ s: NSStepper) { engine?.setDeviceSyncDelay(ms: s.doubleValue, id: Int32(s.tag)); reload() }
    @objc private func panic() { engine?.panic() }
    @objc private func refresh() { engine?.refreshDevices(); reload() }
}

// MARK: - General tab

final class GeneralViewController: NSViewController {
    private let engine: SyncEngine?
    init(engine: SyncEngine?) { self.engine = engine; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let cws = NSButton(checkboxWithTitle: "Keep sending clock while stopped",
                           target: self, action: #selector(toggleCWS(_:)))
        cws.state = .on // default ON; reflects settings on next load
        let note = NSTextField(labelWithString: "Continuous MIDI clock keeps gear locked; transport controls play/stop.")
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor

        let launch = NSButton(checkboxWithTitle: "Launch Synclock at login",
                              target: self, action: #selector(toggleLaunchAtLogin(_:)))
        launch.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        let stack = NSStackView(views: [cws, note, launch])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        ])
        view = container
    }
    @objc private func toggleCWS(_ s: NSButton) { engine?.setClockWhileStopped(s.state == .on) }

    @objc private func toggleLaunchAtLogin(_ s: NSButton) {
        do {
            if s.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Registration only works for an installed, signed .app; ignore in dev.
            s.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            NSSound.beep()
        }
    }
}

// MARK: - Link tab

final class LinkViewController: NSViewController {
    private let engine: SyncEngine?
    private let label = NSTextField(labelWithString: "")
    init(engine: SyncEngine?) { self.engine = engine; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        ])
        view = container
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        let snap = engine?.snapshot()
        label.stringValue = snap.map { "Mode: \($0.mode.label) · Peers: \($0.peerCount) · Link \($0.linkIsReal ? "active" : "unavailable")" }
            ?? "Link unavailable"
    }
}

// MARK: - About tab

final class AboutViewController: NSViewController {
    override func loadView() {
        let title = NSTextField(labelWithString: "Synclock")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let tagline = NSTextField(labelWithString: "Master MIDI clock + Ableton Link for macOS.")
        tagline.textColor = .secondaryLabelColor
        let license = NSTextField(labelWithString: "Free & open source — GPLv2-or-later. © 2026 Henrique Caiano.")
        license.font = .systemFont(ofSize: 11); license.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, tagline, license])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
        ])
        view = container
    }
}
