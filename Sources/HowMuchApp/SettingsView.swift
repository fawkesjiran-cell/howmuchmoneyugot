import AppKit
import HowMuchCore
import SwiftUI

/// Pine Ledger settings: preferences, a compact pay ledger, derived rates and
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
                    .foregroundStyle(Palette.primary)
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
                tint: Palette.primary,
                value: settingBinding(\.monthlySalary),
                suffix: "\(model.currency.code)/\(model.t(.perMonthSuffix))",
                isInvalid: model.settings.monthlySalary <= 0,
                suffixWidth: 46
            )

            rowDivider

            SettingNumberRow(
                icon: "calendar",
                title: model.t(.workdaysPerMonth),
                tint: Palette.primary,
                value: settingBinding(\.workDaysPerMonth),
                suffix: model.t(.daysSuffix),
                isInvalid: model.settings.workDaysPerMonth <= 0,
                suffixWidth: 38
            )

            rowDivider

            SettingNumberRow(
                icon: "clock",
                title: model.t(.hoursPerDay),
                tint: Palette.primary,
                value: settingBinding(\.hoursPerDay),
                suffix: model.t(.hoursSuffix),
                isInvalid: model.settings.hoursPerDay <= 0,
                suffixWidth: 38
            )

            rowDivider

            SettingNumberRow(
                icon: "bolt",
                title: model.t(.overtimeHourly),
                tint: Palette.ember,
                value: settingBinding(\.overtimeHourlyRate),
                suffix: "\(model.currency.code)/\(model.t(.perHourSuffix))",
                isInvalid: false,
                suffixWidth: 46
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
}

// MARK: - Components

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
/// popover; the surrounding control keeps the Pine Ledger look.
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

struct SettingNumberRow: View {
    let icon: String
    let title: String
    let tint: Color
    @Binding var value: Double
    let suffix: String
    var isInvalid: Bool = false
    var suffixWidth: CGFloat = 42

    @FocusState private var focused: Bool

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

            TextField(
                "0",
                value: $value,
                format: .number.precision(.fractionLength(0...2))
            )
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(AppFont.numbers(11.5, .semibold))
            .foregroundStyle(Palette.ink)
            .focused($focused)
            .frame(width: 68, height: 25)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(focused ? Palette.surface : Palette.sunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        focused ? accent : (isInvalid ? Palette.danger.opacity(0.55) : Color.clear),
                        lineWidth: focused ? 1 : 0.8
                    )
            )

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
