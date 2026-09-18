import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
    private let weatherStore: WeatherStore
    private let tabView = NSTabView()
    private let localePicker = NSPopUpButton()
    private let previewLabel = NSTextField(labelWithString: "")
    private let showClocksCheckbox = NSButton(
        checkboxWithTitle: "Show world clocks",
        target: nil,
        action: nil
    )
    private let clockRows = NSStackView()
    private let addClockButton = NSButton(
        title: "Add Time Zone",
        target: nil,
        action: nil
    )
    private let weatherEnabledCheckbox = NSButton(
        checkboxWithTitle: "Show temperature in the menu bar",
        target: nil,
        action: nil
    )
    private let automaticLocationRadio = NSButton(
        radioButtonWithTitle: "Automatic (use this Mac’s location)",
        target: nil,
        action: nil
    )
    private let manualLocationRadio = NSButton(
        radioButtonWithTitle: "Manual",
        target: nil,
        action: nil
    )
    private let authorizationLabel = NSTextField(labelWithString: "")
    private let locationSearchField = NSSearchField()
    private let searchButton = NSButton(
        title: "Search",
        target: nil,
        action: nil
    )
    private let locationResultsPicker = NSPopUpButton()
    private let currentWeatherLocationLabel = NSTextField(labelWithString: "")
    private let refreshIntervalPicker = NSPopUpButton()
    private let weatherStatusLabel = NSTextField(wrappingLabelWithString: "")
    private let refreshWeatherButton = NSButton(
        title: "Refresh Now",
        target: nil,
        action: nil
    )
    private let openLocationSettingsButton = NSButton(
        title: "Open Location Settings",
        target: nil,
        action: nil
    )
    private var locationSearchResults: [WeatherLocation] = []
    private var locationSearchMessage: String?
    private var isSearchingForLocation = false

    init(weatherStore: WeatherStore) {
        self.weatherStore = weatherStore
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Date Day Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        configureContentView()
        refreshControls()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        refreshControls()
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
    }

    func showAbout() {
        tabView.selectTabViewItem(withIdentifier: "about")
        showWindow(nil)
    }

    func refreshForSystemChange() {
        refreshControls()
    }

    func refreshForWeatherChange() {
        refreshWeatherControls()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else {
            return
        }
        saveLabel(from: textField)
    }

    private func configureContentView() {
        guard let contentView = window?.contentView else {
            return
        }

        localePicker.addItems(withTitles: LocalePreference.options.map(\.title))
        localePicker.target = self
        localePicker.action = #selector(localeDidChange)

        showClocksCheckbox.target = self
        showClocksCheckbox.action = #selector(showClocksDidChange)

        addClockButton.bezelStyle = .rounded
        addClockButton.target = self
        addClockButton.action = #selector(addTimeZone)

        clockRows.orientation = .vertical
        clockRows.alignment = .leading
        clockRows.spacing = 8

        configureWeatherControls()

        tabView.tabViewType = .topTabsBezelBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let dateAndClocksTab = NSTabViewItem(identifier: "dateAndClocks")
        dateAndClocksTab.label = "Date & Clocks"
        dateAndClocksTab.view = makeDateAndClocksPane()
        tabView.addTabViewItem(dateAndClocksTab)

        let weatherTab = NSTabViewItem(identifier: "weather")
        weatherTab.label = "Weather"
        weatherTab.view = makeWeatherPane()
        tabView.addTabViewItem(weatherTab)

        let aboutTab = NSTabViewItem(identifier: "about")
        aboutTab.label = "About"
        aboutTab.view = makeAboutPane()
        tabView.addTabViewItem(aboutTab)

        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
        ])
    }

    private func makeDateAndClocksPane() -> NSView {
        let localeSection = makeLocaleSection()
        let divider = NSBox()
        divider.boxType = .separator
        let clocksSection = makeClocksSection()

        let stack = NSStackView(views: [localeSection, divider, clocksSection])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false

        let pane = NSView()
        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: pane.topAnchor, constant: 20),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            localeSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            clocksSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return pane
    }

    private func configureWeatherControls() {
        weatherEnabledCheckbox.target = self
        weatherEnabledCheckbox.action = #selector(weatherEnabledDidChange)

        automaticLocationRadio.target = self
        automaticLocationRadio.action = #selector(weatherLocationModeDidChange)
        automaticLocationRadio.tag = 0
        manualLocationRadio.target = self
        manualLocationRadio.action = #selector(weatherLocationModeDidChange)
        manualLocationRadio.tag = 1

        locationSearchField.placeholderString = "City or place"
        locationSearchField.target = self
        locationSearchField.action = #selector(searchForLocation)
        searchButton.target = self
        searchButton.action = #selector(searchForLocation)
        locationResultsPicker.target = self
        locationResultsPicker.action = #selector(weatherLocationResultDidChange)

        for interval in WeatherPreference.refreshIntervals {
            let minutes = Int(interval / 60)
            let item = NSMenuItem(
                title: "\(minutes) minutes",
                action: nil,
                keyEquivalent: ""
            )
            item.representedObject = interval
            refreshIntervalPicker.menu?.addItem(item)
        }
        refreshIntervalPicker.target = self
        refreshIntervalPicker.action = #selector(weatherRefreshIntervalDidChange)

        refreshWeatherButton.target = self
        refreshWeatherButton.action = #selector(refreshWeatherNow)
        openLocationSettingsButton.target = self
        openLocationSettingsButton.action = #selector(openLocationSettings)

        authorizationLabel.textColor = .secondaryLabelColor
        currentWeatherLocationLabel.textColor = .secondaryLabelColor
        weatherStatusLabel.textColor = .secondaryLabelColor
    }

    private func makeWeatherPane() -> NSView {
        let heading = NSTextField(labelWithString: "Temperature")
        heading.font = .systemFont(ofSize: 17, weight: .semibold)
        let explanation = NSTextField(
            wrappingLabelWithString: "Show Celsius and Fahrenheit together. Date Day keeps the last successful reading when the network is unavailable."
        )
        explanation.textColor = .secondaryLabelColor

        let locationHeading = NSTextField(labelWithString: "Location")
        locationHeading.font = .systemFont(ofSize: 15, weight: .semibold)
        let locationModeStack = NSStackView(
            views: [automaticLocationRadio, manualLocationRadio]
        )
        locationModeStack.orientation = .vertical
        locationModeStack.alignment = .leading
        locationModeStack.spacing = 6

        let searchRow = NSStackView(views: [locationSearchField, searchButton])
        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 8
        locationSearchField.widthAnchor.constraint(equalToConstant: 330).isActive = true
        searchButton.widthAnchor.constraint(equalToConstant: 82).isActive = true
        locationResultsPicker.widthAnchor.constraint(equalToConstant: 420).isActive = true

        let authorizationRow = NSStackView(
            views: [authorizationLabel, openLocationSettingsButton]
        )
        authorizationRow.orientation = .horizontal
        authorizationRow.alignment = .centerY
        authorizationRow.spacing = 10

        let refreshHeading = NSTextField(labelWithString: "Refresh")
        refreshHeading.font = .systemFont(ofSize: 15, weight: .semibold)
        let refreshCaption = NSTextField(labelWithString: "Refresh interval")
        let refreshRow = NSStackView(
            views: [refreshCaption, refreshIntervalPicker, refreshWeatherButton]
        )
        refreshRow.orientation = .horizontal
        refreshRow.alignment = .centerY
        refreshRow.spacing = 10
        refreshIntervalPicker.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let appNapNote = NSTextField(
            wrappingLabelWithString: "Refreshes are best effort. macOS can delay them while the Mac is asleep or idle."
        )
        appNapNote.textColor = .secondaryLabelColor

        let dividerOne = NSBox()
        dividerOne.boxType = .separator
        let dividerTwo = NSBox()
        dividerTwo.boxType = .separator
        let stack = NSStackView(
            views: [
                heading,
                explanation,
                weatherEnabledCheckbox,
                dividerOne,
                locationHeading,
                locationModeStack,
                authorizationRow,
                searchRow,
                locationResultsPicker,
                currentWeatherLocationLabel,
                dividerTwo,
                refreshHeading,
                refreshRow,
                appNapNote,
                weatherStatusLabel,
            ]
        )
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.setCustomSpacing(14, after: explanation)
        stack.setCustomSpacing(16, after: weatherEnabledCheckbox)
        stack.setCustomSpacing(14, after: dividerOne)
        stack.setCustomSpacing(14, after: dividerTwo)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let pane = NSView()
        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: pane.topAnchor, constant: 20),
            dividerOne.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dividerTwo.widthAnchor.constraint(equalTo: stack.widthAnchor),
            explanation.widthAnchor.constraint(equalTo: stack.widthAnchor),
            appNapNote.widthAnchor.constraint(equalTo: stack.widthAnchor),
            weatherStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return pane
    }

    private func makeAboutPane() -> NSView {
        let iconView = NSImageView(image: NSApp.applicationIconImage)
        iconView.imageScaling = .scaleProportionallyUpOrDown

        let appNameLabel = NSTextField(labelWithString: "Date Day")
        appNameLabel.font = .systemFont(ofSize: 24, weight: .semibold)

        let marketingVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? ""
        let buildVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? ""
        let versionText = buildVersion.isEmpty
            ? "Version \(marketingVersion)"
            : "Version \(marketingVersion) (\(buildVersion))"
        let versionLabel = NSTextField(labelWithString: versionText)
        versionLabel.textColor = .secondaryLabelColor

        let weatherCreditButton = NSButton(
            title: "Weather data by Open-Meteo",
            target: self,
            action: #selector(openWeatherAttribution)
        )
        weatherCreditButton.isBordered = false
        weatherCreditButton.contentTintColor = .linkColor
        weatherCreditButton.font = .systemFont(ofSize: 11)
        weatherCreditButton.toolTip = "Open the Open-Meteo website"

        let stack = NSStackView(
            views: [iconView, appNameLabel, versionLabel, weatherCreditButton]
        )
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(18, after: iconView)
        stack.setCustomSpacing(20, after: versionLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let pane = NSView()
        pane.addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 128),
            iconView.heightAnchor.constraint(equalToConstant: 128),
            stack.centerXAnchor.constraint(equalTo: pane.centerXAnchor),
            stack.topAnchor.constraint(equalTo: pane.topAnchor, constant: 54),
        ])
        return pane
    }

    @objc private func openWeatherAttribution() {
        guard let url = URL(string: "https://open-meteo.com/") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func makeLocaleSection() -> NSView {
        let heading = NSTextField(labelWithString: "Date format")
        heading.font = .systemFont(ofSize: 17, weight: .semibold)

        let explanation = NSTextField(
            wrappingLabelWithString: "Use the system locale, or select a locale for the menu-bar date."
        )
        explanation.textColor = .secondaryLabelColor

        let previewCaption = NSTextField(labelWithString: "Preview")
        previewCaption.font = .systemFont(ofSize: 11, weight: .medium)
        previewCaption.textColor = .secondaryLabelColor
        previewLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)

        let section = NSStackView(
            views: [heading, explanation, localePicker, previewCaption, previewLabel]
        )
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        section.setCustomSpacing(12, after: explanation)
        section.setCustomSpacing(12, after: localePicker)

        localePicker.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private func makeClocksSection() -> NSView {
        let heading = NSTextField(labelWithString: "World clocks")
        heading.font = .systemFont(ofSize: 17, weight: .semibold)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [heading, spacer, addClockButton])
        header.orientation = .horizontal
        header.alignment = .centerY

        let explanation = NSTextField(
            wrappingLabelWithString: "Configure up to three clocks. Settings keeps this order. In the menu bar, a clock moves first, uses bold text, and blinks its colon when its time zone matches the Mac’s current time zone."
        )
        explanation.textColor = .secondaryLabelColor

        let section = NSStackView(
            views: [header, explanation, showClocksCheckbox, clockRows]
        )
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 10
        section.setCustomSpacing(14, after: explanation)
        header.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        clockRows.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private func refreshControls() {
        let selectedIdentifier = LocalePreference.selectedIdentifier
        let selectedIndex = LocalePreference.options.firstIndex {
            $0.identifier == selectedIdentifier
        } ?? 0
        localePicker.selectItem(at: selectedIndex)

        let state = WorldClockPreference.state
        showClocksCheckbox.state = state.showsClocks ? .on : .off
        clockRows.isHidden = !state.showsClocks
        addClockButton.isEnabled = state.showsClocks && state.clocks.count < 3

        rebuildClockRows(with: state)
        refreshPreview()
        refreshWeatherControls()
    }

    private func rebuildClockRows(with state: WorldClockPreference.State) {
        for view in clockRows.arrangedSubviews {
            clockRows.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let displayIndexes = Dictionary(uniqueKeysWithValues:
            WorldClockDisplayResolver.visibleClocks(from: state)
                .enumerated()
                .map { ($0.element.id, $0.offset) }
        )
        for (storedIndex, clock) in state.clocks.enumerated() {
            clockRows.addArrangedSubview(
                makeClockRow(
                    clock,
                    index: storedIndex,
                    displayIndex: displayIndexes[clock.id]
                )
            )
        }
    }

    private func makeClockRow(
        _ clock: WorldClockConfiguration,
        index: Int,
        displayIndex: Int?
    ) -> NSView {
        let labelField = NSTextField(string: clock.label)
        labelField.placeholderString = index == 0 ? "Local" : "Label"
        labelField.tag = index
        labelField.delegate = self
        labelField.target = self
        labelField.action = #selector(labelDidChange)

        let timeZonePicker = NSPopUpButton()
        timeZonePicker.tag = index

        for identifier in WorldClockPreference.timeZoneIdentifiers {
            let item = NSMenuItem(
                title: identifier,
                action: nil,
                keyEquivalent: ""
            )
            item.representedObject = identifier
            timeZonePicker.menu?.addItem(item)
        }
        timeZonePicker.selectItem(withTitle: clock.timeZoneIdentifier ?? "UTC")
        timeZonePicker.target = self
        timeZonePicker.action = #selector(timeZoneDidChange)

        let isCurrentTimeZone = clock.timeZoneIdentifier
            == TimeZone.autoupdatingCurrent.identifier
        let weightTitle = if isCurrentTimeZone {
            "Bold"
        } else if displayIndex == 2 {
            "Thin"
        } else {
            "Regular"
        }
        let weightLabel = NSTextField(
            labelWithString: weightTitle
        )
        weightLabel.alignment = .center
        weightLabel.textColor = .secondaryLabelColor

        let removeImage = NSImage(
            systemSymbolName: "minus.circle",
            accessibilityDescription: "Remove time zone"
        ) ?? NSImage()
        let removeButton = NSButton(
            image: removeImage,
            target: self,
            action: #selector(removeTimeZone)
        )
        removeButton.tag = index
        removeButton.isBordered = false

        let row = NSStackView(
            views: [labelField, timeZonePicker, weightLabel, removeButton]
        )
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10

        NSLayoutConstraint.activate([
            labelField.widthAnchor.constraint(equalToConstant: 90),
            timeZonePicker.widthAnchor.constraint(equalToConstant: 320),
            weightLabel.widthAnchor.constraint(equalToConstant: 46),
            removeButton.widthAnchor.constraint(equalToConstant: 24),
        ])

        return row
    }

    private func refreshPreview() {
        previewLabel.stringValue = DateDayFormatter.string(
            for: .now,
            locale: LocalePreference.currentLocale,
            timeZone: .autoupdatingCurrent
        )
    }

    private func saveLabel(from textField: NSTextField) {
        let index = textField.tag
        let trimmedLabel = textField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fallback = "Clock"
        textField.stringValue = trimmedLabel.isEmpty ? fallback : trimmedLabel

        WorldClockPreference.update { state in
            guard state.clocks.indices.contains(index) else {
                return
            }
            state.clocks[index].label = textField.stringValue
            if let identifier = state.clocks[index].timeZoneIdentifier {
                state.labelsByTimeZoneIdentifier[identifier] = textField.stringValue
            }
        }
    }

    @objc private func localeDidChange() {
        let selectedIndex = localePicker.indexOfSelectedItem
        guard LocalePreference.options.indices.contains(selectedIndex) else {
            return
        }

        LocalePreference.select(LocalePreference.options[selectedIndex].identifier)
        refreshPreview()
    }

    @objc private func showClocksDidChange() {
        WorldClockPreference.update { state in
            state.showsClocks = showClocksCheckbox.state == .on
        }
        refreshControls()
    }

    @objc private func addTimeZone() {
        WorldClockPreference.update { state in
            guard state.clocks.count < 3 else {
                return
            }
            state.clocks.append(WorldClockPreference.makeClock())
        }
        refreshControls()
    }

    @objc private func labelDidChange(_ sender: NSTextField) {
        saveLabel(from: sender)
    }

    @objc private func timeZoneDidChange(_ sender: NSPopUpButton) {
        let index = sender.tag
        guard let identifier = sender.selectedItem?.representedObject as? String else {
            return
        }

        WorldClockPreference.update { state in
            guard state.clocks.indices.contains(index) else {
                return
            }
            state.clocks[index].timeZoneIdentifier = identifier
            state.clocks[index].label = state.labelsByTimeZoneIdentifier[identifier]
                ?? WorldClockDisplayResolver.suggestedLabel(for: identifier)
        }
        refreshControls()
    }

    @objc private func removeTimeZone(_ sender: NSButton) {
        let index = sender.tag
        WorldClockPreference.update { state in
            guard state.clocks.indices.contains(index) else {
                return
            }
            state.clocks.remove(at: index)
        }
        refreshControls()
    }

    private func refreshWeatherControls() {
        let state = WeatherPreference.state
        weatherEnabledCheckbox.state = state.isEnabled ? .on : .off
        automaticLocationRadio.state = state.locationMode == .automatic ? .on : .off
        manualLocationRadio.state = state.locationMode == .manual ? .on : .off

        let controlsEnabled = state.isEnabled
        automaticLocationRadio.isEnabled = controlsEnabled
        manualLocationRadio.isEnabled = controlsEnabled
        let manualControlsEnabled = controlsEnabled && state.locationMode == .manual
        locationSearchField.isEnabled = manualControlsEnabled
        searchButton.isEnabled = manualControlsEnabled && !isSearchingForLocation
        locationResultsPicker.isEnabled = manualControlsEnabled
        refreshIntervalPicker.isEnabled = controlsEnabled
        refreshWeatherButton.isEnabled = controlsEnabled && !weatherStore.isRefreshing

        authorizationLabel.stringValue = "Authorization: \(weatherStore.authorizationDescription)"
        openLocationSettingsButton.isHidden = ![
            "Denied",
            "Restricted",
        ].contains(weatherStore.authorizationDescription)

        if locationSearchResults.isEmpty, let manualLocation = state.manualLocation {
            locationSearchResults = [manualLocation]
            locationResultsPicker.removeAllItems()
            locationResultsPicker.addItem(withTitle: manualLocation.name)
        }

        if let manualLocation = state.manualLocation {
            currentWeatherLocationLabel.stringValue = "Manual location: \(manualLocation.name)"
        } else if let snapshot = weatherStore.snapshot {
            currentWeatherLocationLabel.stringValue = "Current: \(snapshot.locationName)"
        } else {
            currentWeatherLocationLabel.stringValue = "No location selected"
        }

        if let item = refreshIntervalPicker.itemArray.first(where: {
            ($0.representedObject as? TimeInterval) == state.refreshInterval
        }) {
            refreshIntervalPicker.select(item)
        }

        weatherStatusLabel.stringValue = locationSearchMessage
            ?? weatherStore.statusDescription
    }

    @objc private func weatherEnabledDidChange() {
        WeatherPreference.update { state in
            state.isEnabled = weatherEnabledCheckbox.state == .on
        }
    }

    @objc private func weatherLocationModeDidChange(_ sender: NSButton) {
        WeatherPreference.update { state in
            state.locationMode = sender.tag == 0 ? .automatic : .manual
        }
    }

    @objc private func weatherRefreshIntervalDidChange() {
        guard
            let interval = refreshIntervalPicker.selectedItem?.representedObject
                as? TimeInterval
        else {
            return
        }
        WeatherPreference.update { state in
            state.refreshInterval = interval
        }
    }

    @objc private func refreshWeatherNow() {
        weatherStore.refreshNow()
        refreshWeatherControls()
    }

    @objc private func searchForLocation() {
        let query = locationSearchField.stringValue
        isSearchingForLocation = true
        locationSearchMessage = "Searching…"
        refreshWeatherControls()

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let results = try await weatherStore.searchLocations(named: query)
                locationSearchResults = results
                locationResultsPicker.removeAllItems()
                locationResultsPicker.addItems(withTitles: results.map(\.name))
                locationSearchMessage = "Select a matching location."
            } catch {
                locationSearchResults = []
                locationResultsPicker.removeAllItems()
                locationSearchMessage = error.localizedDescription
            }
            isSearchingForLocation = false
            refreshWeatherControls()
        }
    }

    @objc private func weatherLocationResultDidChange() {
        let index = locationResultsPicker.indexOfSelectedItem
        guard locationSearchResults.indices.contains(index) else {
            return
        }
        let location = locationSearchResults[index]
        locationSearchMessage = nil
        WeatherPreference.update { state in
            state.locationMode = .manual
            state.manualLocation = location
        }
    }

    @objc private func openLocationSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
