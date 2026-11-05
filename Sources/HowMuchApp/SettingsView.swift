import AppKit
import HowMuchCore
import SwiftUI

/// Signal Ledger settings: preferences, a compact pay ledger, derived rates and
/// one destructive data block. Everything scrolls under a fixed header.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let close: () -> Void

    @State private var showFullResetAlert = false
    @State private var backHovering = false
    @State private var doneHovering = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        sectionLabel(model.t(.preferences), top: 4)
                        preferences

#if !HOWMUCH_OFFLINE
                        sectionLabel(
                            model.t(.updatesSection),
                            caption: "v\(model.updater.currentVersion)"
                        )
                        UpdateSettingsCard(updater: model.updater)
#endif

                        sectionLabel(model.t(.paySection), caption: model.t(.paySavedHint))
                        payCard

                        sectionLabel(model.t(.ratesSection))
                        rateCard

                        sectionLabel(model.t(.dataSection))
                        resetCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }

                LinearGradient(
                    colors: [Palette.canvas.opacity(0), Palette.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 16)
                .allowsHitTesting(false)
            }
        }
        .frame(width: 392, height: 320)
        .alert(model.t(.fullResetConfirmTitle), isPresented: $showFullResetAlert) {
            Button(model.t(.cancel), role: .cancel) {}
            Button(model.t(.fullResetConfirmAction), role: .destructive) {
                model.resetEverything()
            }
        } message: {
            Text(
                model.t(
                    .fullResetConfirmMessage,
                    model.money(model.totalEarned),
                    model.money(model.snapshot.total)
                )
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(backHovering ? Palette.surfaceMuted : Color.clear)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { backHovering = $0 }
            .help(model.t(.back))
            .accessibilityLabel(model.t(.back))

            Text(model.t(.settingsTitle))
                .font(AppFont.geist(15, .semibold))
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 8)

            Button(action: close) {
                Text(model.t(.done))
                    .font(AppFont.geist(11.5, .semibold))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(doneHovering ? Palette.primarySoft : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { doneHovering = $0 }
            .help(model.t(.done))
        }
        .padding(.horizontal, 16)
        .padding(.leading, -6)
        .frame(height: 52)
    }

    // MARK: - Preferences

    private var preferences: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                preferenceField(title: model.t(.language), help: model.t(.languageHint)) {
                    PreferenceMenu(
                        value: model.language.nativeName,
                        options: AppLanguage.allCases.map { language in
                            PreferenceOption(
                                id: language.rawValue,
                                label: language.nativeName,
                                isSelected: language == model.language
                            ) {
                                model.language = language
                            }
                        }
                    )
                }

                preferenceField(
                    title: model.t(.currency),
                    help: model.t(.currencyDisplayOnlyNote)
                ) {
                    PreferenceMenu(
                        value: compactCurrency(model.currency),
                        options: CurrencyUnit.allCases.map { currency in
                            PreferenceOption(
                                id: currency.rawValue,
                                label: currency.menuLabel(in: model.language),
                                isSelected: currency == model.currency
                            ) {
                                model.currency = currency
                            }
                        }
                    )
                }
            }

            bigMacToggleRow
        }
    }

    private var bigMacToggleRow: some View {
        HStack(spacing: 8) {
            Text("🍔")
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Palette.surfaceMuted)
                )
                .accessibilityHidden(true)

            Text(model.t(.bigMacCounterTitle))
                .font(AppFont.geist(11.5, .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            Toggle("", isOn: $model.bigMacCounterEnabled)
                .toggleStyle(CompactSwitchStyle())
                .labelsHidden()
                .help(model.t(.bigMacCounterHint))
                .accessibilityLabel(model.t(.bigMacCounterTitle))
                .accessibilityHint(model.t(.bigMacCounterHint))
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 0.8)
        )
        .help(model.t(.bigMacCounterHint))
    }

    private func preferenceField<Content: View>(
        title: String,
        help: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(AppFont.geist(9, .medium))
                .foregroundStyle(Palette.muted)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(help)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactCurrency(_ currency: CurrencyUnit) -> String {
        "\(currency.code) \(currency.symbol)"
    }

    // MARK: - Pay

    private var payCard: some View {
        VStack(spacing: 0) {
            SettingNumberRow(
                icon: "banknote",
                title: model.t(.monthlySalary),
                tint: Palette.secondary,
                value: salaryBinding,
                suffix: "\(model.currency.code)/\(model.t(.perMonthSuffix))",
                isInvalid: model.settings.monthlySalary <= 0
            )

            rowDivider

            SettingNumberRow(
                icon: "calendar",
                title: model.t(.workdaysPerMonth),
                tint: Palette.secondary,
                value: settingBinding(\.workDaysPerMonth),
                suffix: model.t(.daysSuffix),
                isInvalid: model.settings.workDaysPerMonth <= 0
            )

            rowDivider

            SettingNumberRow(
                icon: "clock",
                title: model.t(.hoursPerDay),
                tint: Palette.secondary,
                value: settingBinding(\.hoursPerDay),
                suffix: model.t(.hoursSuffix),
                isInvalid: model.settings.hoursPerDay <= 0
            )

            rowDivider

            SettingNumberRow(
                icon: "bolt",
                title: model.t(.overtimeHourly),
                tint: Palette.ember,
                value: settingBinding(\.overtimeHourlyRate),
                suffix: "\(model.currency.code)/\(model.t(.perHourSuffix))",
                isInvalid: false
            )
            .contextMenu {
                Button {
                    model.useSuggestedOvertimeRate()
                } label: {
                    Text(
                        model.t(
                            .fillSuggestedRate,
                            model.money(model.settings.suggestedOvertimeHourlyRate)
                        )
                    )
                }
                .disabled(!model.settings.isValid)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 0.8)
        )
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 0.8)
    }

    // MARK: - Rates

    private var rateCard: some View {
        HStack(spacing: 0) {
            SettingsRateCell(
                label: model.t(.perHour),
                value: model.money(model.settings.normalHourlyRate)
            )

            rateDivider

            SettingsRateCell(
                label: model.t(.perMinute),
                value: model.currency.symbol + Fmt.rate(model.settings.normalPerMinuteRate, decimals: 3)
            )

            rateDivider

            SettingsRateCell(
                label: model.t(.perSecond),
                value: model.currency.symbol + Fmt.rate(model.settings.normalPerSecondRate, decimals: 4)
            )
        }
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 0.8)
        )
    }

    private var rateDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(width: 0.8)
            .padding(.vertical, 8)
    }

    // MARK: - Data

    private var resetCard: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.danger.opacity(0.12))
                    .frame(width: 26, height: 26)

                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.danger)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(model.t(.fullResetTitle))
                    .font(AppFont.geist(11.5, .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Text(model.t(.fullResetCaption, model.money(model.totalEarned)))
                    .font(AppFont.geist(9, .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 4)

            Button {
                showFullResetAlert = true
            } label: {
                Text(model.t(.fullResetAction))
                    .font(AppFont.geist(10.5, .semibold))
                    .foregroundStyle(Palette.danger)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Palette.danger.opacity(0.30), lineWidth: 0.8)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!model.hasAnyEarnings)
            .opacity(model.hasAnyEarnings ? 1 : 0.45)
            .help(model.t(.fullResetTitle))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.dangerSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.danger.opacity(0.20), lineWidth: 0.8)
        )
    }

    // MARK: - Shared

    private func sectionLabel(
        _ title: String,
        caption: String? = nil,
        top: CGFloat = 4
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(AppFont.geist(11.5, .semibold))
                .foregroundStyle(Palette.ink)

            Spacer(minLength: 0)

            if let caption {
                Text(caption)
                    .font(AppFont.geist(8.5, .medium))
                    .foregroundStyle(Palette.faint)
                    .lineLimit(1)
            }
        }
        .frame(height: 14)
        .padding(.top, top)
        .padding(.bottom, 4)
    }

    private func settingBinding(_ keyPath: WritableKeyPath<PaySettings, Double>) -> Binding<Double> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                guard newValue.isFinite else { return }
                model.settings[keyPath: keyPath] = max(0, newValue)
            }
        )
    }

    /// Changing the base salary seeds overtime at 1.5×, but the overtime row
    /// remains a normal editable field so the user can overwrite that value.
    private var salaryBinding: Binding<Double> {
        Binding(
            get: { model.settings.monthlySalary },
            set: { newValue in
                guard newValue.isFinite else { return }
                model.updateMonthlySalary(newValue)
            }
        )
    }
}

