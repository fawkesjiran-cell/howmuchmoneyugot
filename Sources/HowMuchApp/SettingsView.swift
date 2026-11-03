import HowMuchCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let close: () -> Void

    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    preferencesCard
                    incomeCard
                    rateCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 2)
                .padding(.bottom, 16)
            }
        }
        .alert(model.t(.resetConfirmTitle), isPresented: $showResetAlert) {
            Button(model.t(.cancel), role: .cancel) {}
            Button(model.t(.reset), role: .destructive) {
                model.resetSession()
            }
        } message: {
            Text(model.t(.resetConfirmMessage, model.money(model.snapshot.total)))
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Palette.surface)
                            .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.8))
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .help(model.t(.back))

            Text(model.t(.settingsTitle))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.ink)

            Spacer()

            Button(model.t(.done), action: close)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.normal)
                .buttonStyle(.plain)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Palette.normalSoft)
                )
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        HStack(spacing: 0) {
            preferenceColumn(
                icon: "globe",
                title: model.t(.language),
                help: model.t(.languageHint)
            ) {
                Picker("", selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }

            Rectangle()
                .fill(Palette.line)
                .frame(width: 0.8, height: 40)

            preferenceColumn(
                icon: "banknote.fill",
                title: model.t(.currency),
                help: model.t(.currencyDisplayOnlyNote)
            ) {
                Picker("", selection: $model.currency) {
                    ForEach(CurrencyUnit.allCases) { currency in
                        Text(currency.menuLabel(in: model.language)).tag(currency)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .cardSurface(cornerRadius: 16)
    }

    private func preferenceColumn<Content: View>(
        icon: String,
        title: String,
        help: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.normal)
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.secondary)
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(help)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    // MARK: - Income

    private var incomeCard: some View {
        VStack(spacing: 0) {
            SettingNumberRow(
                icon: "banknote.fill",
                title: model.t(.monthlySalary),
                tint: Palette.normal,
                value: settingBinding(\.monthlySalary),
                suffix: "\(model.currency.code)/\(model.t(.perMonthSuffix))",
                isInvalid: model.settings.monthlySalary <= 0
            )

            rowDivider

            SettingNumberRow(
                icon: "calendar",
                title: model.t(.workdaysPerMonth),
                tint: Palette.normal,
                value: settingBinding(\.workDaysPerMonth),
                suffix: model.t(.daysSuffix),
                isInvalid: model.settings.workDaysPerMonth <= 0
            )

            rowDivider

            SettingNumberRow(
                icon: "clock.fill",
                title: model.t(.hoursPerDay),
                tint: Palette.normal,
                value: settingBinding(\.hoursPerDay),
                suffix: model.t(.hoursSuffix),
                isInvalid: model.settings.hoursPerDay <= 0
            )

            rowDivider

            SettingNumberRow(
                icon: "bolt.fill",
                title: model.t(.overtimeHourly),
                tint: Palette.gold,
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
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .cardSurface(cornerRadius: 16)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 0.8)
            .padding(.leading, 38)
    }

    // MARK: - Rates

    private var rateCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                RateMetric(
                    label: model.t(.perSecond),
                    symbol: model.currency.symbol,
                    value: model.amount(model.settings.normalPerSecondRate, precise: true),
                    tint: Palette.ink
                )
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 0.8, height: 25)
                    .padding(.horizontal, 9)
                RateMetric(
                    label: model.t(.perMinute),
                    symbol: model.currency.symbol,
                    value: model.amount(model.settings.normalPerMinuteRate),
                    tint: Palette.ink
                )
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 0.8, height: 25)
                    .padding(.horizontal, 9)
                RateMetric(
                    label: model.t(.perHour),
                    symbol: model.currency.symbol,
                    value: model.amount(model.settings.normalHourlyRate),
                    tint: Palette.ink
                )
            }

            Rectangle()
                .fill(Palette.line)
                .frame(height: 0.8)

            HStack(spacing: 8) {
                SummaryStat(
                    label: model.t(.overtimeHourly),
                    value: model.money(model.settings.safeOvertimeHourlyRate)
                )
                Spacer(minLength: 0)
                SummaryStat(
                    label: model.t(.dailyTarget),
                    value: model.money(model.settings.dailyPay)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .cardSurface(cornerRadius: 16)
    }

    // MARK: - Helpers

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

struct SettingNumberRow: View {
    let icon: String
    let title: String
    let tint: Color
    @Binding var value: Double
    let suffix: String
    var isInvalid: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill((isInvalid ? Palette.danger : tint).opacity(0.10))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isInvalid ? Palette.danger : tint)
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                TextField(
                    "0",
                    value: $value,
                    format: .number.precision(.fractionLength(0...2))
                )
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .focused($focused)
                .frame(width: 70)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(focused ? Palette.surfaceStrong : Palette.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            focused
                                ? (isInvalid ? Palette.danger : tint).opacity(0.65)
                                : (isInvalid ? Palette.danger.opacity(0.55) : Palette.line),
                            lineWidth: 0.8
                        )
                )

                Text(suffix)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 54, alignment: .leading)
            }
        }
        .frame(height: 43)
        .contentShape(Rectangle())
        .onTapGesture {
            focused = true
        }
    }
}


struct SummaryStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.tertiary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
