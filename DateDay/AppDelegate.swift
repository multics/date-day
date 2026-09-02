import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var updateTimer: Timer?
    private var settingsWindowController: SettingsWindowController?
    private let launchAtLoginItem = NSMenuItem(
        title: "Launch at Login",
        action: nil,
        keyEquivalent: ""
    )
    private let launchAtLoginMessage = NSMenuItem(
        title: "Approval is required in System Settings.",
        action: nil,
        keyEquivalent: ""
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        observeSystemChanges()
        startUpdateTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshLaunchAtLoginStatus()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "DateDayStatusItem"

        if let button = item.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleNone
            button.toolTip = "Date Day"
            button.setAccessibilityLabel("Current weekday and date")
        }

        let menu = NSMenu()
        menu.delegate = self

        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        launchAtLoginMessage.isEnabled = false
        menu.addItem(launchAtLoginMessage)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About Date Day",
            action: #selector(showAboutPanel),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Date Day",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item

        updateDate()
        refreshLaunchAtLoginStatus()
    }

    private func observeSystemChanges() {
        let notifications: [Notification.Name] = [
            NSLocale.currentLocaleDidChangeNotification,
            .NSSystemTimeZoneDidChange,
            .NSSystemClockDidChange,
            .NSCalendarDayChanged,
            .dateDayLocalePreferenceDidChange,
            .dateDayWorldClocksDidChange,
            NSWorkspace.didWakeNotification,
        ]

        for name in notifications {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(updateDate),
                name: name,
                object: nil
            )
        }
    }

    private func startUpdateTimer() {
        let timer = Timer(
            timeInterval: 30,
            target: self,
            selector: #selector(updateDate),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

    @objc private func updateDate() {
        let now = Date.now
        let locale = LocalePreference.currentLocale
        let clocks = WorldClockPreference.visibleClocks

        let image = StatusContentRenderer.image(
            date: now,
            locale: locale,
            clocks: clocks
        )

        guard let statusItem, let button = statusItem.button else {
            return
        }

        statusItem.length = image.size.width
        button.image = image
        let dateDescription = DateDayFormatter.string(
            for: now,
            locale: locale,
            timeZone: .autoupdatingCurrent
        )
        let clockDescriptions = clocks.map { clock in
            let time = DateDayFormatter.timeString(
                for: now,
                locale: locale,
                timeZone: clock.timeZone
            )
            return "\(clock.label) \(time)"
        }
        button.setAccessibilityValue(
            ([dateDescription] + clockDescriptions).joined(separator: ", ")
        )
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            showError(error)
        }
    }

    private func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginItem.state = status == .enabled ? .on : .off
        launchAtLoginMessage.isHidden = status != .requiresApproval
    }

    @objc private func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert(error: error)
        alert.runModal()
    }
}
