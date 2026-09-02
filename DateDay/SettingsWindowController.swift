import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSTextFieldDelegate {
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

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 430),
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

        let localeSection = makeLocaleSection()
        let divider = NSBox()
        divider.boxType = .separator
        let clocksSection = makeClocksSection()

        let mainStack = NSStackView(
            views: [localeSection, divider, clocksSection]
        )
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 22
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            divider.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            localeSection.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
            clocksSection.widthAnchor.constraint(equalTo: mainStack.widthAnchor),
        ])
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
            wrappingLabelWithString: "The first clock uses the system time zone and bold text. Additional clocks use regular text."
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
    }

    private func rebuildClockRows(with state: WorldClockPreference.State) {
        for view in clockRows.arrangedSubviews {
            clockRows.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, clock) in state.clocks.enumerated() {
            clockRows.addArrangedSubview(makeClockRow(clock, index: index))
        }
    }

    private func makeClockRow(
        _ clock: WorldClockConfiguration,
        index: Int
    ) -> NSView {
        let labelField = NSTextField(string: clock.label)
        labelField.placeholderString = index == 0 ? "Local" : "Label"
        labelField.tag = index
        labelField.delegate = self
        labelField.target = self
        labelField.action = #selector(labelDidChange)

        let timeZonePicker = NSPopUpButton()
        timeZonePicker.tag = index

        if clock.isSystemTimeZone {
            timeZonePicker.addItem(withTitle: "System Time Zone")
            timeZonePicker.isEnabled = false
        } else {
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
        }

        let weightLabel = NSTextField(
            labelWithString: clock.isSystemTimeZone ? "Bold" : "Regular"
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
        removeButton.isHidden = clock.isSystemTimeZone

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
        let fallback = index == 0 ? "Local" : "Clock"
        textField.stringValue = trimmedLabel.isEmpty ? fallback : trimmedLabel

        WorldClockPreference.update { state in
            guard state.clocks.indices.contains(index) else {
                return
            }
            state.clocks[index].label = textField.stringValue
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
            state.clocks.append(WorldClockPreference.makeSecondaryClock())
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
            guard state.clocks.indices.contains(index), index > 0 else {
                return
            }
            state.clocks[index].timeZoneIdentifier = identifier
        }
    }

    @objc private func removeTimeZone(_ sender: NSButton) {
        let index = sender.tag
        WorldClockPreference.update { state in
            guard state.clocks.indices.contains(index), index > 0 else {
                return
            }
            state.clocks.remove(at: index)
        }
        refreshControls()
    }
}
