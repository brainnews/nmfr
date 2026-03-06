import SwiftUI

struct EQView: View {
    @EnvironmentObject var persistence: PersistenceManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("Equalizer")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Toggle("", isOn: $persistence.eqSettings.enabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }

            // Preset picker
            Picker("", selection: Binding(
                get: { persistence.eqSettings.presetName },
                set: { persistence.eqSettings.applyPreset(named: $0) }
            )) {
                ForEach(EQSettings.presets, id: \.name) { preset in
                    Text(preset.name).tag(preset.name)
                }
                if persistence.eqSettings.presetName == "Custom" {
                    Divider()
                    Text("Custom").tag("Custom")
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .disabled(!persistence.eqSettings.enabled)

            // Band sliders
            HStack(spacing: 4) {
                ForEach(0..<EQSettings.bandCount, id: \.self) { band in
                    BandColumn(
                        gain: Binding(
                            get: { persistence.eqSettings.gains[band] },
                            set: { persistence.eqSettings.setGain($0, at: band) }
                        ),
                        label: EQSettings.bandLabels[band],
                        isEnabled: persistence.eqSettings.enabled
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(width: 210)
    }
}

// MARK: - Band column

private struct BandColumn: View {
    @Binding var gain: Float
    let label: String
    let isEnabled: Bool

    private let sliderLength: CGFloat = 90
    private let sliderWidth:  CGFloat = 24

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 0 dB centre mark
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: sliderWidth, height: 1)

                // Vertical slider (rotate horizontal slider –90°)
                Slider(
                    value: Binding(
                        get: { Double(gain) },
                        set: { gain = Float($0) }
                    ),
                    in: EQSettings.gainRange,
                    step: 1
                )
                .frame(width: sliderLength)
                .rotationEffect(.degrees(-90))
                .frame(width: sliderWidth, height: sliderLength)
                .disabled(!isEnabled)
            }
            .frame(width: sliderWidth, height: sliderLength)

            // dB value
            Text(gainText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(gain == 0 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .frame(width: sliderWidth)

            // Frequency label
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: sliderWidth)
        }
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var gainText: String {
        let i = Int(gain)
        if i == 0   { return "0" }
        if i > 0    { return "+\(i)" }
        return "\(i)"
    }
}
