import AppKit
import ServiceManagement
import SynclockCore
import SynclockMIDI

/// Preferences: General · Devices · About. Native system-appearance window (not
/// the popover's vibrant dark). Devices is the gear table; Link has no settings
/// of its own anymore (it's a single on/off toggle in the popover), so its live
/// status folds into General instead of a near-empty tab.
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
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Synclock Settings"
        window.center()
        super.init(window: window)

        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(tab(GeneralViewController(engine: engine), "General", "gearshape"))
        tabs.addTabViewItem(tab(devicesVC, "Devices", "pianokeys"))
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

// MARK: - Shared form helpers

enum PrefUI {
    /// A titled section: a bold header over a left-indented column of rows.
    static func section(_ title: String, _ rows: [NSView]) -> NSView {
        let header = NSTextField(labelWithString: title)
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        let body = NSStackView(views: rows)
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 6
        body.edgeInsets = NSEdgeInsets(top: 0, left: 2, bottom: 0, right: 0)
        let col = NSStackView(views: [header, body])
        col.orientation = .vertical
        col.alignment = .leading
        col.spacing = 8
        return col
    }

    static func help(_ text: String) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: text)
        t.font = .systemFont(ofSize: 11)
        t.textColor = .secondaryLabelColor
        t.isSelectable = false
        t.preferredMaxLayoutWidth = 460
        return t
    }

    static func dot(_ color: NSColor, size: CGFloat = 8) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = color.cgColor
        v.layer?.cornerRadius = size / 2
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }
}

// MARK: - General tab

final class GeneralViewController: NSViewController {
    private let engine: SyncEngine?
    private let cws = NSButton(checkboxWithTitle: "Keep sending clock while stopped", target: nil, action: nil)
    private let launch = NSButton(checkboxWithTitle: "Launch Synclock at login", target: nil, action: nil)
    private let linkDot = PrefUI.dot(.tertiaryLabelColor)
    private let linkStatus = NSTextField(labelWithString: "Off")

    init(engine: SyncEngine?) { self.engine = engine; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        cws.target = self; cws.action = #selector(toggleCWS(_:))
        launch.target = self; launch.action = #selector(toggleLaunchAtLogin(_:))
        linkStatus.font = .systemFont(ofSize: 13)

        let linkRow = NSStackView(views: [linkDot, linkStatus])
        linkRow.alignment = .centerY; linkRow.spacing = 7

        let stack = NSStackView(views: [
            PrefUI.section("Startup", [launch]),
            PrefUI.section("Clock", [cws, PrefUI.help("A continuous MIDI clock keeps gear locked even between songs; the transport buttons still control play and stop.")]),
            PrefUI.section("Ableton Link", [linkRow, PrefUI.help("Turn Link on or off from the menu bar. When on, tempo and start/stop stay in sync with every Link app and device on the network.")]),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
        ])
        view = container
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        cws.state = (engine?.clockWhileStopped ?? true) ? .on : .off
        launch.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        let snap = engine?.snapshot()
        if let snap, snap.linkEnabled {
            linkDot.layer?.backgroundColor = Theme.accent.cgColor
            linkStatus.stringValue = snap.linkIsReal
                ? "On · \(snap.peerCount) \(snap.peerCount == 1 ? "peer" : "peers")"
                : "On · unavailable"
        } else {
            linkDot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
            linkStatus.stringValue = "Off"
        }
    }

    @objc private func toggleCWS(_ s: NSButton) { engine?.setClockWhileStopped(s.state == .on) }
    @objc private func toggleLaunchAtLogin(_ s: NSButton) {
        do {
            if s.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Only works for an installed, signed .app; reflect reality in dev.
            s.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
            NSSound.beep()
        }
    }
}

// MARK: - Devices tab (the gear table)

