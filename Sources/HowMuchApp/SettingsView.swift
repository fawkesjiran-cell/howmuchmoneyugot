import HowMuchCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let close: () -> Void

    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    preferencesSection
                    incomeSection
                    rateSection
                    dataSection
                    privacyNote
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
                .padding(.bottom, 18)
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
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Palette.surface)
                            .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.8))
                    )
            }
            .buttonStyle(PressScaleButtonStyle())
            .help(model.t(.back))

            VStack(alignment: .leading, spacing: 2) {
                Text(model.t(.settingsTitle))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text(model.t(.settingsSubtitle))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer()

            Button(model.t(.done), action: close)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.normal)
                .buttonStyle(.plain)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Palette.normalSoft)
                )
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SmallCapsLabel(text: model.t(.preferences))

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
                    .frame(width: 0.8, height: 44)

                preferenceColumn(
                    icon: "banknote",
                    title: model.t(.currency),
                    help: model.t(.currencyHint)
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
            .padding(.vertical, 10)
            .cardSurface(cornerRadius: 17)

            Text(model.t(.currencyDisplayOnlyNote))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
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

    private var incomeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SmallCapsLabel(text: model.t(.incomeInputSection))

            VStack(spacing: 0) {
                SettingNumberRow(
                    icon: "banknote.fill",
                    title: model.t(.monthlySalary),
                    caption: model.t(.monthlySalaryHint),
                    tint: Palette.normal,
                    value: settingBinding(\.monthlySalary),
                    suffix: "\(model.currency.code)/\(model.t(.perMonthSuffix))"
                )

                rowDivider

                SettingNumberRow(
                    icon: "calendar",
                    title: model.t(.workdaysPerMonth),
                    caption: model.t(.workdaysHint),
                    tint: Palette.normal,
                    value: settingBinding(\.workDaysPerMonth),
                    suffix: model.t(.daysSuffix)
                )

                rowDivider

                SettingNumberRow(
                    icon: "clock.fill",
                    title: model.t(.hoursPerDay),
                    caption: model.t(.hoursHint),
                    tint: Palette.normal,
                    value: settingBinding(\.hoursPerDay),
                    suffix: model.t(.hoursSuffix)
                )

                rowDivider

                SettingNumberRow(
                    icon: "bolt.fill",
                    title: model.t(.overtimeHourly),
                    caption: model.t(.overtimeHourlyHint),
                    tint: Palette.gold,
                    value: settingBinding(\.overtimeHourlyRate),
                    suffix: "\(model.currency.code)/\(model.t(.perHourSuffix))"
                )

                HStack {
                    if !model.settings.isValid {
                        Label(model.t(.invalidIncome), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.danger)
                    }
                    Spacer()
                    Button {
                        model.useSuggestedOvertimeRate()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8.5, weight: .bold))
                            Text(
                                model.t(
                                    .fillSuggestedRate,
                                    model.money(model.settings.suggestedOvertimeHourlyRate)
                                )
                            )
                        }
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.goldDeep)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.settings.isValid)
                }
                .padding(.top, 8)
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 4)
            .cardSurface(cornerRadius: 17)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Palette.line)
            .frame(height: 0.8)
            .padding(.leading, 40)
    }

    // MARK: - Rates

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            SmallCapsLabel(text: model.t(.calculatedRates))

            VStack(spacing: 11) {
                HStack(spacing: 0) {
                    RateMetric(
                        label: model.t(.perSecond),
                        symbol: model.currency.symbol,
                        value: model.amount(model.settings.normalPerSecondRate, precise: true),
                        tint: Palette.ink
                    )
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 0.8, height: 26)
                        .padding(.horizontal, 9)
                    RateMetric(
                        label: model.t(.perMinute),
                        symbol: model.currency.symbol,
                        value: model.amount(model.settings.normalPerMinuteRate),
                        tint: Palette.ink
                    )
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 0.8, height: 26)
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
                        label: model.t(.regularHourly),
                        value: model.money(model.settings.normalHourlyRate)
                    )
                    Spacer(minLength: 0)
                    SummaryStat(
                        label: model.t(.overtimeHourly),
                        value: model.money(model.settings.overtimePerMinuteRate * 60)
                    )
                    Spacer(minLength: 0)
                    SummaryStat(
                        label: model.t(.dailyTarget),
                        value: model.money(model.settings.dailyPay)
                    )
                }

                Text(
                    model.t(
                        .formulaNote,
                        model.count(model.settings.workDaysPerMonth),
                        model.count(model.settings.hoursPerDay)
                    )
                )
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .cardSurface(cornerRadius: 17)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Palette.normalSoft)
                    .frame(width: 34, height: 34)
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.normal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.t(.sessionTotal))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
                Text(model.money(model.snapshot.total))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.ink)
            }

            Spacer()

            Button {
                showResetAlert = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9, weight: .bold))
                    Text(model.t(.reset))
                }
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(model.session.hasRecordedTime ? Palette.danger : Palette.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(model.session.hasRecordedTime ? Palette.danger.opacity(0.09) : Palette.surfaceMuted)
                )
            }
            .buttonStyle(.plain)
            .disabled(!model.session.hasRecordedTime)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .cardSurface(cornerRadius: 17)
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 8.5, weight: .semibold))
                .padding(.top, 1.5)
            Text(model.t(.privacyNote))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Palette.tertiary)
        .padding(.horizontal, 2)
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
    let caption: String
    let tint: Color
    @Binding var value: Double
    let suffix: String

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.10))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(caption)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
            }

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
                        .strokeBorder(focused ? tint.opacity(0.65) : Palette.line, lineWidth: 0.8)
                )

                Text(suffix)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 54, alignment: .leading)
            }
        }
        .frame(height: 45)
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
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