// MARK: - Components

#if !HOWMUCH_OFFLINE
struct UpdateSettingsCard: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var updater: UpdateController

    var body: some View {
        VStack(spacing: 0) {
            toggleRow(
                icon: "arrow.triangle.2.circlepath",
                tint: Palette.primary,
                title: model.t(.autoCheckUpdates),
                help: model.t(.autoCheckUpdatesHint),
                isOn: $model.checkForUpdatesEnabled
            )

            divider

            toggleRow(
                icon: "arrow.down.circle",
                tint: Palette.secondary,
                title: model.t(.autoInstallUpdates),
                help: model.t(.autoInstallUpdatesHint),
                isOn: $model.autoUpdateEnabled
            )

            divider
            footer
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Palette.line, lineWidth: 0.8)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 0.8)
    }

    private func toggleRow(
        icon: String,
        tint: Color,
        title: String,
        help: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Palette.surfaceMuted)
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(AppFont.geist(11.5, .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            Toggle("", isOn: isOn)
                .toggleStyle(CompactSwitchStyle())
                .labelsHidden()
                .help(help)
                .accessibilityLabel(title)
                .accessibilityHint(help)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .help(help)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.62)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 5, height: 5)
            }

            Text(statusText)
                .font(AppFont.geist(9.5, .medium))
                .foregroundStyle(
                    isFailure ? Palette.danger : Palette.muted
                )
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: performAction) {
                Text(actionTitle)
                    .font(AppFont.geist(10.5, .semibold))
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Palette.primary.opacity(0.32), lineWidth: 0.8)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(isBusy)
            .opacity(isBusy ? 0.45 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 34)
    }

    private var isBusy: Bool {
        switch updater.status {
        case .checking, .downloading, .preparing, .installing:
            return true
        default:
            return false
        }
    }

    private var isFailure: Bool {
        if case .failed = updater.status { return true }
        return false
    }

    private var statusColor: Color {
        switch updater.status {
        case .available:
            return Palette.primary
        case .downloading, .preparing, .installing:
            return Palette.secondary
        case .failed:
            return Palette.danger
        default:
            return Palette.faint
        }
    }

    private var statusText: String {
        switch updater.status {
        case .disabled:
            return model.t(.updateStatusDisabled)
        case .idle:
            return model.t(.updateStatusIdle)
        case .checking:
            return model.t(.updateStatusChecking)
        case .upToDate:
            return model.t(.updateStatusUpToDate)
        case .available(let version):
            return model.t(.updateStatusAvailable, version)
        case .downloading(let version):
            return model.t(.updateStatusDownloading, version)
        case .preparing:
            return model.t(.updateStatusPreparing)
        case .installing:
            return model.t(.updateStatusInstalling)
        case .failed(let failure):
            return failureText(failure)
        }
    }

    private func failureText(_ failure: UpdateController.Failure) -> String {
        switch failure {
        case .network:
            return model.t(.updateFailureNetwork)
        case .missingAsset:
            return model.t(.updateFailureMissingAsset)
        case .checksum:
            return model.t(.updateFailureChecksum)
        case .unsafeInstallLocation:
            return model.t(.updateFailureUnsafe)
        case .invalidPackage:
            return model.t(.updateFailurePackage)
        case .install:
            return model.t(.updateFailureInstall)
        }
    }

    private var actionTitle: String {
        switch updater.status {
        case .available:
            return model.t(.installUpdate)
        case .failed:
            return model.t(.updateRetry)
        default:
            return model.t(.checkForUpdates)
        }
    }

    private func performAction() {
        switch updater.status {
        case .available:
            model.installAvailableUpdate()
        default:
            model.checkForUpdatesManually()
        }
    }
}

