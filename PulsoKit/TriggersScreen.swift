import SwiftUI

/// Ustawienia triggerów odczytane z modułu.
///
/// Na razie **wyłącznie do odczytu**. Mapa adresów powstała ze zrzutu z żywego
/// modułu i została sprawdzona przez porównanie z jego ekranem, ale zanim
/// program pozwoli tu cokolwiek zapisać, wartości muszą się zgodzić co do
/// liczby — źle trafiony adres rozstraja odczyt pada, a to psuje granie,
/// nie tylko brzmienie.
struct TriggersScreen: View {
    @ObservedObject var midi: MIDIManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if midi.triggers.isEmpty {
                ContentUnavailableView(
                    "Trigger settings not loaded",
                    systemImage: "dot.radiowaves.left.and.right",
                    description: Text(
                        midi.isReadingTriggers
                            ? "Reading from the module…"
                            : "Press “Read from module”."
                    )
                )
            } else {
                table
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TRIGGERS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(
                    midi.triggers.isEmpty
                        ? "Read only — values come straight from the module"
                        : "Read only — \(midi.triggers.count)/10 inputs"
                )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let common = midi.triggerCommon {
                Label(
                    "Cross stick adjust \(common.crossStickAdjust)",
                    systemImage: "slider.horizontal.3"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if midi.isReadingTriggers {
                ProgressView().controlSize(.small)
            }

            Button {
                midi.readTriggerSettings()
            } label: {
                Label("Read from module", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.pulsoAccent)
            .disabled(midi.isOperationInProgress || midi.selectedOutputID == nil)
        }
    }

    private var table: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerRow
                Divider()
                ForEach(midi.triggers) { trigger in
                    row(trigger)
                    if trigger.input != midi.triggers.last?.input {
                        Divider().opacity(0.4)
                    }
                }
            }
            .padding(10)
        }
        .background(.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            cell("INPUT", width: 78, align: .leading)
            cell("PAD TYPE", width: 104, align: .leading)
            cell("SENS", width: 52)
            cell("THRES", width: 56)
            cell("CURVE", width: 66)
            cell("RIM", width: 46)
            cell("H/R ADJ", width: 62)
            cell("SCAN", width: 60)
            // Ostatnie trzy w grupie: `ViewBuilder` liczy dzieci i jedenaście
            // komórek plus odstęp jest już nad limitem starszych przeciążeń.
            Group {
                cell("MASK", width: 54)
                cell("RETRIG", width: 58)
                cell("XTALK", width: 54)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }

    private func row(_ t: TD17TriggerInfo) -> some View {
        HStack(spacing: 0) {
            cell(t.name, width: 78, align: .leading, bold: true)
            cell(t.padTypeName, width: 104, align: .leading)
            cell("\(t.sensitivity)", width: 52)
            cell("\(t.threshold)", width: 56)
            cell(t.curveName, width: 66)
            // Pad bez obręczy ma tu zero i wtedy kreska mówi więcej niż liczba.
            cell(t.rimGainTenths == 0 ? "—" : t.rimGainText, width: 46)
            cell(t.headRimAdjust == 0 ? "—" : "\(t.headRimAdjust)", width: 62)
            cell(t.scanTimeText, width: 60)
            Group {
                cell("\(t.maskTimeMs)", width: 54)
                cell("\(t.retrigCancel)", width: 58)
                cell(t.crosstalkCancel.map { "\($0)" } ?? "—", width: 54)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.vertical, 5)
    }

    private func cell(
        _ text: String,
        width: CGFloat,
        align: Alignment = .trailing,
        bold: Bool = false
    ) -> some View {
        Text(text)
            .fontWeight(bold ? .bold : .regular)
            .lineLimit(1)
            .frame(width: width, alignment: align)
            .padding(.horizontal, 4)
    }
}