final class DevicesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let engine: SyncEngine?
    private let table = NSTableView()
    private let emptyTitle = NSTextField(labelWithString: "No MIDI gear connected")
    private let emptyBody = NSTextField(wrappingLabelWithString: "Synclock still exposes a virtual source named “Synclock” for your DAW and Link-aware apps. Plug in gear and it shows up here.")
    private var rows: [OutputSettings] = []

    init(engine: SyncEngine?) { self.engine = engine; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let title = NSTextField(labelWithString: "Devices")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        let sub = NSTextField(labelWithString: "Pick what receives the clock. New gear stays off until you turn it on.")
        sub.font = .systemFont(ofSize: 11); sub.textColor = .secondaryLabelColor
        let header = NSStackView(views: [title, sub])
        header.orientation = .vertical; header.alignment = .leading; header.spacing = 2
        header.translatesAutoresizingMaskIntoConstraints = false

        let cols: [(String, String, CGFloat)] = [
            ("device", "Device", 200), ("status", "Status", 110),
            ("enabled", "Clock", 52), ("delay", "Sync delay", 96), ("transport", "Transport", 70),
        ]
        for (id, name, w) in cols {
            let col = NSTableColumn(identifier: .init(id))
            col.title = name; col.width = w
            table.addTableColumn(col)
        }
        table.dataSource = self
        table.delegate = self
        table.style = .inset
        table.usesAlternatingRowBackgroundColors = false
        table.gridStyleMask = []
        table.rowHeight = 34
        table.intercellSpacing = NSSize(width: 8, height: 6)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        emptyTitle.font = .systemFont(ofSize: 13, weight: .medium)
        emptyTitle.textColor = .secondaryLabelColor
        emptyBody.font = .systemFont(ofSize: 11)
        emptyBody.textColor = .tertiaryLabelColor
        emptyBody.alignment = .center
        emptyBody.preferredMaxLayoutWidth = 320
        let empty = NSStackView(views: [emptyTitle, emptyBody])
        empty.orientation = .vertical; empty.alignment = .centerX; empty.spacing = 6
        empty.translatesAutoresizingMaskIntoConstraints = false

        let panic = NSButton(title: "Panic", target: self, action: #selector(panic))
        panic.bezelStyle = .rounded
        panic.contentTintColor = .systemRed
        panic.setAccessibilityLabel("Panic — stop and send All Notes Off")
        let refresh = NSButton(title: "Refresh", target: self, action: #selector(refresh))
        refresh.bezelStyle = .rounded
        let buttons = NSStackView(views: [refresh, NSView(), panic])
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        [header, scroll, empty, buttons].forEach(container.addSubview)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            empty.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            empty.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            buttons.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
        view = container
    }

    func reload() {
        rows = engine?.sortedDevices ?? []
        let empty = rows.isEmpty
        emptyTitle.isHidden = !empty; emptyBody.isHidden = !empty
        table.reloadData()
    }

    override func viewWillAppear() { super.viewWillAppear(); reload() }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    private func statusColor(_ status: OutputStatus) -> NSColor {
        switch status.label.lowercased() {
        case let s where s.contains("active") || s.contains("on"): return Theme.accent
        case let s where s.contains("missing") || s.contains("offline"): return Theme.amber
        default: return .tertiaryLabelColor
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = rows[row]
        switch tableColumn?.identifier.rawValue {
        case "device":
            let field = NSTextField(string: device.displayName)
            field.isBordered = false
            field.drawsBackground = false
            field.isEditable = true
            field.delegate = self
            field.tag = Int(device.uniqueID)
            field.lineBreakMode = .byTruncatingTail
            field.setAccessibilityLabel("Device nickname")
            return field
        case "status":
            let status = engine?.status(for: device.uniqueID) ?? .off
            let label = NSTextField(labelWithString: status.label)
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            let r = NSStackView(views: [PrefUI.dot(statusColor(status)), label])
            r.alignment = .centerY; r.spacing = 6
            return r
        case "enabled":
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleEnabled(_:)))
            cb.state = device.enabled ? .on : .off
            cb.tag = Int(device.uniqueID)
            cb.setAccessibilityLabel("Send clock to \(device.displayName)")
            return cb
        case "delay":
            let label = NSTextField(labelWithString: "\(Int(device.syncDelayMs)) ms")
            label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            label.alignment = .right
            label.widthAnchor.constraint(equalToConstant: 44).isActive = true
            let stepper = NSStepper()
            stepper.minValue = -50; stepper.maxValue = 200; stepper.increment = 1
            stepper.doubleValue = device.syncDelayMs
            stepper.tag = Int(device.uniqueID)
            stepper.target = self; stepper.action = #selector(changeDelay(_:))
            stepper.setAccessibilityLabel("Sync delay for \(device.displayName) in milliseconds")
            let s = NSStackView(views: [label, stepper]); s.spacing = 4; s.alignment = .centerY
            return s
        case "transport":
            let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleTransport(_:)))
            cb.state = device.sendTransport ? .on : .off
            cb.tag = Int(device.uniqueID)
            cb.setAccessibilityLabel("Send start and stop to \(device.displayName)")
            return cb
        default: return nil
        }
    }

    @objc private func toggleEnabled(_ s: NSButton) { engine?.setDeviceEnabled(s.state == .on, id: Int32(s.tag)); reload() }
    @objc private func toggleTransport(_ s: NSButton) { engine?.setDeviceSendTransport(s.state == .on, id: Int32(s.tag)) }
    @objc private func changeDelay(_ s: NSStepper) { engine?.setDeviceSyncDelay(ms: s.doubleValue, id: Int32(s.tag)); reload() }
    @objc private func panic() { engine?.panic() }
    @objc private func refresh() { engine?.refreshDevices(); reload() }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        let id = Int32(field.tag)
        guard let device = rows.first(where: { $0.uniqueID == id }) else { return }
        let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = (trimmed.isEmpty || trimmed == device.systemName) ? "" : trimmed
        engine?.setDeviceNickname(nickname, id: id)
        reload()
    }
}

// MARK: - About tab

final class AboutViewController: NSViewController {
    override func loadView() {
        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true

        let name = NSTextField(labelWithString: "Synclock")
        name.font = .systemFont(ofSize: 22, weight: .semibold)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let ver = NSTextField(labelWithString: "Version \(version)")
        ver.font = .systemFont(ofSize: 11); ver.textColor = .secondaryLabelColor

        let tagline = NSTextField(labelWithString: "Master MIDI clock + Ableton Link for macOS.")
        tagline.font = .systemFont(ofSize: 12); tagline.textColor = .secondaryLabelColor

        let links = NSStackView(views: [
            linkButton("Website", "https://synclock.caiano.com"),
            linkButton("Source on GitHub", "https://github.com/hcaiano/synclock"),
            linkButton("Acknowledgements", "https://github.com/hcaiano/synclock/blob/main/THIRD-PARTY-NOTICES.md"),
        ])
        links.spacing = 16

        let license = NSTextField(labelWithString: "Free & open source · GPLv2-or-later · © 2026 Henrique Caiano")
        license.font = .systemFont(ofSize: 10); license.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [icon, name, ver, tagline, links, license])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(4, after: name)
        stack.setCustomSpacing(14, after: tagline)
        stack.setCustomSpacing(18, after: links)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        view = container
    }

    private func linkButton(_ title: String, _ url: String) -> NSButton {
        let b = NSButton(title: title, target: self, action: #selector(openLink(_:)))
        b.isBordered = false
        b.contentTintColor = .linkColor
        b.toolTip = url
        b.identifier = .init(url)
        return b
    }

    @objc private func openLink(_ s: NSButton) {
        guard let raw = s.identifier?.rawValue, let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }
}
