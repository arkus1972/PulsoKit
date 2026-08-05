import AppKit
import Combine
import SwiftUI

struct ContentView: View {
    /// Jedno miejsce na numer wersji — pokazuje go pasek tytułu i ekran
    /// wygaśnięcia.
    static let version = "v0.98"

    @EnvironmentObject private var midi: MIDIManager
    @EnvironmentObject private var td0: TD0EditorModel
    @EnvironmentObject private var kitEditor: KitEditor
    @State private var selectedPadGroup: PadGroup = .all

    /// Tyka co minutę tylko po to, żeby przeliczyć termin ważności.
    /// Bez tego wygaśnięcie o północy zauważyłby dopiero pierwszy ruch
    /// w interfejsie.
    @State private var expiryTick = 0
    @State private var selectedSection: AppSection = .editor

    /// Pięć sekcji zamiast siedmiu.
    ///
    /// Zestaw, Instrumenty, V-Edit i MIDI dzieliły parametry po **typie**, więc
    /// żeby ustawić jeden pad, trzeba było obejść cztery ekrany — a każdy z nich
    /// pokazywał te same dwadzieścia stref. Wszystko, co edytuje kit, siedzi
    /// teraz w Editorze. Tutaj zostaje to, co edycją nie jest: kopie zapasowe,
    /// pliki TD0 i podgląd komunikacji.
    private enum AppSection: String, CaseIterable, Identifiable {
        case editor = "Editor"
        case triggers = "Triggers"
        case backup = "Backup"
        case td0 = "TD0 file"
        case log = "Log"

        var id: Self { self }
        var icon: String {
            switch self {
            case .editor: "slider.horizontal.below.rectangle"
            case .triggers: "dot.radiowaves.left.and.right"
            case .backup: "externaldrive.badge.timemachine"
            case .td0: "doc.badge.gearshape"
            case .log: "text.alignleft"
            }
        }
    }

    private enum PadGroup: String, CaseIterable, Identifiable {
        case all = "All"
        case kick = "Kick"
        case snare = "Snare"
        case toms = "Toms"
        case hiHat = "Hi-hat"
        case cymbals = "Cymbals"
        case aux = "AUX"

        var id: Self { self }

        func contains(_ zoneIndex: Int) -> Bool {
            switch self {
            case .all: true
            case .kick: zoneIndex == 0
            case .snare: (1...2).contains(zoneIndex)
            case .toms: (3...8).contains(zoneIndex)
            case .hiHat: (9...10).contains(zoneIndex)
            case .cymbals: (11...17).contains(zoneIndex)
            case .aux: (18...19).contains(zoneIndex)
            }
        }
    }

    var body: some View {
        // Wersja testowa po terminie nie wpuszcza dalej. Sprawdzenie jest tu,
        // a nie przy starcie, bo program potrafi chodzić tygodniami — data
        // musi być sprawdzana także wtedy, gdy termin minie w trakcie pracy.
        Group {
            // `expiryTick` wchodzi tu jako argument tylko po to, żeby widok
            // zależał od zegara — inaczej SwiftUI nie miałby powodu przeliczyć
            // terminu, dopóki nie zmieni się cokolwiek innego.
            if hasExpired(at: expiryTick) {
                expiredScreen
            } else {
                editor
            }
        }
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { _ in
            AppExpiry.stampToday()
            expiryTick &+= 1
        }
        .task { AppExpiry.stampToday() }
    }

    private func hasExpired(at tick: Int) -> Bool {
        _ = tick
        return AppExpiry.hasExpired
    }