#endif

struct PreferenceOption: Identifiable {
    let id: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
}

struct PreferenceMenu: View {
    let value: String
    let options: [PreferenceOption]

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 4) {
                Text(value)
                    .font(AppFont.geist(11.5, .medium))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.faint)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .frame(height: 31)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Palette.line, lineWidth: 0.8)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            PreferenceMenuAnchor(options: options, accessibilityLabel: value)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 31)
        .help(value)
    }
}

/// A transparent AppKit hit area that opens a native NSMenu. Native menus are
/// modal and do not dismiss the status-bar NSPopover, unlike a nested SwiftUI
/// popover; the surrounding control keeps the Signal Ledger look.
private struct PreferenceMenuAnchor: NSViewRepresentable {
    let options: [PreferenceOption]
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator {
        Coordinator(options: options)
    }

    func makeNSView(context: Context) -> MenuAnchorView {
        let view = MenuAnchorView()
        view.coordinator = context.coordinator
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel(accessibilityLabel)
        return view
    }

    func updateNSView(_ nsView: MenuAnchorView, context: Context) {
        context.coordinator.options = options
        nsView.setAccessibilityLabel(accessibilityLabel)
    }

    final class Coordinator: NSObject {
        var options: [PreferenceOption]

        init(options: [PreferenceOption]) {
            self.options = options
        }

