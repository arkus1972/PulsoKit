import SwiftUI

struct TD0StudioView: View {
    @ObservedObject var td0: TD0EditorModel
    @State private var selectedZone = 1
    @State private var page: StudioPage = .kit

    private enum StudioPage: Int, CaseIterable, Identifiable {
        case kit, effects, midi, general
        var id: Int { rawValue }

        var title: String {
            switch self {
            case .kit: "Kit"
            case .effects: "Effects"
            case .midi: "MIDI"
            case .general: "General"
            }
        }

        var icon: String {
            switch self {
            case .kit: "drum.fill"
            case .effects: "waveform"
            case .midi: "pianokeys"
            case .general: "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            toolbar
            if td0.isValid {
                HStack(spacing: 12) {
                    sidebar
                    VStack(spacing: 12) {
                        mainPage
                        mixer
                    }
                    inspector
                }
            } else {
                emptyState
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private var mainPage: some View {
        switch page {
        case .kit:
            // Scena musi obserwować wybraną strefę, żeby podpis z poziomem
            // odświeżał się na bieżąco. `TD0StudioView` obserwuje tylko
            // `td0`, a edycja poziomu zmienia `TD0ZoneDraft`, nie tablicę
            // `zones` — dokładnie ten sam problem, co wcześniej z mikserem.
            StudioStage(
                zone: td0.zones.first { $0.index == selectedZone },
                selectedZone: $selectedZone
            )
        case .effects:
            effectsPage
        case .midi:
            midiPage
        case .general:
            generalPage
        }
    }

    // MARK: - Chrome

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(td0.isValid ? td0.kitName : "PulsoKit Studio")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text(
                    td0.isValid
                        ? (td0.fileName ?? "TD0")
                        : "Visual TD-17 kit editor"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if td0.isValid {
                Label("MD5 OK", systemImage: "checkmark.shield.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
            Button("Open TD0") { td0.open() }
                .buttonStyle(.bordered)
            Button("Save a copy") { td0.exportCopy() }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(!td0.isValid)
        }
        .padding(14)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("STUDIO")
                .font(.caption2.bold())
                .tracking(1.4)
                .foregroundStyle(.secondary)
            ForEach(StudioPage.allCases) { target in
                navButton(target)
            }
            Divider()
            Text("KIT")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            TextField("Name", text: $td0.kitName)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $td0.kitDescription)
                .textFieldStyle(.roundedBorder)
            Spacer()
            Label(
                td0.hasUserSamples ? "User Samples" : "No User Samples",
                systemImage: td0.hasUserSamples ? "waveform" : "waveform.slash"
            )
            Text("Format \(td0.formatVersion ?? "—")")
        }
        .font(.caption)
        .padding(12)
        .frame(width: 166)
        .background(.black.opacity(0.23))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func navButton(_ target: StudioPage) -> some View {
        Button {
            page = target
        } label: {
            HStack {
                Image(systemName: target.icon).frame(width: 22)
                Text(target.title)
                Spacer()
            }
            .padding(9)
            .foregroundStyle(page == target ? .cyan : .primary)
            .background(page == target ? .cyan.opacity(0.15) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mikser

    private var mixer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(td0.zones) { zone in
                    // Osobny widok obserwujący `zone`. Wcześniej pasek
                    // czytał `zone.mainLevel` w ciele widoku nadrzędnego,
                    // który obserwuje tylko `td0` — a tablica `zones` nie
                    // zmienia tożsamości przy edycji poziomu, więc miernik
                    // pokazywał nieaktualną wartość aż do przypadkowego
                    // przerysowania.
                    StudioMixerStrip(
                        zone: zone,
                        selected: selectedZone == zone.index
                    ) {
                        selectedZone = zone.index
                        page = .kit
                    }
                }
            }
            .padding(8)
        }
        .frame(height: 116)
        .background(.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var inspector: some View {
        Group {
            if let zone = td0.zones.first(where: { $0.index == selectedZone }) {
                StudioZoneInspector(zone: zone)
            } else {
                Text("Select a zone")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(minWidth: 330, maxWidth: 330, maxHeight: .infinity, alignment: .top)
        .background(.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Efekty

    private var effectsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !td0.supportsExpandedEffects {
                    Label(
                        "TD0 1.x has no Ambience, Reverb or "
                            + "compressor blocks — only MFX is available.",
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.orange)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                ambienceCard
                reverbCard
                compressorCard
                mfxCard
            }
            .padding(12)
        }
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var ambienceCard: some View {
        card("Ambience", "speaker.wave.3") {
            Toggle("Enabled", isOn: $td0.ambienceEnabled)
                .toggleStyle(.switch)
            catalogPicker("Type", $td0.ambienceType, TD17AmbienceCatalog.roomTypes)
            catalogPicker("Size", $td0.ambienceSize, TD17AmbienceCatalog.roomSizes)
            stepperRow(
                "Shape",
                $td0.ambienceShape,
                MIDIManager.roomShapeRange
            )
            catalogPicker("Wall", $td0.ambienceWall, TD17AmbienceCatalog.wallTypes)
            catalogPicker("Mic", $td0.ambienceMic, TD17AmbienceCatalog.micPositions)
            levelRow("Level", $td0.ambienceLevel)
        }
        .disabled(!td0.supportsExpandedEffects)
        .opacity(td0.supportsExpandedEffects ? 1 : 0.45)
    }

    private var reverbCard: some View {
        card("Reverb", "waveform.path.ecg") {
            Toggle("Enabled", isOn: $td0.reverbEnabled)
                .toggleStyle(.switch)
            catalogPicker(
                "Type",
                arrayBinding($td0.reverbParameters, 0),
                TD17ReverbCatalog.types
            )
            ForEach(TD17ReverbCatalog.parameterNames.indices, id: \.self) { index in
                stepperRow(
                    TD17ReverbCatalog.parameterNames[index],
                    arrayBinding($td0.reverbParameters, index + 1),
                    0...127
                )
            }
            levelRow("Level", $td0.reverbLevel)
            Text(
                "The 9-byte Reverb layout in a TD0 file is read by "
                    + "analogy with the SysEx block (type + 8 parameters) and needs "
                    + "confirmation on hardware."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .disabled(!td0.supportsExpandedEffects)
        .opacity(td0.supportsExpandedEffects ? 1 : 0.45)
    }

    private var compressorCard: some View {
        card("Kompresor", "dial.medium") {
            Toggle("Enabled", isOn: $td0.compressorEnabled)
                .toggleStyle(.switch)
            catalogPicker(
                "Type",
                $td0.compressorType,
                TD17MasterCompCatalog.types
            )
            stepperRow("Mix Balance", $td0.compressorMixBalance, 0...127)
            Text(
                "A TD0 file carries only these three compressor fields. Thresholds, "
                    + "ratio, attack and release are not mapped in it and "
                    + "stay untouched when saving."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .disabled(!td0.supportsExpandedEffects)
        .opacity(td0.supportsExpandedEffects ? 1 : 0.45)
    }

    private var mfxCard: some View {
        card("MFX", "slider.horizontal.below.rectangle") {
            Toggle("Enabled", isOn: $td0.mfxEnabled)
                .toggleStyle(.switch)
            catalogPicker("Type", $td0.mfxType, TD17MFXCatalog.types)
            levelRow("Level", $td0.mfxLevel)

            Text("PARAMETRY")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Text(
                "The meaning of the parameters depends on the MFX type and is not "
                    + "decoded — the values are raw."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 128), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(td0.mfxParameters.indices, id: \.self) { index in
                    numberField(
                        String(format: "P%02d", index + 1),
                        arrayBinding($td0.mfxParameters, index)
                    )
                }
            }
        }
    }

    // MARK: - MIDI

    private var midiPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(
                    "The note number each zone sends. "
                        + "128 means OFF."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(td0.midiNotes.indices, id: \.self) { index in
                        HStack {
                            Text(noteName(index))
                                .font(.caption.bold())
                            Spacer()
                            Stepper(
                                value: arrayBinding($td0.midiNotes, index),
                                in: MIDIManager.midiNoteRange
                            ) {
                                Text(
                                    TD17MIDINoteCatalog.text(
                                        td0.midiNotes[index]
                                    )
                                )
                                .font(.body.monospacedDigit().bold())
                                .foregroundStyle(
                                    td0.midiNotes[index] == 128
                                        ? .orange
                                        : .primary
                                )
                            }
                        }
                        .padding(8)
                        .background(.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(12)
        }
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func noteName(_ index: Int) -> String {
        TD17MIDINoteCatalog.names.indices.contains(index)
            ? TD17MIDINoteCatalog.names[index]
            : "STREFA \(index + 1)"
    }

    // MARK: - Ustawienia ogólne

    private var generalPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                card("Volumes", "speaker.wave.2") {
                    levelRow("Kit volume", $td0.kitVolume, MIDIManager.levelRange)
                    levelRow("Pedal Hi-Hat", $td0.pedalHHVolume, MIDIManager.levelRange)
                    levelRow("Cross Stick", $td0.xStickVolume, MIDIManager.levelRange)
                }

                card("Other", "slider.horizontal.3") {
                    Toggle("Cross stick enabled", isOn: $td0.crossStickEnabled)
                        .toggleStyle(.switch)
                    stepperRow(
                        "Balans Hi-Hat",
                        $td0.hiHatBalance,
                        MIDIManager.hiHatBalanceRange
                    )
                    Text(
                        "The hi-hat balance scale in a TD0 file is not "
                            + "confirmed — the range comes from the SysEx map "
                            + "of the module. Saving the file does not change a value "
                            + "you do not touch."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                card("File", "doc.text") {
                    infoRow("Name", td0.fileName ?? "—")
                    infoRow("Format", td0.formatVersion ?? "—")
                    infoRow(
                        "User Samples",
                        td0.hasUserSamples ? "obecne" : "none"
                    )
                    infoRow("Weryfikacja", td0.validationMessage)
                }
            }
            .padding(12)
        }
        .background(.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Elementy wspólne

    private func card<Content: View>(
        _ title: String,
        _ icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.cyan)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func catalogPicker(
        _ title: String,
        _ value: Binding<Int>,
        _ catalog: [String]
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            if catalog.indices.contains(value.wrappedValue) {
                Picker("", selection: value) {
                    ForEach(catalog.indices, id: \.self) { index in
                        Text(catalog[index]).tag(index)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)
            } else {
                // Wartość spoza katalogu — pokazujemy ją surowo zamiast
                // po cichu podmieniać na pierwszą pozycję.
                Text("nieznana (\(value.wrappedValue))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
            }
        }
    }

    private func stepperRow(
        _ title: String,
        _ value: Binding<Int>,
        _ range: ClosedRange<Int>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
            }
            .frame(maxWidth: 150)
        }
    }

    private func levelRow(
        _ title: String,
        _ value: Binding<Int>,
        _ range: ClosedRange<Int> = MIDIManager.effectLevelRange
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: value, in: range) {
                Text(levelText(value.wrappedValue))
                    .monospacedDigit()
            }
            .frame(maxWidth: 150)
        }
    }

    private func numberField(
        _ title: String,
        _ value: Binding<Int>
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.caption)
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            Image(systemName: "drum")
                .font(.system(size: 54))
                .foregroundStyle(.cyan)
            Text("Open a TD-17 kit").font(.title2.bold())
            Text("PulsoKit will show it as a visual kit.")
                .foregroundStyle(.secondary)
            Button("Open a TD0 file") { td0.open() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Pomocnicze

    private func levelText(_ value: Int) -> String {
        value == -601 ? "-INF" : String(format: "%+.1f dB", Double(value) / 10)
    }

    private func arrayBinding(
        _ values: Binding<[Int]>,
        _ index: Int
    ) -> Binding<Int> {
        Binding(
            get: {
                values.wrappedValue.indices.contains(index)
                    ? values.wrappedValue[index]
                    : 0
            },
            set: {
                guard values.wrappedValue.indices.contains(index) else { return }
                values.wrappedValue[index] = $0
            }
        )
    }
}

// MARK: - Scena zestawu

/// Cienka obudowa na `TD17KitStage`, która obserwuje wybraną strefę.
private struct StudioStage: View {
    let zone: TD0ZoneDraft?
    @Binding var selectedZone: Int

    var body: some View {
        if let zone {
            ObservedStage(zone: zone, selectedZone: $selectedZone)
        } else {
            TD17KitStage(selectedZone: $selectedZone)
        }
    }

    private struct ObservedStage: View {
        @ObservedObject var zone: TD0ZoneDraft
        @Binding var selectedZone: Int

        var body: some View {
            TD17KitStage(selectedZone: $selectedZone) { _ in
                zone.mainLevel == -601
                    ? "-INF"
                    : String(format: "%+.1f dB", Double(zone.mainLevel) / 10)
            }
        }
    }
}

// MARK: - Pasek miksera

private struct StudioMixerStrip: View {
    @ObservedObject var zone: TD0ZoneDraft
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Capsule()
                    .fill(zone.mainLevel > 0 ? .orange : .green)
                    .frame(width: 7, height: meter)
                    .frame(height: 43, alignment: .bottom)
                Text(shortName)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                Text(levelText)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 96)
            .background(selected ? .cyan.opacity(0.16) : .white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var meter: CGFloat {
        zone.mainLevel == -601
            ? 2
            : max(3, min(43, CGFloat(zone.mainLevel + 601) / 661 * 43))
    }

    private var levelText: String {
        zone.mainLevel == -601
            ? "-INF"
            : String(format: "%+.1f", Double(zone.mainLevel) / 10)
    }

    private var shortName: String {
        zone.name
            .replacingOccurrences(of: " HEAD", with: "")
            .replacingOccurrences(of: " RIM", with: " R")
            .replacingOccurrences(of: "HI-HAT", with: "HH")
    }
}

// MARK: - Inspektor strefy

private struct StudioZoneInspector: View {
    @ObservedObject var zone: TD0ZoneDraft

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("SELECTED ITEM")
                    .font(.caption2.bold())
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(zone.name).font(.title2.bold())

                section("MAIN") {
                    HStack {
                        Text("Instrument")
                        Spacer()
                        TD17InstrumentPicker(selection: $zone.mainInstrument)
                    }
                    levelControl("Level", $zone.mainLevel)
                    // Plik TD0 dopuszcza -64…64, mapa SysEx modułu -64…63.
                    // Trzymamy się zakresu pliku, żeby nie obcinać danych,
                    // których ten edytor nie zapisuje do modułu.
                    slider("Pan", $zone.pan, -64...64)
                }

                section("SUB") {
                    Toggle("Enabled", isOn: $zone.subEnabled)
                        .toggleStyle(.switch)
                    HStack {
                        Text("Instrument")
                        Spacer()
                        TD17InstrumentPicker(selection: $zone.subInstrument)
                    }
                    levelControl("Level", $zone.subLevel)
                    catalogRow("Layer type", $zone.layerType, TD17LayerCatalog.types)
                    field("Fade Point", $zone.fadePoint)
                }

                section("V‑EDIT MAIN") {
                    field("Tuning / Size", array($zone.mainVEdit, 0))
                    field("Muffling / Decay", array($zone.mainVEdit, 1))
                    field("Strainer / Buzz", array($zone.mainVEdit, 2))
                }

                section("V‑EDIT SUB") {
                    field("Tuning / Size", array($zone.subVEdit, 0))
                    field("Muffling / Decay", array($zone.subVEdit, 1))
                    field("Strainer / Buzz", array($zone.subVEdit, 2))
                }

                section("SENDS") {
                    levelControl("Ambience", $zone.ambienceSend)
                    levelControl("MFX", $zone.mfxSend)
                    levelControl("Reverb", $zone.reverbSend)
                }

                section("PAD EQ") {
                    Toggle("Enabled", isOn: $zone.eqEnabled)
                        .toggleStyle(.switch)
                    catalogRow(
                        "LOW Freq",
                        $zone.eqLowFrequency,
                        TD17EQCatalog.lowFrequencies
                    )
                    field("LOW Gain", $zone.eqLowGain)
                    catalogRow(
                        "MID Freq",
                        $zone.eqMidFrequency,
                        TD17EQCatalog.midFrequencies
                    )
                    catalogRow("MID Q", $zone.eqMidQ, TD17EQCatalog.qValues)
                    field("MID Gain", $zone.eqMidGain)
                    catalogRow(
                        "HIGH Freq",
                        $zone.eqHighFrequency,
                        TD17EQCatalog.highFrequencies
                    )
                    field("HIGH Gain", $zone.eqHighGain)
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(.cyan)
            content()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func field(_ title: String, _ value: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 76)
        }
    }

    private func catalogRow(
        _ title: String,
        _ value: Binding<Int>,
        _ catalog: [String]
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            if catalog.indices.contains(value.wrappedValue) {
                Picker("", selection: value) {
                    ForEach(catalog.indices, id: \.self) { index in
                        Text(catalog[index]).tag(index)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 130)
            } else {
                Text("? (\(value.wrappedValue))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
            }
        }
    }

    private func levelControl(
        _ title: String,
        _ value: Binding<Int>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Stepper(value: value, in: MIDIManager.levelRange) {
                Text(
                    value.wrappedValue == -601
                        ? "-INF"
                        : String(format: "%+.1f", Double(value.wrappedValue) / 10)
                )
                .monospacedDigit()
            }
        }
    }

    private func slider(
        _ title: String,
        _ value: Binding<Int>,
        _ range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)").monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
        }
    }

    private func array(_ values: Binding<[Int]>, _ index: Int) -> Binding<Int> {
        Binding(
            get: {
                values.wrappedValue.indices.contains(index)
                    ? values.wrappedValue[index]
                    : 0
            },
            set: {
                guard values.wrappedValue.indices.contains(index) else { return }
                values.wrappedValue[index] = $0
            }
        )
    }
}