    private var expiredScreen: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.063, blue: 0.082),
                    Color(red: 0.025, green: 0.030, blue: 0.043)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "hourglass")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.orange)
                Text("This test version has expired")
                    .font(.system(size: 22, weight: .bold))
                Text("PulsoKit \(Self.version) stopped working on \(AppExpiry.formattedDeadline).")
                    .foregroundStyle(.secondary)
                Text("Nothing was changed in your module. Ask for a newer build.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(40)
        }
        .frame(minWidth: 520, minHeight: 320)
        .preferredColorScheme(.dark)
    }

    private var editor: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.063, blue: 0.082),
                    Color(red: 0.025, green: 0.030, blue: 0.043)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                if AppExpiry.shouldWarn {
                    Label(
                        "This test version stops working on "
                            + "\(AppExpiry.formattedDeadline) "
                            + "(\(AppExpiry.daysLeft) days left).",
                        systemImage: "hourglass"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                header
                connectionBar
                appNavigation
                activeSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
        }
        .frame(minWidth: 1080, minHeight: 740)
        .preferredColorScheme(.dark)
        // Przepisanie stanu z modułu musi siedzieć tutaj, a nie w ekranie
        // edytora. Odczyt bywa uruchamiany z sekcji Backup — a wtedy ekranu
        // edytora nie ma w drzewie widoków i sygnał o zakończonym odczycie
        // przepadał, zostawiając edytor ze starymi wartościami wyjściowymi.
        .onChange(of: midi.kitReadGeneration) {
            kitEditor.capture(from: midi)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "waveform.path")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .shadow(color: .cyan.opacity(0.25), radius: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("PulsoKit")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(Self.version)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                HStack(spacing: 7) {
                    Circle()
                        .fill(midi.moduleAvailable ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(midi.moduleAvailable ? "TD-17 connected" : "Module not connected")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(midi.moduleAvailable ? .green : .secondary)
                    Text("•").foregroundStyle(.tertiary)
                    Text(midi.status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()

            // `displayedKitNumber`, nie `currentKitNumber`: ten drugi jest
            // zerowany na czas odczytu, więc cała karta razem z przyciskami
            // zmiany kitu znikała dokładnie po ich naciśnięciu.
            if let number = midi.displayedKitNumber {
                HStack(spacing: 12) {
                    // Karta kitu **jest** listą — osobna ikonka obok niej była
                    // drugim przyciskiem do tej samej rzeczy.
                    kitListMenu(current: number)

                    // Przełączanie kitu w module. Numer kitu leży pod tym samym
                    // adresem SysEx, spod którego go czytamy, więc zapis pod
                    // niego przestawia moduł.
                    VStack(spacing: 2) {
                        Button {
                            midi.selectNextKit()
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 22, height: 15)
                        }
                        .disabled(midi.isOperationInProgress || number >= 100)
                        Button {
                            midi.selectPreviousKit()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .frame(width: 22, height: 15)
                        }
                        .disabled(midi.isOperationInProgress || number <= 1)
                    }
                    .buttonStyle(.bordered)
                    .help("Change the kit in the module")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.white.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                midi.exportCurrentKitSnapshot()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(midi.kitCommon == nil || midi.isOperationInProgress)

            Button {
                midi.importSnapshotPreview()
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(midi.isOperationInProgress)
        }
    }

    /// Lista wszystkich kitów z modułu — jedna, płaska.
    ///
    /// Zawartość dostaje gotowe wartości, a nie cały `MIDIManager`. Dzięki
    /// temu sto pozycji przelicza się tylko wtedy, gdy zmienią się nazwy albo
    /// bieżący kit — a nie przy każdym drgnięciu statusu połączenia.
    private func kitListMenu(current: Int) -> some View {
        KitListMenu(
            names: midi.kitNames,
            current: current,
            title: midi.currentKitName ?? "Reading…",
            progress: midi.kitListProgress,
            scanning: midi.isScanningKitList,
            busy: midi.isOperationInProgress || midi.selectedOutputID == nil,
            select: { midi.selectKit($0) },
            rescan: { midi.scanKitList() }
        )
        .equatable()
    }

    private var connectionBar: some View {
        HStack(spacing: 14) {
            Label("CONNECTION", systemImage: "cable.connector")
                .font(.caption.bold())
                .tracking(1)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Picker("Input", selection: $midi.selectedInputID) {
                    Text("None").tag(MIDIEndpointID?.none)
                    ForEach(midi.inputs) { endpoint in
                        Text(endpoint.name).tag(Optional(endpoint.id))
                    }
                }
                .onChange(of: midi.selectedInputID) {
                    midi.connectSelectedInput()
                }
                .disabled(midi.isOperationInProgress)
                .frame(maxWidth: 210)

                Picker("Output", selection: $midi.selectedOutputID) {
                    Text("None").tag(MIDIEndpointID?.none)
                    ForEach(midi.outputs) { endpoint in
                        Text(endpoint.name).tag(Optional(endpoint.id))
                    }
                }
                .disabled(midi.isOperationInProgress)
                .frame(maxWidth: 210)
            }

            Spacer()

            Toggle("Auto read", isOn: $midi.automaticallyReadChangedKit)
                .toggleStyle(.switch)
                .help("Read the parameters automatically when the kit changes on the TD-17")

            Button { midi.refreshDevices() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(midi.isOperationInProgress)

            Button { midi.sendIdentityRequest() } label: {
                Label("Identify module", systemImage: "wave.3.right")
            }
            .disabled(midi.selectedOutputID == nil || midi.isOperationInProgress)

            Button { midi.readCurrentKit() } label: {
                Label("Read full kit", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(midi.selectedOutputID == nil || midi.isOperationInProgress)
        }
        .padding(14)
        .background(.white.opacity(0.05))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var appNavigation: some View {
        HStack(spacing: 6) {
            ForEach(AppSection.allCases) { section in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedSection = section
                    }
                } label: {
                    Label(section.rawValue, systemImage: section.icon)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 9)
                        .foregroundStyle(
                            selectedSection == section ? .white : .secondary
                        )
                        .background(
                            selectedSection == section
                                ? Color.blue.opacity(0.85)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(5)
        .background(.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var activeSection: some View {
        switch selectedSection {
        case .editor: KitScreen(midi: midi, editor: kitEditor)
        case .triggers: TriggersScreen(midi: midi)
        case .backup: backupTab
        case .td0: TD0StudioView(td0: td0)
        case .log: logTab
        }
    }

    private var kitDashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(midi.currentKitName ?? "Select a kit on the TD-17")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    HStack(spacing: 8) {
                        if let number = midi.currentKitNumber {
                            Text("KIT \(number)")
                                .font(.caption.bold())
                                .tracking(1)
                                .foregroundStyle(.cyan)
                        }
                        if !midi.zones.isEmpty {
                            Label(
                                midi.kitCommon == nil
                                    ? "Basic data ready"
                                    : "All details ready",
                                systemImage: midi.kitCommon == nil
                                    ? "bolt.fill"
                                    : "checkmark.seal.fill"
                            )
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                midi.kitCommon == nil ? .orange : .green
                            )
                        }
                    }
                }
                Spacer()
                if !midi.zones.isEmpty, midi.kitCommon == nil {
                    VStack(alignment: .trailing, spacing: 5) {
                        Button {
                            midi.readCurrentKit()
                        } label: {
                            Label(
                                "Load all details",
                                systemImage: "arrow.down.circle.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(midi.isOperationInProgress)
                        Text("SUB, mixer, V-Edit, effects and MIDI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: [.blue.opacity(0.17), .purple.opacity(0.08)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.blue.opacity(0.22), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if !midi.zones.isEmpty {
                HStack(spacing: 6) {
                    ForEach(PadGroup.allCases) { group in
                        Button(group.rawValue) {
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedPadGroup = group
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedPadGroup == group ? .cyan : .gray)
                    }
                    Spacer()
                    Text("\(visibleDashboardZones.count) stref")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 215), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(visibleDashboardZones) { zone in
                        dashboardZoneCard(zone)
                    }
                }
            }
        }
    }

    private var visibleDashboardZones: [TD17ZoneInfo] {
        midi.zones
            .filter { selectedPadGroup.contains($0.index) }
            .sorted { $0.index < $1.index }
    }

    private func dashboardZoneCard(_ zone: TD17ZoneInfo) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(zoneAccent(zone.index).opacity(0.14))
                Image(systemName: zoneIcon(zone.index))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(zoneAccent(zone.index))
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(zone.name)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(zone.instrument.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(zone.instrument.groupName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(zone.instrument.levelText)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(
                    zone.instrument.levelTenthsDB == -601 ? .secondary : .primary
                )
        }
        .padding(12)
        .background(.white.opacity(0.045))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private func zoneAccent(_ index: Int) -> Color {
        switch index {
        case 0: .orange
        case 1...2: .pink
        case 3...8: .blue
        case 9...10: .green
        case 11...17: .yellow
        default: .purple
        }
    }

    private func zoneIcon(_ index: Int) -> String {
        switch index {
        case 0: "circle.inset.filled"
        case 1...2: "circle.hexagongrid.fill"
        case 3...8: "circle.grid.cross.fill"
        case 9...10: "line.3.horizontal"
        case 11...17: "circle.circle.fill"
        default: "waveform"
        }
    }

    private var backupTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                kitDashboard

                if let summary = midi.importedSnapshotSummary {
                    GroupBox("Loaded snapshot") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(summary)
                                    .font(.headline)
                                Spacer()
                                if midi.snapshotNeedsTargetAuthorization,
                                   let target = midi.currentKitNumber {
                                    Button("Set kit \(target) as the import target") {
                                        midi.authorizeSnapshotForCurrentKit()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                                    .disabled(midi.isOperationInProgress)
                                }
                                Button("Compare with the current kit") {
                                    midi.compareImportedSnapshot()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    midi.kitCommon == nil
                                        || midi.isOperationInProgress
                                )
                                if let progress = midi.batchRestoreProgress {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text(progress)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if midi.stabilizationSecondsRemaining > 0 {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Label(
                                        "Settling in the TD-17 — do not change the kit "
                                            + "and do not power off the module "
                                            + "(\(midi.stabilizationSecondsRemaining) s)",
                                        systemImage: "externaldrive.badge.timemachine"
                                    )
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.orange.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            ForEach(
                                Array(midi.importedSnapshotDetails.enumerated()),
                                id: \.offset
                            ) { _, detail in
                                Label(detail, systemImage: "checkmark.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }
                if let differences = midi.snapshotDifferences {
                    GroupBox(
                        differences.isEmpty
                            ? "Comparison — no differences"
                            : "Comparison — \(differences.count) differences"
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            if differences.isEmpty {
                                Label(
                                    "The snapshot matches the current kit.",
                                    systemImage: "checkmark.seal.fill"
                                )
                                .foregroundStyle(.green)
                            } else {
                                Button {
                                    midi.restoreAllSnapshotDifferences()
                                } label: {
                                    Label(
                                        "Fast write of the whole kit",
                                        systemImage: "bolt.fill"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(midi.isOperationInProgress)

                                Divider()

                                if !midi.restorableSnapshotCommonPaths.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of individual general settings",
                                            systemImage: "shield.checkered"
                                        )
                                        HStack {
                                            ForEach(
                                                midi.restorableSnapshotCommonPaths,
                                                id: \.self
                                            ) { path in
                                                Button(
                                                    "Restore \(midi.snapshotCommonLabel(path))"
                                                ) {
                                                    midi.restoreSnapshotCommon(path)
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotInstruments.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of individual instruments",
                                            systemImage: "music.note"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 190),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotInstruments
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotInstrument(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotLevels.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of individual levels",
                                            systemImage: "speaker.wave.2"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 210),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotLevels
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotLevel(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotLayers.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of individual SUB settings",
                                            systemImage: "square.stack.3d.up"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 220),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotLayers
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotLayer(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotPans.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of panoramy",
                                            systemImage: "arrow.left.and.right"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 190),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotPans
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotPan(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotMixSends.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of effect sends",
                                            systemImage: "arrow.triangle.branch"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 225),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotMixSends
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotMixSend(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotEQFields.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of Pad EQ",
                                            systemImage: "waveform"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 225),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotEQFields
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotEQField(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotAmbienceFields.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of Ambience",
                                            systemImage: "building.2"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 205),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotAmbienceFields
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotAmbienceField(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotReverbFields.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of Reverb",
                                            systemImage: "wave.3.right"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 190),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotReverbFields
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotReverbField(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotMFXFields.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of MFX",
                                            systemImage: "wand.and.stars"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 160),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotMFXFields
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotMFXField(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotMasterCompFields.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of Master Comp",
                                            systemImage: "dial.medium"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 220),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotMasterCompFields
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotMasterCompField(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotMIDINotes.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of nut MIDI",
                                            systemImage: "pianokeys"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 205),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotMIDINotes
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotMIDINote(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                if !midi.restorableSnapshotVEdits.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label(
                                            "Safe restore of individual V-Edit fields",
                                            systemImage: "slider.horizontal.3"
                                        )
                                        LazyVGrid(
                                            columns: [
                                                GridItem(
                                                    .adaptive(minimum: 230),
                                                    spacing: 8
                                                )
                                            ],
                                            alignment: .leading,
                                            spacing: 8
                                        ) {
                                            ForEach(
                                                midi.restorableSnapshotVEdits
                                            ) { restore in
                                                Button(
                                                    "Restore \(restore.label)"
                                                ) {
                                                    midi.restoreSnapshotVEdit(
                                                        restore
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                }
                                ForEach(
                                    Array(differences.enumerated()),
                                    id: \.offset
                                ) { _, difference in
                                    Text(difference)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }
            }
            .padding(4)
        }
    }

    private var logTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SysEx traffic").font(.headline)
                Spacer()
                Text("\(midi.logLineCount) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Copy log") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        midi.logText(),
                        forType: .string
                    )
                }
                .disabled(midi.logLineCount == 0)
                Button("Clear log") { midi.clearLog() }

                // Zrzut obszaru ustawień modułu. Wyłącznie odczyt — z tego
                // powstanie mapa adresów, bez której nie da się ruszyć
                // ustawień triggerów.
                Button("Dump module setup") { midi.dumpModuleSetup() }
                    .disabled(midi.isOperationInProgress || midi.selectedOutputID == nil)
            }
            // Log renderowany leniwie, linia po linii.
            //
            // Wcześniej był to jeden `Text` z całą zawartością i włączonym
            // zaznaczaniem. Każda dopisana linia wymuszała ponowne złożenie
            // i rozmierzenie całego bloku tekstu, więc im dłuższa sesja, tym
            // wolniej działała cała aplikacja — do tego stopnia, że odczyt
            // kitu przestawał się mieścić w limicie czasu. `LazyVStack`
            // przelicza tylko widoczne linie.
            ScrollView {
                if midi.logLines.isEmpty {
                    Text("No messages")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(10)
                } else {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(midi.logLines) { line in
                            Text(line.text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .topLeading
                                )
                        }
                    }
                    .padding(10)
                }
            }
            .background(.black.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(6)
    }
}

/// Rozwijana lista stu kitów.
///
/// `Equatable` na wartościach, bez domknięć: `Menu` buduje wszystkie sto
/// pozycji od razu, a nagłówek przelicza się przy każdej zmianie w
/// `MIDIManager` — także przy każdej porcji logu. Bez tego sto przycisków
/// powstawałoby kilkadziesiąt razy w trakcie jednego odczytu.
private struct KitListMenu: View, Equatable {
    static func == (lhs: KitListMenu, rhs: KitListMenu) -> Bool {
        lhs.names == rhs.names
            && lhs.current == rhs.current
            && lhs.title == rhs.title
            && lhs.progress == rhs.progress
            && lhs.scanning == rhs.scanning
            && lhs.busy == rhs.busy
    }

    let names: [Int: String]
    let current: Int
    let title: String
    let progress: Int
    let scanning: Bool
    let busy: Bool
    let select: (Int) -> Void
    let rescan: () -> Void

    var body: some View {
        Menu {
            if names.count < 100 {
                Text(
                    scanning
                        ? "Reading kit list… \(progress)/100"
                        : "The kit list has not been loaded yet"
                )
                Button("Load kit list", action: rescan)
                    .disabled(busy)
            } else {
                // Jedna płaska lista. macOS sam ją przewija, gdy nie mieści
                // się na ekranie — podział na dziesiątki tylko wydłużał drogę
                // do konkretnego kitu.
                ForEach(1...100, id: \.self) { number in
                    Button {
                        select(number)
                    } label: {
                        Text(
                            "\(number)  \(names[number] ?? "—")"
                                + (number == current ? "  ✓" : "")
                        )
                    }
                    .disabled(busy)
                }
                Divider()
                Button("Refresh list", action: rescan)
                    .disabled(busy)
            }
        } label: {
            HStack(spacing: 12) {
                Text("\(current)")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background(.cyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("CURRENT KIT")
                            .font(.caption2.bold())
                            .tracking(1.2)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundStyle(.secondary)
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Click to pick a kit from the list")
    }
}