        @objc func select(_ sender: NSMenuItem) {
            guard let index = sender.representedObject as? Int,
                  options.indices.contains(index) else { return }
            options[index].action()
        }
    }

    final class MenuAnchorView: NSView {
        weak var coordinator: Coordinator?

        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            openMenu()
        }

        override func rightMouseDown(with event: NSEvent) {
            openMenu()
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 36, 49, 76: // Return, Space, Enter
                openMenu()
            default:
                super.keyDown(with: event)
            }
        }

        override func accessibilityPerformPress() -> Bool {
            openMenu()
            return true
        }

        private func openMenu() {
            guard let coordinator else { return }

            let menu = NSMenu()
            menu.autoenablesItems = false

            for (index, option) in coordinator.options.enumerated() {
                let item = NSMenuItem(
                    title: option.label,
                    action: #selector(Coordinator.select(_:)),
                    keyEquivalent: ""
                )
                item.target = coordinator
                item.representedObject = index
                item.state = option.isSelected ? .on : .off
                menu.addItem(item)
            }

            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: bounds.height + 4),
                in: self
            )
        }
    }
}

struct CompactSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        configuration.isOn
                            ? Palette.primary
                            : Palette.lineStrong.opacity(0.55)
                    )

                Circle()
                    .fill(
                        configuration.isOn
                            ? Palette.onPrimary
                            : Palette.surface
                    )
                    .frame(width: 13, height: 13)
                    .padding(2)
                    .offset(x: configuration.isOn ? 13 : 0)
                    .shadow(
                        color: Palette.ink.opacity(0.12),
                        radius: 1,
                        y: 0.5
                    )
            }
            .frame(width: 30, height: 17)
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.16), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}

struct SettingNumberRow: View {
    let icon: String
    let title: String
    let tint: Color
    @Binding var value: Double
    let suffix: String
    var isInvalid: Bool = false
    // Shared across all four rows so the input boxes and unit labels line up.
    private let suffixWidth: CGFloat = 46

    @FocusState private var focused: Bool
    @State private var draft = ""

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private var accent: Color {
        isInvalid ? Palette.danger : tint
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(accent.opacity(0.10))
                    .frame(width: 24, height: 24)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accent)
            }

            Text(title)
                .font(AppFont.geist(11.5, .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            TextField("0", text: $draft)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(AppFont.numbers(11.5, .semibold))
                .foregroundStyle(Palette.ink)
                .focused($focused)
                .frame(width: 68, height: 25)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Palette.field)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            focused ? accent : (isInvalid ? Palette.danger.opacity(0.55) : Color.clear),
                            lineWidth: focused ? 1 : 0.8
                        )
                )
                .onAppear {
                    draft = formatted(value)
                }
                .onChange(of: focused) { isFocused in
                    if isFocused {
                        DispatchQueue.main.async {
                            NSApp.sendAction(
                                #selector(NSText.selectAll(_:)),
                                to: nil,
                                from: nil
                            )
                        }
                    } else {
                        commitDraft()
                    }
                }
                .onChange(of: value) { newValue in
                    if !focused {
                        draft = formatted(newValue)
                    }
                }
                .onChange(of: draft) { newDraft in
                    guard focused,
                          let parsed = parseDraft(newDraft),
                          abs(parsed - value) > 0.0001 else { return }
                    value = parsed
                }
                .onSubmit {
                    commitDraft()
                    focused = false
                }

            Text(suffix)
                .font(AppFont.geist(8.5, .medium))
                .foregroundStyle(Palette.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: suffixWidth, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .contentShape(Rectangle())
        .onTapGesture {
            focused = true
        }
    }

    private func formatted(_ value: Double) -> String {
        let safe = value.isFinite ? max(0, value) : 0
        return Self.numberFormatter.string(from: NSNumber(value: safe)) ?? "0"
    }

    private func parseDraft(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, let parsed = Double(cleaned), parsed.isFinite else {
            return nil
        }
        return max(0, parsed)
    }

    private func commitDraft() {
        if let parsed = parseDraft(draft) {
            value = parsed
            draft = formatted(parsed)
        } else {
            draft = formatted(value)
        }
    }
}

struct SettingsRateCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.geist(9, .medium))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)

            Text(value)
                .font(AppFont.numbers(13.5, .semibold))
                .tracking(-0.25)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }
}
