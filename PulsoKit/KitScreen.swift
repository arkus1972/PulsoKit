import SwiftUI

/// Nowy ekran edycji kitu: scena, mikser, lista zmian i inspektor strefy.
///
/// Zastępuje zakładki Zestaw / Instrumenty / V-Edit, które dzieliły parametry
/// po typie — żeby zmienić wszystko przy werblu, trzeba było obejść cztery
/// ekrany. Tutaj podział jest po tym, co edytujesz: klikasz pad, po prawej
/// masz komplet jego parametrów.
struct KitScreen: View {
    @ObservedObject var midi: MIDIManager
    @ObservedObject var editor: KitEditor

    /// Lista zmian zjada szerokość potrzebną scenie, a patrzy się w nią raz
    /// na kilkanaście edycji. Dlatego siedzi w dymku pod przyciskiem licznika.
    @State private var showChanges = false

    var body: some View {
        VStack(spacing: 9) {
            if editor.hasCapturedKit {
                content
            } else if midi.isReadingKit {
                // Odczyt startuje teraz sam po uruchomieniu, więc pusty ekran
                // bez słowa wyjaśnienia byłby myleniem użytkownika.
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("Reading the kit from the module…")
                        .font(.headline)
                    Text(midi.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No kit loaded",
                    systemImage: "square.and.arrow.down",
                    description: Text(
                        midi.moduleAvailable
                            ? "Press “Read full kit” to load the kit selected on the module."
                            : "Connect the module and press “Refresh”."
                    )
                )
            }
            bottomBar
        }
    }

    /// Układ przeniesiony z ekranu pliku TD0: pasek stron po lewej, praca
    /// pośrodku, inspektor wybranej strefy przy prawej krawędzi.
    ///
    /// Plik TD0 to ten sam kit co w module, więc oba ekrany robiły tę samą
    /// robotę w dwóch różnych układach. Ten układ okazał się lepszy, więc
    /// przejmuje go edytor modułu.
    private var content: some View {
        HStack(alignment: .top, spacing: 9) {
            sidebar
            centerColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ZoneInspectorColumn(editor: editor)
                .frame(width: 330)
        }
        .frame(maxHeight: .infinity)
    }

    /// Lewy pasek: strony i podstawowe dane kitu.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("EDITOR")
                .font(.caption2.bold())
                .tracking(1.4)
                .foregroundStyle(.secondary)

            ForEach(EditorPage.allCases) { target in
                pageButton(target)
            }

            Divider()

            Text("KIT")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            // Zablokowane w trakcie wysyłki, bo model i tak odrzuca wtedy
            // zmiany — a wpisany tekst zostawałby w polu jako cicha nieprawda.
            Group {
                TextField("Name", text: editor.textBinding(.name))
                    .textFieldStyle(.roundedBorder)
                TextField("Description", text: editor.textBinding(.subName))
                    .textFieldStyle(.roundedBorder)
                if editor.kitNameIsEmpty {
                    Text("Name cannot be empty")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
            }
            .disabled(editor.isSending)

            Spacer()

            sidebarFooter
        }
        .font(.caption)
        .padding(12)
        .frame(width: 166)
        .background(.black.opacity(0.23))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var sidebarFooter: some View {
        if let number = midi.displayedKitNumber {
            Label("KIT \(number)", systemImage: "number")
        }
        Label(
            midi.kitCommon == nil ? "Basic data only" : "Full data",
            systemImage: midi.kitCommon == nil
                ? "exclamationmark.circle"
                : "checkmark.seal"
        )
        .foregroundStyle(midi.kitCommon == nil ? .orange : .secondary)
    }

    private func pageButton(_ target: EditorPage) -> some View {
        Button {
            editor.page = target
        } label: {
            HStack {
                Image(systemName: target.icon).frame(width: 22)
                Text(target.title)
                Spacer()
            }
            .padding(9)
            .foregroundStyle(editor.page == target ? Color.pulsoAccent : .primary)
            .background(
                editor.page == target
                    ? Color.pulsoAccent.opacity(0.15)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var centerColumn: some View {
        switch editor.page {
        case .kit:
            VStack(spacing: 9) {
                TD17KitStage(
                    selectedZone: Binding(
                        get: { editor.selectedZone },
                        set: { zone in
                            editor.selectedZone = zone
                            // Odsłuch idzie za wyborem: klikasz pad, słyszysz
                            // go w module. Próbki siedzą w TD-17, więc gra on,
                            // nie komputer.
                            if midi.auditionEnabled { midi.playZone(zone) }
                        }
                    ),
                    detail: { zone in
                        editor.zone(zone).map {
                            ZoneField.mainLevel.formatted($0.value(.mainLevel))
                        } ?? ""
                    },
                    isMuted: { editor.isMuted($0) },
                    playingZone: midi.nowPlayingZone,
                    zoneNames: midi.profile.zoneNames
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Mały mikser wpięty pod scenę, jak na ekranie pliku TD0:
                // głośność, panorama i wyciszenie, i tyle.
                KitZoneStrip(editor: editor)
                    .frame(height: 118)
            }
        case .effects:
            EffectsPage(editor: editor)
        case .midi:
            MIDIPage(editor: editor)
        case .general:
            GeneralPage(editor: editor)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            auditionControls

            Divider().frame(height: 18)

            changesButton

            statusStrip

            Spacer()

            Button { editor.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(!editor.canUndo)
            Button { editor.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
                .disabled(!editor.canRedo)
            // Odsłuch zmian: wysyła je do modułu na próbę i gra pady, których
            // dotyczą. Inaczej się nie da — dźwięki siedzą w TD-17, więc żeby
            // usłyszeć zmianę, moduł musi ją mieć. Różnica wobec zwykłej
            // wysyłki jest taka, że program pamięta stan sprzed próby.
            if editor.hasPreview {
                Button {
                    editor.revertPreview(using: midi)
                } label: {
                    Label("Undo in module", systemImage: "arrow.uturn.backward.circle")
                }
                // `isBusyWithSysEx`, a nie `isOperationInProgress`: to drugie
                // zawiera odsłuch, a odsłuch startuje zaraz po próbie. Guzik
                // do jej cofnięcia byłby martwy dokładnie wtedy, gdy się go
                // słucha i chce nacisnąć.
                .disabled(editor.isSending || midi.isBusyWithSysEx)
                .help("Restore the values the module had before the preview")
            } else {
                Button {
                    editor.preview(using: midi)
                } label: {
                    Label("Try it", systemImage: "play.circle")
                }
                .disabled(!editor.canPreview || midi.isOperationInProgress)
                .help("Send the changes to the module on trial and play the affected pads")
            }

            // W trakcie wysyłki cała reszta interfejsu MIDI jest zablokowana,
            // więc musi być czym ją przerwać — inaczej przy niemrawym module
            // zostaje tylko czekanie na watchdoga.
            if editor.isSending {
                Button(role: .cancel) {
                    editor.cancelSend()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button {
                    if editor.hasPreview {
                        editor.keepPreview()
                    } else {
                        editor.send(using: midi)
                    }
                } label: {
                    Text(
                        editor.hasPreview
                            ? "Keep \(editor.previewed.count)"
                            : (editor.changes.isEmpty
                                ? "Send changes"
                                : "Send \(editor.changes.count) change\(editor.changes.count == 1 ? "" : "s")")
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.pulsoAccent)
                .disabled(
                    editor.hasPreview
                        ? editor.isSending
                        : (!editor.canSend || midi.isOperationInProgress)
                )
            }
        }
        .padding(.horizontal, 4)
    }

    /// Odsłuch: przełącznik, siła uderzenia i przesłuchanie całego zestawu.
    ///
    /// Program nie ma czym zagrać sam — próbki są w pamięci modułu. Wysyła
    /// więc nutę, a dźwięk wychodzi z TD-17 tak samo jak przy graniu pałkami.
    @ViewBuilder
    private var auditionControls: some View {
        Toggle(isOn: $midi.auditionEnabled) {
            Image(systemName: midi.auditionEnabled ? "speaker.wave.2.fill" : "speaker.slash")
        }
        .toggleStyle(.button)
        .help("Play the pad in the module when you click it")

        if midi.auditionEnabled {
            Slider(
                value: Binding(
                    get: { Double(midi.auditionVelocity) },
                    set: { midi.auditionVelocity = Int($0.rounded()) }
                ),
                in: 1...127
            )
            .frame(width: 80)
            .help("Velocity")

            Text("\(midi.auditionVelocity)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)

            Button {
                midi.auditionKit()
            } label: {
                Label(
                    midi.isAuditioningKit ? "Stop" : "Play kit",
                    systemImage: midi.isAuditioningKit ? "stop.fill" : "play.fill"
                )
            }
            .help("Play every pad of the kit in turn")

            // Na słuchawkach dźwięk słychać, ale nie widać, skąd wyszedł.
            // Scena pokazuje pad, a to nazwę strefy — potrzebną tam, gdzie
            // pad ma ich kilka (werbel, ride) albo gdzie strefy w ogóle nie
            // widać na zdjęciu (obręcze, AUX). Stała szerokość, żeby pasek
            // nie skakał przy każdym uderzeniu.
            Text(playingZoneLabel)
                .font(.caption.weight(.semibold).monospaced())
                .foregroundStyle(Color.pulsoAccent)
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)
                .animation(.easeOut(duration: 0.12), value: midi.nowPlayingZone)
        }
    }

    /// Nazwa strefy, która właśnie zabrzmiała — pusta przy wyciszonej.
    ///
    /// Scena i pastylki wyciszonych nie zapalają. Gdyby pasek robił inaczej,
    /// byłby jedynym miejscem twierdzącym, że coś gra, przy ciszy
    /// w słuchawkach.
    private var playingZoneLabel: String {
        guard let zone = midi.nowPlayingZone, !editor.isMuted(zone) else { return "" }
        return midi.nowPlayingZoneName ?? ""
    }

    /// Postęp wysyłki, błąd wysyłki i komunikat po przeładowaniu kitu.
    /// Razem, żeby dolny pasek nie rósł w nieskończoność bezpośrednimi
    /// dziećmi — `ViewBuilder` ma na to limit.
    @ViewBuilder
    private var statusStrip: some View {
        if let progress = editor.sendProgress {
            ProgressView().controlSize(.small)
            Text(progress).font(.caption).foregroundStyle(.secondary)
        }
        if let failure = editor.sendFailure {
            Label(failure, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
        if let notice = editor.previewNotice {
            Label(notice, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
        if let notice = editor.captureNotice {
            Button {
                editor.dismissCaptureNotice()
            } label: {
                Label(notice, systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
            .buttonStyle(.plain)
            .help("Click to dismiss")
        }
    }

    /// Licznik zmian jest jednocześnie uchwytem do ich listy.
    private var changesButton: some View {
        let count = editor.changes.count
        return Button {
            showChanges.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(
                    count == 0
                        ? "No changes"
                        : "\(count) unsaved change\(count == 1 ? "" : "s")"
                )
                .font(.caption.bold())
                Image(systemName: "chevron.up")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(count == 0 ? 0.4 : 1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                count == 0 ? Color.white.opacity(0.05) : Color.orange.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .foregroundStyle(count == 0 ? Color.secondary : Color.orange)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help("Show the list of pending changes")
        .popover(isPresented: $showChanges) {
            PendingChangesPanel(editor: editor)
                .frame(width: 320, height: 360)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Lista zmian

private struct PendingChangesPanel: View {
    @ObservedObject var editor: KitEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PENDING CHANGES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
                if !editor.changes.isEmpty {
                    Text("(\(editor.changes.count))")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.pulsoAccent)
                }
                Spacer()
                if !editor.changes.isEmpty {
                    Button("revert all") { editor.revertAll() }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            Divider()

            if editor.changes.isEmpty {
                Text("Nothing to send.\nThe kit matches the module.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(editor.changes) { change in
                            row(change)
                        }
                    }
                    .padding(5)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(_ change: KitChange) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(change.groupName).font(.caption.bold())
            HStack(spacing: 5) {
                Text(change.fieldLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(change.fromText)
                    .font(.system(size: 10, design: .monospaced))
                    .strikethrough()
                    .foregroundStyle(.tertiary)
                Text(change.toText)
                    .font(.system(size: 10, design: .monospaced).bold())
                    .foregroundStyle(Color.pulsoAccent)
                Button {
                    editor.revert(change)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 7))
    }
}

// MARK: - Pasek stref

/// Mały mikser pod sceną — na wzór paska z ekranu pliku TD0.
///
/// Dwadzieścia komórek na całą szerokość: słupek poziomu, nazwa, wartość,
/// pasek panoramy i wyciszenie. Tyle wystarczy, żeby ustawić balans zestawu
/// bez schodzenia do inspektora, a wysokość zostaje mała — resztę miejsca
/// bierze rysunek zestawu.
struct KitZoneStrip: View {
    @ObservedObject var editor: KitEditor

    var body: some View {
        // Stała szerokość komórki i przewijanie w poziomie — dokładnie jak
        // w TD0. Rozciąganie dwudziestu komórek na szerokość okna dawało
        // przy węższym oknie 23 punkty na komórkę, czyli same wielokropki
        // zamiast nazw.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(editor.zones) { zone in
                    KitZoneCell(zone: zone, editor: editor)
                }
            }
        }
        .padding(6)
        .background(.black.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }

    /// Wpisane ręcznie — automatyczne obcinanie dawało nierozróżnialne
    /// „SNA…", „CRA…", „RIDE…".
    static let shortNames = [
        "KICK", "SNARE", "SN R", "TOM1", "T1 R", "TOM2", "T2 R",
        "TOM3", "T3 R", "HH", "HH R", "CR1", "CR1 R", "CR2", "CR2 R",
        "RIDE", "RD R", "RD B", "AUX", "AUX R"
    ]

    /// Wypełnienie słupka. Czysta szarość ginęła na ciemnym tle panelu.
    static let trackFill = Color(red: 0.41, green: 0.46, blue: 0.55)

    /// Skala liniowa dawała -10 dB i +3 dB praktycznie tej samej wysokości,
    /// bo realne poziomy kitu siedzą w górnych kilku procentach zakresu.
    static let curve = 2.5

    static func fraction(_ tenths: Int) -> Double {
        guard tenths > -601 else { return 0 }
        return pow(Double(tenths + 601) / 661, curve)
    }

    static func level(from fraction: Double) -> Int {
        let clamped = min(1, max(0, fraction))
        guard clamped > 0.005 else { return -601 }
        let value = Int((-601 + 661 * pow(clamped, 1 / curve)).rounded())
        return min(60, max(-601, value))
    }
}

private struct KitZoneCell: View {
    @ObservedObject var zone: ZoneEditor
    @ObservedObject var editor: KitEditor

    /// Wartość w chwili chwycenia. Edycja jest **względna** — bez tego samo
    /// kliknięcie przestawiało poziom w miejsce kursora.
    @State private var levelAtGrab: Int?
    @State private var panAtGrab: Int?

    /// Gest rozpoczęty na niezaznaczonej strefie tylko ją zaznacza.
    @State private var gestureOnlySelects = false

    private var selected: Bool { zone.index == editor.selectedZone }
    private var muted: Bool { editor.isMuted(zone.index) }

    var body: some View {
        VStack(spacing: 3) {
            muteButton
            meter
            name
            Text(ZoneField.mainLevel.formatted(zone.value(.mainLevel)))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
            pan
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 5)
        .frame(width: 52)
        .background(
            selected ? Color.pulsoAccent.opacity(0.16) : Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.pulsoAccent, lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editor.selectedZone = zone.index }
        .help(zone.name)
    }

    /// Suwak poziomu: rowek w kolorze akcentu i wąski uchwyt.
    ///
    /// Sam słupek nie mówił, że da się go chwycić — uchwyt to pierwsza rzecz,
    /// na którą patrzy ręka. Wysokość uchwytu jest odjęta od drogi, żeby przy
    /// skrajnych wartościach nie wystawał poza rowek.
    private var meter: some View {
        GeometryReader { geo in
            let thumb: CGFloat = 6
            let travel = max(1, geo.size.height - thumb)
            let fraction = KitZoneStrip.fraction(zone.value(.mainLevel))
            let centre = thumb / 2 + travel * fraction

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.opacity(0.45))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    }
                    .frame(width: 12)

                RoundedRectangle(cornerRadius: 6)
                    .fill(fill)
                    .frame(width: 12, height: centre)

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        zone.isChanged(.mainLevel)
                            ? Color.pulsoAccent
                            : Color(white: muted ? 0.55 : 0.88)
                    )
                    .frame(width: 18, height: thumb)
                    .shadow(color: .black.opacity(0.7), radius: 1.5, y: 1)
                    .padding(.bottom, centre - thumb / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if levelAtGrab == nil, !gestureOnlySelects {
                            guard selected else {
                                editor.selectedZone = zone.index
                                gestureOnlySelects = true
                                return
                            }
                            levelAtGrab = zone.value(.mainLevel)
                        }
                        guard let base = levelAtGrab else { return }
                        // `minimumDistance: 0` zgłasza też sam moment
                        // wciśnięcia, z zerowym przesunięciem. Przepuszczony
                        // dalej potrafił wyciszyć pad (przy bardzo niskim
                        // poziomie zaokrąglenie schodzi do -INF) i za każdym
                        // razem kasował stos ponawiania.
                        guard drag.translation.height != 0 else { return }
                        let delta = -drag.translation.height / travel
                        editor.set(
                            .mainLevel,
                            zone: zone.index,
                            to: KitZoneStrip.level(
                                from: KitZoneStrip.fraction(base) + delta
                            )
                        )
                    }
                    .onEnded { _ in
                        levelAtGrab = nil
                        gestureOnlySelects = false
                    }
            )
        }
        .frame(height: 38)
    }

    /// Wyciszenie nad suwakiem, na całą szerokość komórki — nazwa odzyskuje
    /// przez to całe miejsce pod spodem.
    private var muteButton: some View {
        Button {
            editor.toggleMute(zone: zone.index)
        } label: {
            Text("M")
                .font(.system(size: 8, weight: .heavy))
                .frame(maxWidth: .infinity)
                .frame(height: 12)
                .background(
                    muted ? Color.pulsoAccent : Color.white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 3)
                )
                .foregroundStyle(muted ? Color.white : Color.secondary)
                .contentShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .help(muted ? "Odcisz" : "Wycisz")
    }

    private var name: some View {
        Text(KitZoneStrip.shortNames.indices.contains(zone.index)
                ? KitZoneStrip.shortNames[zone.index]
                : "Z\(zone.index + 1)")
            .font(.system(size: 9, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(selected ? .primary : .secondary)
    }

    /// Panorama w tym samym języku co suwak: rowek, wypełnienie od środka
    /// w stronę odchylenia i ten sam jasny uchwyt. Dwuklik wraca na środek.
    private var pan: some View {
        GeometryReader { geo in
            let thumb: CGFloat = 6
            let travel = max(1, geo.size.width - thumb)
            let fraction = Double(zone.value(.pan) + 64) / 127
            let centre = thumb / 2 + travel * fraction
            let middle = thumb / 2 + travel * 0.5

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.black.opacity(0.45))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    }
                    .frame(height: 6)

                // Kreska środka: bez niej „lekko w bok" i „dokładnie CENTER"
                // różnią się ułamkiem punktu.
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1, height: 6)
                    .offset(x: middle - 0.5)

                // Wypełnienie od środka pokazuje kierunek i siłę odchylenia
                // bez czytania liczby.
                RoundedRectangle(cornerRadius: 3)
                    .fill(panFill)
                    .frame(width: abs(centre - middle), height: 6)
                    .offset(x: min(centre, middle))

                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        zone.isChanged(.pan)
                            ? Color.pulsoAccent
                            : Color(white: muted ? 0.55 : 0.88)
                    )
                    .frame(width: thumb, height: 11)
                    .shadow(color: .black.opacity(0.7), radius: 1.5, y: 1)
                    .offset(x: centre - thumb / 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if panAtGrab == nil, !gestureOnlySelects {
                            guard selected else {
                                editor.selectedZone = zone.index
                                gestureOnlySelects = true
                                return
                            }
                            panAtGrab = zone.value(.pan)
                        }
                        guard let base = panAtGrab else { return }
                        guard drag.translation.width != 0 else { return }
                        let delta = drag.translation.width / travel * 127
                        let value = Int((Double(base) + delta).rounded())
                        editor.set(
                            .pan,
                            zone: zone.index,
                            to: min(63, max(-64, value))
                        )
                    }
                    .onEnded { _ in
                        panAtGrab = nil
                        gestureOnlySelects = false
                    }
            )
            .onTapGesture(count: 2) {
                editor.set(.pan, zone: zone.index, to: 0)
            }
        }
        .frame(height: 13)
    }

    /// Rowek w kolorze akcentu — mocniejszy, gdy wartość czeka na wysyłkę.
    /// Oczekująca zmiana jest sprawdzana **przed** wyciszeniem: samo
    /// wyciszenie to zapis poziomu -INF, więc inaczej pad wyciszony w
    /// aplikacji i pad wyciszony już w module wyglądałyby identycznie.
    private var fill: Color {
        if zone.isChanged(.mainLevel) { return Color.pulsoAccent.opacity(0.62) }
        return muted ? Color.white.opacity(0.10) : Color.pulsoAccent.opacity(0.28)
    }

    private var panFill: Color {
        if muted { return Color.white.opacity(0.10) }
        return zone.isChanged(.pan)
            ? Color.pulsoAccent.opacity(0.62)
            : Color.pulsoAccent.opacity(0.28)
    }
}

// MARK: - Inspektor

/// Prawa kolumna: parametry wybranej strefy.
///
/// Stoi niezależnie od otwartej strony — strefę wybiera się na scenie albo
/// w pasku pod nią, a jej parametry mają być pod ręką zawsze.
private struct ZoneInspectorColumn: View {
    @ObservedObject var editor: KitEditor

    var body: some View {
        // W trakcie wysyłki model odrzuca zmiany. Bez zablokowania pól
        // wpisana wartość zostawałaby w polu, choć nigdzie by nie trafiła.
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                if let zone = editor.zone(editor.selectedZone) {
                    ZoneInspector(zone: zone, editor: editor)
                }
            }
            .padding(12)
        }
        .disabled(editor.isSending)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

/// Nagłówek sekcji parametrów.
private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.pulsoAccent)
            content()
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Jeden parametr: nazwa po lewej, kontrolka po prawej.
private struct InspectorRow<Content: View>: View {
    let title: String
    var changed = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 9) {
            Text(title)
                .font(.caption)
                .foregroundStyle(changed ? Color.primary : Color.secondary)
            Spacer(minLength: 6)
            content()
        }
    }
}

// MARK: - Inspektor strefy

private struct ZoneInspector: View {
    @ObservedObject var zone: ZoneEditor
    @ObservedObject var editor: KitEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            mainSection
            vEditSection
            subSection
            sendsSection
            eqSection
            midiSection
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("EDITING ZONE")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Text(zone.name)
                .font(.system(size: 19, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mainSection: some View {
        InspectorSection(title: "MAIN") {
            instrumentRow("Instrument", .mainInstrument)
            levelRow("Level", .mainLevel)
            stepperRow("Pan", .pan, MIDIManager.panRange)
        }
    }

    /// Trzy parametry V-Edit znaczą co innego dla każdej rodziny instrumentów,
    /// więc etykiety i zakresy biorą się z `TD17VEditStyle`.
    @ViewBuilder
    private var vEditSection: some View {
        if !zone.vEditStyle.group.isEmpty {
            InspectorSection(title: "V-EDIT · \(zone.vEditStyle.group)") {
                vEditRows(
                    zone.vEditStyle,
                    primary: .vEditPrimary,
                    secondary: .vEditSecondary,
                    tertiary: .vEditTertiary
                )
            }
        }
    }

    @ViewBuilder
    private var subSection: some View {
        InspectorSection(title: "SUB") {
            toggleRow("Layer enabled", .subEnabled)
            if zone.flag(.subEnabled) {
                instrumentRow("Instrument", .subInstrument)
                levelRow("Level", .subLevel)
                pickerRow("Type", .layerType, TD17LayerCatalog.types)
                stepperRow("Fade point", .fadePoint, MIDIManager.fadePointEditRange)

                if !zone.subVEditStyle.group.isEmpty {
                    Divider().padding(.vertical, 2)
                    Text("SUB V-EDIT · \(zone.subVEditStyle.group)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    vEditRows(
                        zone.subVEditStyle,
                        primary: .subVEditPrimary,
                        secondary: .subVEditSecondary,
                        tertiary: .subVEditTertiary
                    )
                }
            }
        }
    }

    private var sendsSection: some View {
        InspectorSection(title: "SENDS") {
            levelRow("Ambience", .ambienceSend, MIDIManager.sendLevelRange)
            levelRow("MFX", .mfxSend, MIDIManager.sendLevelRange)
            levelRow("Reverb", .reverbSend, MIDIManager.sendLevelRange)
        }
    }

    @ViewBuilder
    private var eqSection: some View {
        InspectorSection(title: "PAD EQ") {
            toggleRow("Equaliser", .eqEnabled)
            if zone.flag(.eqEnabled) {
                pickerRow("Low freq", .eqLowFrequency, TD17EQCatalog.lowFrequencies)
                stepperRow("Low gain", .eqLowGain, MIDIManager.eqGainRange)
                pickerRow("Mid freq", .eqMidFrequency, TD17EQCatalog.midFrequencies)
                pickerRow("Mid Q", .eqMidQ, TD17EQCatalog.qValues)
                stepperRow("Mid gain", .eqMidGain, MIDIManager.eqGainRange)
                pickerRow("High freq", .eqHighFrequency, TD17EQCatalog.highFrequencies)
                stepperRow("High gain", .eqHighGain, MIDIManager.eqGainRange)
            }
        }
    }

    /// Nut MIDI jest 24, a stref 20 — hi-hat i werbel mają po kilka. Tablica
    /// przypisań siedzi w `TD17NoteMap`.
    @ViewBuilder
    private var midiSection: some View {
        let indices = TD17NoteMap.noteIndices(forZone: zone.index)
            .filter { editor.hasNote($0) }
        if !indices.isEmpty {
            InspectorSection(title: "MIDI NOTES") {
                ForEach(indices, id: \.self) { index in
                    InspectorRow(
                        title: TD17MIDINoteCatalog.names.indices.contains(index)
                            ? TD17MIDINoteCatalog.names[index]
                            : "NOTE \(index + 1)",
                        changed: editor.isChangedNote(index)
                    ) {
                        Stepper(value: editor.noteBinding(index), in: 0...128) {
                            Text(TD17MIDINoteCatalog.text(editor.note(index)))
                                .font(.caption.monospacedDigit())
                        }
                        .fixedSize()
                    }
                }
            }
        }
    }

    // MARK: Wiersze

    @ViewBuilder
    private func vEditRows(
        _ style: TD17VEditStyle,
        primary: ZoneField,
        secondary: ZoneField,
        tertiary: ZoneField
    ) -> some View {
        InspectorRow(title: style.primaryLabel, changed: zone.isChanged(primary)) {
            HStack(spacing: 6) {
                ValueHint(
                    style.primaryText(zone.value(primary)),
                    zone.value(primary)
                )
                NumberField(
                    value: editor.binding(primary, zone: zone.index),
                    range: style.primaryRange
                )
            }
        }

        // Wartość spoza wyliczonego zakresu **musi** iść w gałąź „unknown".
        // `Picker` bez pasującego znacznika przestawia się sam na pierwszy
        // z listy i zapisuje zmianę, której nikt nie zrobił — dokładnie ten
        // sam mechanizm, który wcześniej psuł poziom reverbu.
        InspectorRow(title: style.secondaryLabel, changed: zone.isChanged(secondary)) {
            if style.secondaryNames.isEmpty {
                NumberField(
                    value: editor.binding(secondary, zone: zone.index),
                    range: style.secondaryRange
                )
            } else if style.secondaryRange.contains(zone.value(secondary)) {
                Picker("", selection: editor.binding(secondary, zone: zone.index)) {
                    ForEach(Array(style.secondaryRange), id: \.self) { value in
                        Text(style.secondaryText(value)).tag(value)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 132)
            } else {
                unknownValue(zone.value(secondary))
            }
        }

        if style.hasTertiary {
            InspectorRow(title: style.tertiaryLabel, changed: zone.isChanged(tertiary)) {
                if style.tertiaryRange.contains(zone.value(tertiary)) {
                    Picker("", selection: editor.binding(tertiary, zone: zone.index)) {
                        ForEach(Array(style.tertiaryRange), id: \.self) { value in
                            Text(style.tertiaryText(value)).tag(value)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 132)
                } else {
                    unknownValue(zone.value(tertiary))
                }
            }
        }
    }

    /// Wartość, której nie ma w katalogu — pokazujemy liczbę zamiast
    /// podstawiać cokolwiek pod spód.
    private func unknownValue(_ value: Int) -> some View {
        Text("unknown (\(value))")
            .font(.caption.monospaced())
            .foregroundStyle(.orange)
    }

    private func instrumentRow(_ title: String, _ field: ZoneField) -> some View {
        InspectorRow(title: title, changed: zone.isChanged(field)) {
            TD17InstrumentPicker(
                selection: editor.binding(field, zone: zone.index),
                width: 176
            )
        }
    }

    private func levelRow(
        _ title: String,
        _ field: ZoneField,
        _ range: ClosedRange<Int> = MIDIManager.levelRange
    ) -> some View {
        // Wartość do wpisania w decybelach plus strzałki co 0.1 dB. Suwak
        // zniknął, bo zjadał pół szerokości wiersza — do zamaszystych ruchów
        // jest mikser pod sceną.
        InspectorRow(title: title, changed: zone.isChanged(field)) {
            LevelField(
                tenths: editor.binding(field, zone: zone.index),
                range: range
            )
        }
    }

    private func stepperRow(
        _ title: String,
        _ field: ZoneField,
        _ range: ClosedRange<Int>
    ) -> some View {
        InspectorRow(title: title, changed: zone.isChanged(field)) {
            HStack(spacing: 6) {
                // Podpis tylko wtedy, gdy mówi coś ponad samą liczbę —
                // „CENTER", „+3 dB". Inaczej ta sama wartość stałaby dwa razy
                // obok siebie.
                ValueHint(field.formatted(zone.value(field)), zone.value(field))
                NumberField(
                    value: editor.binding(field, zone: zone.index),
                    range: range
                )
            }
        }
    }

    private func toggleRow(_ title: String, _ field: ZoneField) -> some View {
        InspectorRow(title: title, changed: zone.isChanged(field)) {
            Toggle("", isOn: Binding(
                get: { zone.flag(field) },
                set: { editor.set(field, zone: zone.index, to: $0 ? 1 : 0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }

    @ViewBuilder
    private func pickerRow(
        _ title: String,
        _ field: ZoneField,
        _ catalog: [String]
    ) -> some View {
        InspectorRow(title: title, changed: zone.isChanged(field)) {
            if catalog.indices.contains(zone.value(field)) {
                Picker("", selection: editor.binding(field, zone: zone.index)) {
                    ForEach(catalog.indices, id: \.self) { index in
                        Text(catalog[index]).tag(index)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 132)
            } else {
                Text("unknown (\(zone.value(field)))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Strony ustawień kitu

/// Jeden wiersz na dowolny parametr kitu — kontrolka bierze się z `kind`,
/// więc dołożenie parametru nie wymaga dokładania widoku.
private struct KitFieldRow: View {
    @ObservedObject var editor: KitEditor
    let field: KitField

    init(_ field: KitField, _ editor: KitEditor) {
        self.field = field
        self.editor = editor
    }

    var body: some View {
        InspectorRow(title: field.label, changed: editor.isChanged(field)) {
            switch field.kind {
            case .toggle:
                Toggle("", isOn: Binding(
                    get: { editor.flag(field) },
                    set: { editor.set(field, to: $0 ? 1 : 0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)

            case .picker(let names):
                if names.indices.contains(editor.value(field)) {
                    Picker("", selection: editor.binding(field)) {
                        ForEach(names.indices, id: \.self) { index in
                            Text(names[index]).tag(index)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 168)
                } else {
                    Text("unknown (\(editor.value(field)))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.orange)
                }

            case .level(let range):
                LevelField(tenths: editor.binding(field), range: range)

            case .stepper(let range):
                HStack(spacing: 6) {
                    ValueHint(field.formatted(editor.value(field)), editor.value(field))
                    NumberField(value: editor.binding(field), range: range)
                }
            }
        }
    }
}

/// Wspólna oprawa stron: przewijana kolumna sekcji o rozsądnej szerokości.
private struct KitPage<Content: View>: View {
    let title: String
    @ObservedObject var editor: KitEditor
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                content()
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(14)
        }
        .disabled(editor.isSending)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: Efekty

private struct EffectsPage: View {
    @ObservedObject var editor: KitEditor

    var body: some View {
        KitPage(title: "Effects", editor: editor) {
            if editor.hasAmbience { ambience }
            if editor.hasReverb { reverb }
            if editor.hasMFX { mfx }
            if editor.hasMasterComp { comp }
            if !editor.hasAmbience && !editor.hasReverb
                && !editor.hasMFX && !editor.hasMasterComp {
                Text("Read the full kit to see the effect blocks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var ambience: some View {
        InspectorSection(title: "AMBIENCE") {
            KitFieldRow(.ambienceEnabled, editor)
            if editor.flag(.ambienceEnabled) {
                KitFieldRow(.ambienceLevel, editor)
                KitFieldRow(.ambienceRoomType, editor)
                KitFieldRow(.ambienceRoomSize, editor)
                KitFieldRow(.ambienceRoomShape, editor)
                KitFieldRow(.ambienceWallType, editor)
                KitFieldRow(.ambienceMicPosition, editor)
            }
        }
    }

    @ViewBuilder
    private var reverb: some View {
        InspectorSection(title: "REVERB") {
            KitFieldRow(.reverbEnabled, editor)
            if editor.flag(.reverbEnabled) {
                KitFieldRow(.reverbType, editor)
                KitFieldRow(.reverbLevel, editor)
                ForEach(TD17ReverbCatalog.parameterNames.indices, id: \.self) { index in
                    KitFieldRow(.reverbParameter(index), editor)
                }
            }
        }
    }

    @ViewBuilder
    private var mfx: some View {
        InspectorSection(title: "MFX") {
            KitFieldRow(.mfxEnabled, editor)
            if editor.flag(.mfxEnabled) {
                KitFieldRow(.mfxType, editor)
                KitFieldRow(.mfxLevel, editor)
                // 32 parametry MFX to ściana liczb, których znaczenie zależy
                // od typu efektu — domyślnie zwinięte.
                DisclosureGroup(isExpanded: $editor.showMFXParameters) {
                    if editor.showMFXParameters {
                        ForEach(0..<32, id: \.self) { index in
                            KitFieldRow(.mfxParameter(index), editor)
                        }
                    }
                } label: {
                    Text("Parameters P01–P32")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var comp: some View {
        InspectorSection(title: "MASTER COMP") {
            KitFieldRow(.masterCompEnabled, editor)
            if editor.flag(.masterCompEnabled) {
                KitFieldRow(.masterCompType, editor)
                ForEach(TD17MasterCompCatalog.parameterNames.indices, id: \.self) { index in
                    KitFieldRow(.masterCompParameter(index), editor)
                }
            }
        }
    }
}

// MARK: Nuty MIDI

private struct MIDIPage: View {
    @ObservedObject var editor: KitEditor

    var body: some View {
        KitPage(title: "MIDI notes", editor: editor) {
            InspectorSection(title: "NOTE ASSIGNMENTS") {
                ForEach(0..<TD17MIDINoteCatalog.names.count, id: \.self) { index in
                    if editor.hasNote(index) {
                        InspectorRow(
                            title: TD17MIDINoteCatalog.names[index],
                            changed: editor.isChangedNote(index)
                        ) {
                            HStack(spacing: 6) {
                                ValueHint(
                                    TD17MIDINoteCatalog.text(editor.note(index)),
                                    editor.note(index)
                                )
                                NumberField(
                                    value: editor.noteBinding(index),
                                    range: 0...128
                                )
                            }
                        }
                    }
                }
            }
            Text("128 means OFF.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: Ustawienia ogólne

private struct GeneralPage: View {
    @ObservedObject var editor: KitEditor

    var body: some View {
        KitPage(title: "General", editor: editor) {
            InspectorSection(title: "KIT") {
                KitFieldRow(.volume, editor)
                KitFieldRow(.pedalHiHatVolume, editor)
                KitFieldRow(.crossStickEnabled, editor)
                KitFieldRow(.crossStickVolume, editor)
                KitFieldRow(.hiHatBalance, editor)
            }
            Text("The kit name and description are in the panel on the left.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pole liczbowe

/// Liczba do wpisania z klawiatury, ze strzałkami obok.
///
/// Wcześniej każdy parametr miał sam stepper na stałej szerokości: żeby
/// zmienić strojenie o czterdzieści jednostek, trzeba było czterdzieści razy
/// kliknąć. Tutaj wartość można po prostu wpisać, a wpisana z palca poza
/// zakresem jest przycinana — moduł i tak by jej nie przyjął.
struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat = 68

    var body: some View {
        HStack(spacing: 2) {
            TextField(
                "",
                value: Binding(
                    get: { value },
                    set: { value = min(range.upperBound, max(range.lowerBound, $0)) }
                ),
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption.monospacedDigit())
            .multilineTextAlignment(.trailing)
            .frame(width: width)

            Stepper("", value: $value, in: range)
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// Podpis obok pola liczbowego — pokazywany tylko wtedy, gdy niesie coś
/// więcej niż sama liczba („CENTER", „+3 dB", „16.0\"").
struct ValueHint: View {
    let text: String
    let value: Int

    init(_ text: String, _ value: Int) {
        self.text = text
        self.value = value
    }

    var body: some View {
        if text != String(value) {
            Text(text)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// Poziom w decybelach: pole do wpisania plus strzałki co 0.1 dB.
///
/// Model trzyma poziomy w dziesiątych częściach decybela, więc wpisane
/// „-3.5" ląduje jako -35. Dolny kraniec zakresu to cisza — obok pola stoi
/// wtedy „-INF", bo w liczbie nie da się tego zapisać.
struct LevelField: View {
    @Binding var tenths: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 6) {
            if tenths <= -601 {
                Text("-INF")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            TextField(
                "",
                value: Binding(
                    get: { Double(tenths) / 10 },
                    set: {
                        // Przycinamy jeszcze w liczbach zmiennoprzecinkowych.
                        // `Int(Double)` jest inicjalizatorem pułapkującym:
                        // dwadzieścia dziewiątek wpisanych w to pole dają
                        // wartość spoza zakresu `Int` i program ginie na
                        // miejscu. Pola inspektora są aktywne także w trakcie
                        // serii wysyłki, więc taki zgon potrafił przeciąć
                        // zapis w połowie.
                        guard $0.isFinite else { return }
                        let value = ($0 * 10).rounded()
                        if value <= Double(range.lowerBound) {
                            tenths = range.lowerBound
                        } else if value >= Double(range.upperBound) {
                            tenths = range.upperBound
                        } else {
                            tenths = Int(value)
                        }
                    }
                ),
                format: .number.precision(.fractionLength(1))
            )
            .textFieldStyle(.roundedBorder)
            .font(.caption.monospacedDigit())
            .multilineTextAlignment(.trailing)
            .frame(width: 62)

            Stepper("", value: $tenths, in: range)
                .labelsHidden()
                .fixedSize()
        }
    }
}

extension Color {
    /// Akcent interfejsu. Jedno miejsce, żeby zmiana koloru nie oznaczała
    /// przechodzenia przez wszystkie widoki.
    static let pulsoAccent = Color(red: 0.76, green: 0.25, blue: 0.36)
}
