import Combine
import SwiftUI

/// Pojedynczy parametr strefy, który da się edytować i wysłać do modułu.
///
/// Wszystko trzymamy jako `Int` — także przełączniki (0/1) i poziomy
/// (dziesiąte części dB). Jednorodny typ pozwala prowadzić listę zmian,
/// cofanie i wysyłkę jedną ścieżką zamiast dwudziestu wariantów.
enum ZoneField: String, CaseIterable, Identifiable, Hashable {
    case mainInstrument, mainLevel
    case subEnabled, subInstrument, subLevel, layerType, fadePoint
    case pan
    case ambienceSend, mfxSend, reverbSend
    case eqEnabled, eqLowGain, eqMidGain, eqHighGain
    case eqLowFrequency, eqMidFrequency, eqMidQ, eqHighFrequency
    case vEditPrimary, vEditSecondary, vEditTertiary
    case subVEditPrimary, subVEditSecondary, subVEditTertiary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mainInstrument: "Instrument"
        case .mainLevel: "Level"
        case .subEnabled: "SUB layer"
        case .subInstrument: "SUB instrument"
        case .subLevel: "SUB level"
        case .layerType: "Layer type"
        case .fadePoint: "Fade point"
        case .pan: "Pan"
        case .ambienceSend: "Ambience send"
        case .mfxSend: "MFX send"
        case .reverbSend: "Reverb send"
        case .eqEnabled: "Pad EQ"
        case .eqLowGain: "EQ low gain"
        case .eqMidGain: "EQ mid gain"
        case .eqHighGain: "EQ high gain"
        case .eqLowFrequency: "EQ low freq"
        case .eqMidFrequency: "EQ mid freq"
        case .eqMidQ: "EQ mid Q"
        case .eqHighFrequency: "EQ high freq"
        case .vEditPrimary: "V-Edit 1"
        case .vEditSecondary: "V-Edit 2"
        case .vEditTertiary: "V-Edit 3"
        case .subVEditPrimary: "SUB V-Edit 1"
        case .subVEditSecondary: "SUB V-Edit 2"
        case .subVEditTertiary: "SUB V-Edit 3"
        }
    }

    /// Kolejność wysyłki. Warstwa SUB musi zostać włączona zanim wyślemy jej
    /// instrument i poziom, bo inaczej moduł nie ma czego potwierdzić.
    var sendPriority: Int {
        switch self {
        case .subEnabled, .layerType, .fadePoint: 0
        case .mainInstrument, .subInstrument: 1
        default: 2
        }
    }

    /// Trzy pola jadą jednym zapisem `writeLayerSettings`, więc wysyłamy je
    /// razem i tylko raz.
    var isLayerSetting: Bool {
        self == .subEnabled || self == .layerType || self == .fadePoint
    }

    func formatted(_ value: Int) -> String {
        switch self {
        case .mainInstrument, .subInstrument:
            return TD17InstrumentIndex.label(for: value)
        case .mainLevel, .subLevel, .ambienceSend, .mfxSend, .reverbSend:
            return value <= -601
                ? "-INF"
                : String(format: "%+.1f dB", Double(value) / 10)
        case .subEnabled, .eqEnabled:
            return value != 0 ? "ON" : "OFF"
        case .pan:
            if value == 0 { return "CENTER" }
            return value < 0 ? "L\(-value)" : "R\(value)"
        case .layerType:
            return TD17LayerCatalog.types.indices.contains(value)
                ? TD17LayerCatalog.types[value]
                : "\(value)"
        case .eqLowGain, .eqMidGain, .eqHighGain:
            return String(format: "%+d dB", value)
        case .eqLowFrequency:
            return catalogText(TD17EQCatalog.lowFrequencies, value)
        case .eqMidFrequency:
            return catalogText(TD17EQCatalog.midFrequencies, value)
        case .eqMidQ:
            return catalogText(TD17EQCatalog.qValues, value)
        case .eqHighFrequency:
            return catalogText(TD17EQCatalog.highFrequencies, value)
        default:
            return "\(value)"
        }
    }

    private func catalogText(_ catalog: [String], _ value: Int) -> String {
        catalog.indices.contains(value) ? catalog[value] : "\(value)"
    }
}

// MARK: - Parametry całego kitu

/// Parametr wspólny dla całego kitu: głośność, hi-hat, ambience, reverb,
/// MFX i kompresor główny.
///
/// Te ustawienia miały wcześniej własną zakładkę z przyciskiem „Zapisz" przy
/// każdym polu. Po przeniesieniu do inspektora jadą tą samą drogą co parametry
/// stref — na listę zmian, pod Undo i pod jeden przycisk wysyłki.
enum KitField: Hashable, Identifiable {
    case volume
    case pedalHiHatVolume, crossStickVolume, crossStickEnabled, hiHatBalance

    case ambienceEnabled, ambienceLevel
    case ambienceRoomType, ambienceRoomSize, ambienceRoomShape
    case ambienceWallType, ambienceMicPosition

    case reverbEnabled, reverbType, reverbLevel
    case reverbParameter(Int)

    case mfxEnabled, mfxType, mfxLevel
    case mfxParameter(Int)

    case masterCompEnabled, masterCompType
    case masterCompParameter(Int)

    var id: String {
        switch self {
        case .volume: "volume"
        case .pedalHiHatVolume: "pedalHH"
        case .crossStickVolume: "xstickLevel"
        case .crossStickEnabled: "xstickOn"
        case .hiHatBalance: "hhBalance"
        case .ambienceEnabled: "ambOn"
        case .ambienceLevel: "ambLevel"
        case .ambienceRoomType: "ambRoomType"
        case .ambienceRoomSize: "ambRoomSize"
        case .ambienceRoomShape: "ambRoomShape"
        case .ambienceWallType: "ambWallType"
        case .ambienceMicPosition: "ambMic"
        case .reverbEnabled: "revOn"
        case .reverbType: "revType"
        case .reverbLevel: "revLevel"
        case .reverbParameter(let index): "revP\(index)"
        case .mfxEnabled: "mfxOn"
        case .mfxType: "mfxType"
        case .mfxLevel: "mfxLevel"
        case .mfxParameter(let index): "mfxP\(index)"
        case .masterCompEnabled: "compOn"
        case .masterCompType: "compType"
        case .masterCompParameter(let index): "compP\(index)"
        }
    }

    var label: String {
        switch self {
        case .volume: "Kit volume"
        case .pedalHiHatVolume: "Pedal HH level"
        case .crossStickVolume: "Cross stick level"
        case .crossStickEnabled: "Cross stick"
        case .hiHatBalance: "HH balance"
        case .ambienceEnabled: "Ambience"
        case .ambienceLevel: "Ambience level"
        case .ambienceRoomType: "Room type"
        case .ambienceRoomSize: "Room size"
        case .ambienceRoomShape: "Room shape"
        case .ambienceWallType: "Wall type"
        case .ambienceMicPosition: "Mic position"
        case .reverbEnabled: "Reverb"
        case .reverbType: "Reverb type"
        case .reverbLevel: "Reverb level"
        case .reverbParameter(let index):
            TD17ReverbCatalog.parameterNames.indices.contains(index)
                ? TD17ReverbCatalog.parameterNames[index]
                : "Reverb P\(index + 1)"
        case .mfxEnabled: "MFX"
        case .mfxType: "MFX type"
        case .mfxLevel: "MFX level"
        case .mfxParameter(let index): String(format: "MFX P%02d", index + 1)
        case .masterCompEnabled: "Master comp"
        case .masterCompType: "Comp type"
        case .masterCompParameter(let index):
            TD17MasterCompCatalog.parameterNames.indices.contains(index)
                ? TD17MasterCompCatalog.parameterNames[index]
                : "Comp P\(index + 1)"
        }
    }

    /// Jak pole ma wyglądać w inspektorze.
    var kind: KitFieldKind {
        switch self {
        case .crossStickEnabled, .ambienceEnabled, .reverbEnabled,
             .mfxEnabled, .masterCompEnabled:
            .toggle
        case .volume:
            .level(-600...60)
        case .pedalHiHatVolume, .crossStickVolume:
            .level(MIDIManager.levelRange)
        case .ambienceLevel, .reverbLevel, .mfxLevel:
            .level(MIDIManager.effectLevelRange)
        case .hiHatBalance:
            .stepper(MIDIManager.hiHatBalanceRange)
        case .ambienceRoomType:
            .picker(TD17AmbienceCatalog.roomTypes)
        case .ambienceRoomSize:
            .picker(TD17AmbienceCatalog.roomSizes)
        case .ambienceRoomShape:
            .stepper(0...100)
        case .ambienceWallType:
            .picker(TD17AmbienceCatalog.wallTypes)
        case .ambienceMicPosition:
            .picker(TD17AmbienceCatalog.micPositions)
        case .reverbType:
            .picker(TD17ReverbCatalog.types)
        case .reverbParameter:
            .stepper(0...127)
        case .mfxType:
            .picker(TD17MFXCatalog.types)
        case .mfxParameter:
            .stepper(-32768...32767)
        case .masterCompType:
            .picker(TD17MasterCompCatalog.types)
        case .masterCompParameter(let index):
            if index == 0 {
                .stepper(0...65535)
            } else if (1...4).contains(index) {
                .stepper(-128...127)
            } else {
                .stepper(0...127)
            }
        }
    }

    func formatted(_ value: Int) -> String {
        switch kind {
        case .toggle:
            return value != 0 ? "ON" : "OFF"
        case .level:
            return value <= -601
                ? "-INF"
                : String(format: "%+.1f dB", Double(value) / 10)
        case .picker(let names):
            return names.indices.contains(value) ? names[value] : "\(value)"
        case .stepper:
            // Kompresor główny trzyma częstotliwość podziału w dziesiątkach
            // herców, a wzmocnienia w połówkach decybela — tak samo jak
            // opisy w logu i w podglądzie kitu.
            if case .masterCompParameter(let index) = self {
                if index == 0 {
                    return value == 0 ? "SINGLE" : "\(value * 10) Hz"
                }
                if index == 1 || index == 2 {
                    return String(format: "%+.1f dB", Double(value) / 2)
                }
            }
            return "\(value)"
        }
    }

    /// Włączniki i typy efektów idą przed parametrami, żeby moduł nie dostawał
    /// ustawień bloku, którego jeszcze nie włączył.
    var sendPriority: Int {
        switch self {
        case .ambienceEnabled, .reverbEnabled, .mfxEnabled, .masterCompEnabled,
             .reverbType, .mfxType, .masterCompType:
            3
        default:
            4
        }
    }
}

/// Sposób prezentacji parametru kitu w inspektorze.
enum KitFieldKind {
    case toggle
    case picker([String])
    case level(ClosedRange<Int>)
    case stepper(ClosedRange<Int>)
}

/// Tekstowe pola kitu. Osobno, bo jako jedyne nie są liczbami.
enum KitTextField: String, Hashable, Identifiable, CaseIterable {
    case name, subName

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: "Kit name"
        case .subName: "Kit description"
        }
    }

    /// Limit modułu, liczony w bajtach ASCII.
    var limit: Int {
        switch self {
        case .name: 12
        case .subName: 16
        }
    }

    /// Indeks przyjmowany przez `writeKitText`.
    var writeIndex: Int {
        switch self {
        case .name: 0
        case .subName: 1
        }
    }
}

// MARK: - Adres zmiany

/// Co dokładnie zostało zmienione.
///
/// Jeden typ dla stref, ustawień całego kitu, nazw i przypisań nut pozwala
/// prowadzić **jedną** listę zmian, jedno cofanie i jedną wysyłkę. Wcześniej
/// każda z tych grup miała własną zakładkę i własny przycisk zapisu, co przy
/// jednym ekranie edycji dawałoby cztery sprzeczne zachowania.
enum EditTarget: Hashable, Identifiable {
    case zone(Int, ZoneField)
    case kit(KitField)
    case text(KitTextField)
    case note(Int)

    var id: String {
        switch self {
        case .zone(let index, let field): "zone.\(index).\(field.rawValue)"
        case .kit(let field): "kit.\(field.id)"
        case .text(let field): "text.\(field.rawValue)"
        case .note(let index): "note.\(index)"
        }
    }

    /// Nagłówek pozycji na liście zmian.
    var groupName: String {
        switch self {
        case .zone(let index, _):
            TD17ZoneCatalog.names.indices.contains(index)
                ? TD17ZoneCatalog.names[index]
                : "ZONE \(index + 1)"
        case .kit, .text:
            "KIT"
        case .note(let index):
            TD17MIDINoteCatalog.names.indices.contains(index)
                ? "MIDI · \(TD17MIDINoteCatalog.names[index])"
                : "MIDI · NOTE \(index + 1)"
        }
    }

    var fieldLabel: String {
        switch self {
        case .zone(_, let field): field.label
        case .kit(let field): field.label
        case .text(let field): field.label
        case .note: "MIDI note"
        }
    }

    func formatted(_ value: KitValue) -> String {
        switch self {
        case .zone(_, let field): field.formatted(value.number)
        case .kit(let field): field.formatted(value.number)
        case .text: value.text.isEmpty ? "—" : value.text
        case .note: TD17MIDINoteCatalog.text(value.number)
        }
    }

    var sendPriority: Int {
        switch self {
        case .zone(_, let field): field.sendPriority
        case .kit(let field): field.sendPriority
        case .text: 5
        case .note: 6
        }
    }

    /// Numer strefy — używany tylko do porządkowania wysyłki.
    var zoneIndex: Int {
        switch self {
        case .zone(let index, _): index
        case .note(let index): index
        default: 0
        }
    }
}

/// Strony edytora — dokładnie ten sam podział co na ekranie pliku TD0.
///
/// Zestaw to scena z padami, reszta to ustawienia całego kitu. Inspektor
/// wybranej strefy stoi po prawej niezależnie od strony.
enum EditorPage: String, CaseIterable, Identifiable {
    case kit, effects, midi, general

    var id: String { rawValue }

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

/// Wartość parametru. Prawie wszystko jest liczbą; nazwa i opis kitu nie.
enum KitValue: Equatable {
    case number(Int)
    case text(String)

    var number: Int {
        if case .number(let value) = self { return value }
        return 0
    }

    var text: String {
        if case .text(let value) = self { return value }
        return ""
    }
}

/// Jedna pozycja na liście „do wysłania".
struct KitChange: Identifiable, Equatable {
    let target: EditTarget
    let from: KitValue
    var to: KitValue

    var id: String { target.id }
    var groupName: String { target.groupName }
    var fieldLabel: String { target.fieldLabel }
    var fromText: String { target.formatted(from) }
    var toText: String { target.formatted(to) }
}

// MARK: - Stan strefy

/// Stan jednej strefy.
///
/// Osobny obiekt na strefę to nie kosmetyka. Wcześniej wszystkie wartości
/// robocze siedziały w kilkudziesięciu słownikach na jednym `MIDIManager`,
/// więc ruszenie dowolnego suwaka unieważniało **cały** interfejs — stąd
/// zacinanie się przy przełączaniu zakładek. Teraz widok strefy odświeża
/// się wtedy i tylko wtedy, gdy zmienia się ta strefa.
@MainActor
final class ZoneEditor: ObservableObject, Identifiable {
    let index: Int
    nonisolated var id: Int { index }

    var name: String {
        TD17ZoneCatalog.names.indices.contains(index)
            ? TD17ZoneCatalog.names[index]
            : "ZONE \(index + 1)"
    }

    /// Rodzina instrumentu z bloku V-Edit. Decyduje o tym, co znaczą trzy
    /// parametry V-Edit — dla werbla strojenie, dla talerza rozmiar.
    private(set) var vEditStyle = TD17VEditStyle(group: "")
    private(set) var subVEditStyle = TD17VEditStyle(group: "")

    /// Wartości odczytane z modułu.
    private(set) var committed: [ZoneField: Int] = [:]

    /// Wyłącznie te pola, które użytkownik zmienił.
    @Published private(set) var edited: [ZoneField: Int] = [:]

    init(index: Int) { self.index = index }

    func value(_ field: ZoneField) -> Int {
        edited[field] ?? committed[field] ?? 0
    }

    func flag(_ field: ZoneField) -> Bool { value(field) != 0 }

    func isChanged(_ field: ZoneField) -> Bool { edited[field] != nil }

    var hasChanges: Bool { !edited.isEmpty }

    func commit(_ values: [ZoneField: Int], vEdit: String, subVEdit: String) {
        committed = values
        edited = [:]
        vEditStyle = TD17VEditStyle(group: vEdit)
        subVEditStyle = TD17VEditStyle(group: subVEdit)
    }

    /// Zwraca `true`, jeśli po tej operacji pole faktycznie różni się od
    /// modułu. Powrót do wartości wyjściowej kasuje wpis, żeby lista zmian
    /// nie pokazywała „z -2.5 na -2.5".
    @discardableResult
    func apply(_ field: ZoneField, _ newValue: Int) -> Bool {
        if newValue == committed[field] ?? 0 {
            edited.removeValue(forKey: field)
            return false
        }
        edited[field] = newValue
        return true
    }

    func revert(_ field: ZoneField) {
        edited.removeValue(forKey: field)
    }

    func commitField(_ field: ZoneField, _ value: Int) {
        committed[field] = value
        edited.removeValue(forKey: field)
    }
}

// MARK: - Edytor

/// Warstwa edycji nad `MIDIManager`.
///
/// Zmiany nie idą do modułu od razu — zbierają się na liście, którą można
/// przejrzeć, cofnąć albo wysłać w całości. Wysyłka używa istniejących metod
/// `write*`, każda z własną weryfikacją, bo ta ścieżka jest sprawdzona na
/// sprzęcie. Zapis blokowy zostaje osobną operacją do kopiowania kitów.
@MainActor
final class KitEditor: ObservableObject {
    @Published private(set) var zones: [ZoneEditor] =
        (0..<20).map { ZoneEditor(index: $0) }

    /// Kolejność wpisów odpowiada kolejności edycji. Kolejne zmiany tego
    /// samego pola nadpisują wpis — inaczej przeciągnięcie suwaka zostawiałoby
    /// setki pozycji i cofanie cofałoby o jedną dziesiątą decybela.
    @Published private(set) var changes: [KitChange] = []
    @Published private(set) var redoable: [KitChange] = []

    @Published private(set) var isSending = false
    @Published private(set) var sendProgress: String?
    @Published private(set) var sendFailure: String?
    @Published private(set) var hasCapturedKit = false

    /// Zmiany wysłane **na próbę**: siedzą już w module, ale nie zostały
    /// uznane za zapisane, więc da się je jednym ruchem wycofać.
    ///
    /// Program nie ma czym zagrać sam — próbki są w pamięci TD-17. Żeby
    /// usłyszeć zmianę przed jej zatwierdzeniem, trzeba ją do modułu wysłać.
    /// Cała sztuka polega na tym, żeby dało się wrócić.
    @Published private(set) var previewed: [KitChange] = []

    var canPreview: Bool { !changes.isEmpty && !isSending && !hasPreview }
    var hasPreview: Bool { !previewed.isEmpty }

    /// Ostrzeżenie, gdy próba obejmuje coś, czego nie da się cofnąć w całości.
    @Published private(set) var previewNotice: String?

    /// Komunikat po przepisaniu stanu z modułu — pokazywany tylko wtedy, gdy
    /// odczyt skasował coś, czego użytkownik nie zdążył wysłać.
    @Published private(set) var captureNotice: String?

    /// Wybrana strefa siedzi w modelu, a nie w widoku, bo dzielą ją trzy
    /// widoki naraz: scena, mikser pod nią i inspektor.
    @Published var selectedZone = 1

    /// Otwarta strona edytora.
    @Published var page: EditorPage = .kit

    /// Czy lista 32 parametrów MFX jest rozwinięta. W modelu, a nie w widoku,
    /// bo strona efektów powstaje od nowa przy każdym wejściu na nią.
    @Published var showMFXParameters = false

    // Ustawienia całego kitu — ten sam podział na „odczytane z modułu"
    // i „zmienione przez użytkownika", co w strefach.
    private var kitCommitted: [KitField: Int] = [:]
    @Published private(set) var kitEdited: [KitField: Int] = [:]
    private var textCommitted: [KitTextField: String] = [:]
    @Published private(set) var textEdited: [KitTextField: String] = [:]
    private var noteCommitted: [Int: Int] = [:]
    @Published private(set) var noteEdited: [Int: Int] = [:]

    /// Czy moduł w ogóle przysłał bloki efektów — bez tego nie ma czego
    /// pokazywać ani wysyłać.
    @Published private(set) var hasAmbience = false
    @Published private(set) var hasReverb = false
    @Published private(set) var hasMFX = false
    @Published private(set) var hasMasterComp = false

    /// Zapamiętany poziom sprzed wyciszenia — tylko po to, żeby odciszenie
    /// wracało tam, skąd wyszło.
    private var levelBeforeMute: [Int: Int] = [:]

    /// Wyciszenie nie jest osobnym stanem, tylko odczytem z poziomu.
    ///
    /// TD-17 nie ma osobnego wyciszenia pada — jedyne, co da się wysłać, to
    /// poziom -INF. Trzymanie obok tego własnego zbioru „wyciszonych" musiało
    /// się rozjechać przy cofaniu: poziom wracał, a pad zostawał przekreślony.
    /// Wyprowadzenie tego wprost z poziomu likwiduje całą klasę błędu —
    /// przycisk świeci dokładnie wtedy, gdy pad milczy.
    func isMuted(_ index: Int) -> Bool {
        (zone(index)?.value(.mainLevel) ?? 0) <= -601
    }

    func toggleMute(zone index: Int) {
        guard let editor = zone(index), !isSending else { return }

        if isMuted(index) {
            // Bez zapamiętanej wartości wracamy na 0 dB, żeby odciszenie
            // zawsze coś dawało.
            let restored = levelBeforeMute.removeValue(forKey: index) ?? 0
            set(.mainLevel, zone: index, to: max(-600, restored))
        } else {
            levelBeforeMute[index] = editor.value(.mainLevel)
            set(.mainLevel, zone: index, to: -601)
        }
    }

    private var sendTask: Task<Void, Never>?

    var canSend: Bool { !changes.isEmpty && !isSending }
    var canUndo: Bool { !changes.isEmpty && !isSending }
    var canRedo: Bool { !redoable.isEmpty && !isSending }

    func zone(_ index: Int) -> ZoneEditor? {
        zones.indices.contains(index) ? zones[index] : nil
    }

    // MARK: - Edycja stref

    func set(_ field: ZoneField, zone index: Int, to newValue: Int) {
        guard let editor = zone(index), !isSending else { return }

        // Ręczne podniesienie poziomu unieważnia zapamiętaną wartość
        // sprzed wyciszenia.
        if field == .mainLevel, newValue > -601 {
            levelBeforeMute.removeValue(forKey: index)
        }

        let base = editor.committed[field] ?? 0
        let stillChanged = editor.apply(field, newValue)
        record(
            .zone(index, field),
            from: .number(base),
            to: .number(newValue),
            changed: stillChanged
        )
    }

    func binding(_ field: ZoneField, zone index: Int) -> Binding<Int> {
        Binding(
            get: { [weak self] in self?.zone(index)?.value(field) ?? 0 },
            set: { [weak self] in self?.set(field, zone: index, to: $0) }
        )
    }

    // MARK: - Edycja ustawień kitu

    func value(_ field: KitField) -> Int {
        kitEdited[field] ?? kitCommitted[field] ?? 0
    }

    func flag(_ field: KitField) -> Bool { value(field) != 0 }

    func isChanged(_ field: KitField) -> Bool { kitEdited[field] != nil }

    func set(_ field: KitField, to newValue: Int) {
        guard !isSending else { return }
        let base = kitCommitted[field] ?? 0

        if newValue == base {
            kitEdited.removeValue(forKey: field)
        } else {
            kitEdited[field] = newValue
        }
        record(
            .kit(field),
            from: .number(base),
            to: .number(newValue),
            changed: newValue != base
        )
    }

    func binding(_ field: KitField) -> Binding<Int> {
        Binding(
            get: { [weak self] in self?.value(field) ?? 0 },
            set: { [weak self] in self?.set(field, to: $0) }
        )
    }

    // MARK: - Edycja nazw

    func text(_ field: KitTextField) -> String {
        textEdited[field] ?? textCommitted[field] ?? ""
    }

    /// Liczy się to, co pójdzie do modułu, a nie zawartość pola. Sama spacja
    /// dopisana na końcu nazwy nic nie zmienia, bo moduł i tak ją utnie.
    func isChanged(_ field: KitTextField) -> Bool {
        changes.contains { $0.target == .text(field) }
    }

    /// Wartość, którą ma moduł — niezależnie od tego, co stoi w polu.
    func committedText(_ field: KitTextField) -> String {
        textCommitted[field] ?? ""
    }

    /// Pusta nazwa kitu: pole da się wyczyścić, ale moduł jej nie przyjmie.
    var kitNameIsEmpty: Bool {
        text(.name).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Moduł przyjmuje wyłącznie ASCII i ma twardy limit długości, więc
    /// obcinamy tu, a nie dopiero przy wysyłce — inaczej zmiana trafiłaby
    /// na listę i zostałaby odrzucona bez wyjaśnienia.
    func setText(_ field: KitTextField, to newValue: String) {
        guard !isSending else { return }

        let filtered = String(
            newValue.unicodeScalars.filter { $0.isASCII && $0.value >= 32 }
        )
        let clipped = String(filtered.prefix(field.limit))
        let base = textCommitted[field] ?? ""

        // W polu zostaje to, co wpisano — inaczej nie dałoby się postawić
        // spacji w środku nazwy. Ale do modułu (i na listę zmian) idzie
        // wersja przycięta, bo `writeKitText` wysyła i weryfikuje właśnie ją.
        let normalized = clipped.trimmingCharacters(in: .whitespacesAndNewlines)

        if clipped == base {
            textEdited.removeValue(forKey: field)
        } else {
            textEdited[field] = clipped
        }

        // Moduł odrzuca pustą nazwę kitu bez podnoszenia `isWriting`, więc
        // taka pozycja na liście zerwałaby całą wysyłkę i wszystko po niej
        // zostałoby niewysłane. Nie wpuszczamy jej na listę.
        //
        // Puste pole zostaje puste — inaczej nie dałoby się skasować nazwy
        // i wpisać nowej. Że nic z tego nie pójdzie do modułu, widać
        // w inspektorze (ostrzeżenie przy polu) i po nazwie w nagłówku,
        // która pokazuje stan modułu.
        guard !(field == .name && normalized.isEmpty) else {
            changes.removeAll { $0.target == .text(field) }
            redoable = []
            return
        }

        record(
            .text(field),
            from: .text(base),
            to: .text(normalized),
            changed: normalized != base
        )
    }

    func textBinding(_ field: KitTextField) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.text(field) ?? "" },
            set: { [weak self] in self?.setText(field, to: $0) }
        )
    }

    // MARK: - Edycja nut MIDI

    func note(_ index: Int) -> Int {
        noteEdited[index] ?? noteCommitted[index] ?? 0
    }

    func hasNote(_ index: Int) -> Bool { noteCommitted[index] != nil }

    func isChangedNote(_ index: Int) -> Bool { noteEdited[index] != nil }

    func setNote(_ index: Int, to newValue: Int) {
        guard !isSending, noteCommitted[index] != nil else { return }
        let base = noteCommitted[index] ?? 0

        if newValue == base {
            noteEdited.removeValue(forKey: index)
        } else {
            noteEdited[index] = newValue
        }
        record(
            .note(index),
            from: .number(base),
            to: .number(newValue),
            changed: newValue != base
        )
    }

    func noteBinding(_ index: Int) -> Binding<Int> {
        Binding(
            get: { [weak self] in self?.note(index) ?? 0 },
            set: { [weak self] in self?.setNote(index, to: $0) }
        )
    }

    // MARK: - Lista zmian

    /// Wspólne dopisanie pozycji do listy. `changed == false` znaczy, że
    /// wartość wróciła do stanu z modułu i pozycja ma zniknąć.
    private func record(
        _ target: EditTarget,
        from: KitValue,
        to: KitValue,
        changed: Bool
    ) {
        changes.removeAll { $0.target == target }
        if changed {
            changes.append(KitChange(target: target, from: from, to: to))
        }
        redoable = []
    }

    func revert(_ change: KitChange) {
        guard !isSending else { return }
        undoValue(change.target)
        changes.removeAll { $0.id == change.id }
        redoable.append(change)
    }

    func revertAll() {
        guard !isSending else { return }
        for change in changes {
            undoValue(change.target)
        }
        redoable = changes.reversed()
        changes = []
    }

    func undo() {
        guard canUndo, let last = changes.last else { return }
        undoValue(last.target)
        changes.removeLast()
        redoable.append(last)
    }

    func redo() {
        guard canRedo, let last = redoable.popLast() else { return }
        redoValue(last.target, last.to)
        changes.append(last)
    }

    /// Kasuje edycję i zostawia wartość odczytaną z modułu.
    private func undoValue(_ target: EditTarget) {
        switch target {
        case .zone(let index, let field):
            zone(index)?.revert(field)
        case .kit(let field):
            kitEdited.removeValue(forKey: field)
        case .text(let field):
            textEdited.removeValue(forKey: field)
        case .note(let index):
            noteEdited.removeValue(forKey: index)
        }
    }

    private func redoValue(_ target: EditTarget, _ value: KitValue) {
        switch target {
        case .zone(let index, let field):
            zone(index)?.apply(field, value.number)
        case .kit(let field):
            kitEdited[field] = value.number
        case .text(let field):
            textEdited[field] = value.text
        case .note(let index):
            noteEdited[index] = value.number
        }
    }

    /// Po potwierdzonym zapisie wartość staje się stanem modułu.
    private func markSent(_ change: KitChange) {
        switch change.target {
        case .zone(let index, let field):
            zone(index)?.commitField(field, change.to.number)
        case .kit(let field):
            kitCommitted[field] = change.to.number
            kitEdited.removeValue(forKey: field)
        case .text(let field):
            textCommitted[field] = change.to.text
            textEdited.removeValue(forKey: field)
        case .note(let index):
            noteCommitted[index] = change.to.number
            noteEdited.removeValue(forKey: index)
        }
        changes.removeAll { $0.id == change.id }
    }

    // MARK: - Przepisanie stanu z modułu

    /// Wywoływane po każdym pełnym odczycie kitu. Kasuje niewysłane zmiany,
    /// bo odnosiły się do poprzedniego stanu modułu.
    func capture(from midi: MIDIManager) {
        let vEditGroups = Dictionary(
            midi.vEdits.map { ($0.zoneIndex, $0.instrumentGroup) },
            uniquingKeysWith: { first, _ in first }
        )
        let subVEditGroups = Dictionary(
            midi.subVEdits.map { ($0.zoneIndex, $0.instrumentGroup) },
            uniquingKeysWith: { first, _ in first }
        )

        for editor in zones {
            let i = editor.index
            var values: [ZoneField: Int] = [:]

            values[.mainInstrument] = midi.mainInstrumentDrafts[i] ?? 0
            values[.subInstrument] = midi.subInstrumentDrafts[i] ?? 0
            values[.mainLevel] = tenths(midi.mainLevelDrafts[i])
            values[.subLevel] = tenths(midi.subLevelDrafts[i])
            values[.subEnabled] = (midi.subEnabledDrafts[i] ?? false) ? 1 : 0
            values[.layerType] = midi.subLayerTypeDrafts[i] ?? 0
            // Bez podnoszenia do 1. Moduł trzyma tu 0 dla warstw MIX
            // i SWITCH, a wymuszanie jedynki robiło z tego zmianę, której
            // nikt nie zrobił — i którą zapis wysyłał przy okazji.
            // Zapis przyjmuje teraz pełny zakres składowania.
            values[.fadePoint] = midi.subFadePointDrafts[i] ?? 50
            values[.pan] = midi.panDrafts[i] ?? 0
            values[.ambienceSend] = midi.ambienceSendDrafts[i] ?? -601
            values[.mfxSend] = midi.mfxSendDrafts[i] ?? -601
            values[.reverbSend] = midi.reverbSendDrafts[i] ?? -601
            values[.eqEnabled] = (midi.eqEnabledDrafts[i] ?? false) ? 1 : 0
            values[.eqLowGain] = midi.eqLowGainDrafts[i] ?? 0
            values[.eqMidGain] = midi.eqMidGainDrafts[i] ?? 0
            values[.eqHighGain] = midi.eqHighGainDrafts[i] ?? 0
            values[.eqLowFrequency] = midi.eqLowFrequencyDrafts[i] ?? 0
            values[.eqMidFrequency] = midi.eqMidFrequencyDrafts[i] ?? 0
            values[.eqMidQ] = midi.eqMidQDrafts[i] ?? 0
            values[.eqHighFrequency] = midi.eqHighFrequencyDrafts[i] ?? 0
            values[.vEditPrimary] = midi.mainTuningDrafts[i] ?? 0
            values[.vEditSecondary] = midi.mainVEditSecondDrafts[i] ?? 0
            values[.vEditTertiary] = midi.mainVEditThirdDrafts[i] ?? 0
            values[.subVEditPrimary] = midi.subTuningDrafts[i] ?? 0
            values[.subVEditSecondary] = midi.subVEditSecondDrafts[i] ?? 0
            values[.subVEditTertiary] = midi.subVEditThirdDrafts[i] ?? 0

            editor.commit(
                values,
                vEdit: vEditGroups[i] ?? "",
                subVEdit: subVEditGroups[i] ?? ""
            )
        }

        captureKit(from: midi)

        // Niewysłane zmiany odnosiły się do poprzedniego stanu modułu, a przy
        // zmianie kitu poszłyby w dodatku do **innego** kitu — `write*` bierze
        // numer kitu dopiero w chwili wysyłki. Kasujemy je, ale mówimy o tym
        // wprost, bo teraz odczyt potrafi ruszyć sam.
        let discarded = changes.count
        // O nieodebranej próbie trzeba powiedzieć osobno i wprost: te wartości
        // **są w module**, tylko program przestaje o nich wiedzieć. Milczenie
        // w tym miejscu zostawiłoby ustawiony kit i przekonanie, że nic się
        // nie stało.
        let stranded = previewed.count
        var parts: [String] = []
        if discarded > 0 {
            parts.append(
                "\(discarded) unsent change\(discarded == 1 ? "" : "s") discarded"
            )
        }
        if stranded > 0 {
            parts.append(
                "\(stranded) previewed change\(stranded == 1 ? "" : "s") left in the module"
            )
        }
        captureNotice = parts.isEmpty
            ? nil
            : "Kit reloaded — " + parts.joined(separator: ", ") + "."

        changes = []
        redoable = []
        previewed = []
        previewNotice = nil
        levelBeforeMute = [:]
        sendFailure = nil
        hasCapturedKit = true
    }

    func dismissCaptureNotice() {
        captureNotice = nil
    }

    private func captureKit(from midi: MIDIManager) {
        var values: [KitField: Int] = [:]

        // `writeKitVolume` i tak ścina do tego zakresu, więc wartość spoza
        // niego oznaczałaby, że wysyłamy co innego, niż potem zapiszemy
        // jako stan modułu.
        values[.volume] = min(60, max(-600, Int((midi.kitVolumeDraft * 10).rounded())))
        values[.pedalHiHatVolume] = midi.pedalHiHatVolumeDraft
        values[.crossStickVolume] = midi.crossStickVolumeDraft
        values[.crossStickEnabled] = midi.crossStickEnabledDraft ? 1 : 0
        values[.hiHatBalance] = midi.hiHatBalanceDraft

        values[.ambienceEnabled] = midi.ambienceEnabledDraft ? 1 : 0
        values[.ambienceLevel] = midi.ambienceLevelDraft
        values[.ambienceRoomType] = midi.ambienceRoomTypeDraft
        values[.ambienceRoomSize] = midi.ambienceRoomSizeDraft
        values[.ambienceRoomShape] = midi.ambienceRoomShapeDraft
        values[.ambienceWallType] = midi.ambienceWallTypeDraft
        values[.ambienceMicPosition] = midi.ambienceMicPositionDraft

        values[.reverbEnabled] = midi.reverbEnabledDraft ? 1 : 0
        values[.reverbType] = midi.reverbTypeDraft
        values[.reverbLevel] = midi.reverbLevelDraft
        for index in TD17ReverbCatalog.parameterNames.indices {
            values[.reverbParameter(index)] = midi.reverbParameterDrafts[index] ?? 0
        }

        values[.mfxEnabled] = midi.mfxEnabledDraft ? 1 : 0
        values[.mfxType] = midi.mfxTypeDraft
        values[.mfxLevel] = midi.mfxLevelDraft
        for index in 0..<32 {
            values[.mfxParameter(index)] = midi.mfxParameterDrafts[index] ?? 0
        }

        values[.masterCompEnabled] = midi.masterCompEnabledDraft ? 1 : 0
        values[.masterCompType] = midi.masterCompTypeDraft
        for index in TD17MasterCompCatalog.parameterNames.indices {
            values[.masterCompParameter(index)] =
                midi.masterCompParameterDrafts[index] ?? 0
        }

        kitCommitted = values
        kitEdited = [:]

        textCommitted = [
            .name: midi.kitNameDraft,
            .subName: midi.kitSubNameDraft
        ]
        textEdited = [:]

        var notes: [Int: Int] = [:]
        for assignment in midi.midiNotes {
            notes[assignment.index] =
                midi.midiNoteDrafts[assignment.index] ?? assignment.note
        }
        noteCommitted = notes
        noteEdited = [:]

        hasAmbience = midi.ambience != nil
        hasReverb = midi.reverb != nil
        hasMFX = midi.mfx != nil
        hasMasterComp = midi.masterComp != nil
    }

    private func tenths(_ decibels: Double?) -> Int {
        guard let decibels else { return -601 }
        let value = Int((decibels * 10).rounded())
        return value <= -601 ? -601 : value
    }

    // MARK: - Wysyłka

    /// Wysyła zmiany na próbę i przesłuchuje strefy, których dotyczą.
    ///
    /// Zmiany zostają na liście — moduł już nimi gra, ale program nadal pamięta
    /// wartości sprzed próby, więc `revertPreview` przywraca stan wyjściowy.
    func preview(using midi: MIDIManager) {
        guard canPreview, !midi.isOperationInProgress else { return }
        let queue = plan()
        guard !queue.isEmpty else { return }

        var auditionZones = Set(queue.flatMap { step in
            step.changes.compactMap { change -> Int? in
                if case .zone(let index, _) = change.target { return index }
                return nil
            }
        }).sorted()

        // Zmiana samego kitu (efekt, głośność) nie wskazuje żadnej strefy —
        // wtedy gramy wybraną, żeby w ogóle było co usłyszeć.
        if auditionZones.isEmpty { auditionZones = [selectedZone] }

        // Zmiana instrumentu kasuje w module V-Edit tego pada i ustawia
        // domyślne dla nowego brzmienia. Powrót wgra stary instrument, ale
        // jego V-Edit będzie już fabryczny, nie Twój.
        previewNotice = changes.contains {
            if case .zone(_, let field) = $0.target {
                return field == .mainInstrument || field == .subInstrument
            }
            return false
        }
            ? "Instrument previews cannot be fully undone — the module resets that pad's V-Edit."
            : nil

        run(queue, using: midi, commit: false) { [weak self] in
            // Odsłuch idzie tą samą drogą co „Play kit": własne zadanie
            // z licznikiem pokoleń, przerywalne przyciskiem Stop. Grany
            // z wnętrza wysyłki byłby nie do zatrzymania, a program przez
            // te kilka sekund udawałby, że nic nie robi.
            guard let self, !self.previewed.isEmpty else { return }
            midi.auditionZones(auditionZones)
        }
    }

    /// Przywraca w module wartości sprzed odsłuchu, zostawiając zmiany
    /// na liście do dalszej pracy.
    func revertPreview(using midi: MIDIManager) {
        // `isBusyWithSysEx` zamiast `isOperationInProgress`: próba kończy się
        // odsłuchem, więc warunek z odsłuchem blokowałby powrót przez cały
        // czas jego trwania.
        guard hasPreview, !isSending, !midi.isBusyWithSysEx else { return }
        // Odsłuch schodzi z drogi — inaczej grałby dalej po wartościach,
        // których już nie ma w module.
        midi.cancelAudition()
        let restore = previewed

        // `push` wysyła zawsze `change.to`, więc do modułu musi pójść lista
        // **odwrócona** — inaczej „cofnij" wgrałoby jeszcze raz dokładnie te
        // wartości, które właśnie odsłuchiwaliśmy.
        let inverse = restore.map {
            KitChange(target: $0.target, from: $0.to, to: $0.from)
        }

        // Model wraca do wartości sprzed próby: dzięki temu wymuszona
        // synchronizacja trzech draftów warstwy w `push` też poda stan sprzed.
        for change in restore { undoValue(change.target) }
        let queue = plan(for: inverse, reversed: true)

        run(queue, using: midi, commit: false, restoring: true) { [weak self] in
            guard let self else { return }
            // Edycje wracają na swoje miejsce — ale te **aktualne**, a nie
            // zapamiętane przy odsłuchu: w międzyczasie mogły się zmienić
            // albo zostać cofnięte.
            for change in restore {
                guard let current = self.changes.first(where: { $0.id == change.id })
                else { continue }
                self.redoValue(current.target, current.to)
            }
            // Przerwany powrót zostawia resztę próby w module, więc
            // ostrzeżenie o instrumencie nadal jest aktualne.
            if self.previewed.isEmpty { self.previewNotice = nil }
        }
    }

    /// Zatwierdza to, co gra po odsłuchu.
    func keepPreview() {
        guard !isSending else { return }
        for change in previewed {
            // Zatwierdzamy **zawsze**: `previewed` opisuje to, co naprawdę
            // siedzi teraz w module. Pominięcie którejkolwiek pozycji zostawia
            // program z fałszywym obrazem sprzętu i bez czegokolwiek, czym
            // dałoby się to naprawić.
            let current = changes.first(where: { $0.id == change.id })
            markSent(change)

            // Jeśli po odsłuchu poprawiłeś wartość, nowsza edycja wraca na
            // listę — ale liczona już od tego, co gra w module, a nie od
            // stanu sprzed próby.
            if let current, current.to != change.to {
                changes.append(
                    KitChange(target: current.target, from: change.to, to: current.to)
                )
                redoValue(current.target, current.to)
            }
        }
        previewed = []
        previewNotice = nil
        // Stos „ponów" pamięta stan sprzed zatwierdzenia. Po nim wskazywałby
        // na wartości, które są już zapisane, i „ponów" dopisywałby do listy
        // zmianę z tą samą wartością po obu stronach.
        redoable = []
    }

    func send(using midi: MIDIManager) {
        guard canSend, !hasPreview, !midi.isOperationInProgress else { return }

        // Ustawienia warstwy jadą jednym zapisem, więc trzy pola liczą się
        // jako jedna pozycja do wysłania.
        let queue = plan()
        guard !queue.isEmpty else { return }

        run(queue, using: midi, commit: true)
    }

    /// Wspólna pętla wysyłki.
    ///
    /// `commit == true` znaczy „to jest zapis" — potwierdzona zmiana znika
    /// z listy. `commit == false` to próba: zmiana zostaje na liście, a jej
    /// wcześniejsza wartość jest nadal znana, więc da się wrócić.
    private func run(
        _ queue: [SendStep],
        using midi: MIDIManager,
        commit: Bool,
        restoring: Bool = false,
        then finish: (@MainActor () async -> Void)? = nil
    ) {
        isSending = true
        sendFailure = nil
        // Moduł musi wiedzieć, że seria trwa. Między krokami `isWriting`
        // opada i wszystko, co pyta „czy coś trwa", widziało bezczynność —
        // wystarczyło, żeby odroczony odczyt kitu albo zmiana kitu z nagłówka
        // weszły w środek wysyłki i zerwały resztę serii.
        midi.beginEditorSend()
        sendTask = Task { @MainActor [weak self] in
            guard let self else {
                midi.endEditorSend()
                return
            }
            var done = 0

            for step in queue {
                guard !Task.isCancelled else { break }
                self.sendProgress = "\(done + 1) of \(queue.count)"

                self.push(step, to: midi)
                step.write(midi)

                // `write*` podnosi `isWriting` od razu albo nie wysyła nic —
                // więc tu już wiadomo, czy bajty poszły na kabel.
                if !commit, !restoring, midi.isWriting, midi.lastSendReachedTheWire {
                    // Od tej chwili krok jest **do cofnięcia**, niezależnie od
                    // tego, czy moduł go potwierdzi. Brak potwierdzenia nie
                    // znaczy „nie doszło" — mogła zginąć sama odpowiedź. Lepiej
                    // mieć przycisk powrotu na coś, co nie dotarło (powrót
                    // wgra tę samą wartość, która i tak tam siedzi), niż nie
                    // mieć go na coś, co dotarło i zostaje w module na zawsze.
                    // Ale gdy `sendSysEx` w ogóle nie zszedł na kabel (termin
                    // ważności, brak wyjścia), do modułu nie poszło nic i nie
                    // ma czego cofać ani zatwierdzać.
                    for change in step.changes
                    where !self.previewed.contains(where: { $0.id == change.id }) {
                        self.previewed.append(change)
                    }
                }

                guard await self.waitForWrite(midi) else {
                    let left = queue.count - done
                    self.sendFailure = Task.isCancelled
                        ? "Send stopped — \(left) change(s) left unsent."
                        : "Module did not confirm \(step.describe()). "
                            + "\(left) change(s) left unsent."
                    break
                }

                for change in step.changes {
                    if commit {
                        self.markSent(change)
                    } else if restoring {
                        // Z listy próby schodzi tylko to, czego powrót moduł
                        // **potwierdził**. Przerwany powrót zostawia resztę,
                        // więc przycisk „cofnij" nadal jest po co nacisnąć.
                        self.previewed.removeAll { $0.id == change.id }
                    }
                }
                done += 1
            }

            // Ostrzeżenie o instrumencie nie ma po co wisieć, jeśli próba
            // w ogóle nie ruszyła — nie ma czego cofać.
            if !commit, !restoring, self.previewed.isEmpty {
                self.previewNotice = nil
            }

            self.sendProgress = nil
            self.isSending = false
            self.redoable = []
            midi.endEditorSend()
            await finish?()
        }
    }

    func cancelSend() {
        sendTask?.cancel()
        sendTask = nil
    }

    /// Czeka na zakończenie weryfikacji zapisu.
    ///
    /// Najpierw upewnia się, że zapis **w ogóle wystartował**. Metody
    /// `write*` mają na wejściu warunki wstępne i przy niespełnionym
    /// którymkolwiek po cichu wracają, nie ustawiając `isWriting`. Bez tej
    /// kontroli pętla widziała „nie pisze" już przy pierwszym sprawdzeniu
    /// i meldowała sukces zapisu, którego nigdy nie wysłano — a zmiana
    /// znikała z listy jako potwierdzona.
    ///
    /// Weryfikacja zaczyna się po 180 ms, więc `isWriting` jest podniesione
    /// znacznie dłużej niż okres próbkowania.
    private func waitForWrite(_ midi: MIDIManager) async -> Bool {
        var generation: Int?
        for _ in 0..<12 {
            if midi.isWriting {
                generation = midi.writeGeneration
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return false }
        }
        if generation == nil, midi.isWriting {
            generation = midi.writeGeneration
        }
        guard let generation else { return false }

        // `MIDIManager` ma własny watchdog na 8 s, więc pętla się kończy.
        //
        // Sam koniec zapisu to za mało: moduł mógł odesłać inną wartość niż
        // wysłana (np. ściąć ją do swojego zakresu). Wtedy `isWriting` opada
        // dokładnie tak samo, a zmiana **nie** została zapisana.
        //
        // Do tego numer pokolenia: gdyby między opadnięciem `isWriting`
        // a naszym sprawdzeniem wcisnął się inny zapis, przeczytalibyśmy
        // **jego** werdykt. Pokolenie rośnie przy każdym przełączeniu flagi,
        // więc nasz zapis kończy się dokładnie na `generation + 1`.
        for _ in 0..<240 {
            try? await Task.sleep(for: .milliseconds(50))
            if Task.isCancelled { return false }
            if !midi.isWriting {
                return midi.lastWriteConfirmed
                    && midi.writeGeneration == generation + 1
            }
        }
        return false
    }

    private func push(_ step: SendStep, to midi: MIDIManager) {
        // Zapis ustawień warstwy wysyła wszystkie trzy pola naraz i sprawdza
        // je razem, więc muszą być spójne — nawet te, których użytkownik nie
        // ruszał.
        if step.changes.contains(where: {
            if case .zone(_, let field) = $0.target { return field.isLayerSetting }
            return false
        }), let editor = zone(step.zoneIndex) {
            let i = step.zoneIndex
            // Wartość bierzemy z **kroku**, a dopiero w drugiej kolejności ze
            // stanu modułu. Nigdy z bieżącej edycji: przy powrocie z próby
            // krok niesie tylko te pola, które w tej próbie poszły, a wszystko
            // inne, co użytkownik zdążył w międzyczasie ruszyć, pojechałoby do
            // modułu przy okazji — nigdy nie zapisane w programie i nie do
            // odkręcenia, bo program by o tym nie wiedział.
            func layerValue(_ field: ZoneField) -> Int {
                if let change = step.changes.first(
                    where: { $0.target == EditTarget.zone(i, field) }
                ) {
                    return change.to.number
                }
                return editor.committed[field] ?? 0
            }
            midi.subEnabledDrafts[i] = layerValue(.subEnabled) != 0
            midi.subLayerTypeDrafts[i] = layerValue(.layerType)
            midi.subFadePointDrafts[i] = layerValue(.fadePoint)
        }

        for change in step.changes {
            switch change.target {
            case .zone(let index, let field):
                KitEditor.pushZone(field, index, change.to.number, midi)
            case .kit(let field):
                KitEditor.pushKit(field, change.to.number, midi)
            case .text(let field):
                switch field {
                case .name: midi.kitNameDraft = change.to.text
                case .subName: midi.kitSubNameDraft = change.to.text
                }
            case .note(let index):
                midi.midiNoteDrafts[index] = change.to.number
            }
        }
    }

    private static func pushZone(
        _ field: ZoneField,
        _ i: Int,
        _ value: Int,
        _ midi: MIDIManager
    ) {
        switch field {
        case .mainInstrument: midi.mainInstrumentDrafts[i] = value
        case .subInstrument: midi.subInstrumentDrafts[i] = value
        case .mainLevel: midi.mainLevelDrafts[i] = Double(value) / 10
        case .subLevel: midi.subLevelDrafts[i] = Double(value) / 10
        case .subEnabled: midi.subEnabledDrafts[i] = value != 0
        case .layerType: midi.subLayerTypeDrafts[i] = value
        case .fadePoint: midi.subFadePointDrafts[i] = value
        case .pan: midi.panDrafts[i] = value
        case .ambienceSend: midi.ambienceSendDrafts[i] = value
        case .mfxSend: midi.mfxSendDrafts[i] = value
        case .reverbSend: midi.reverbSendDrafts[i] = value
        case .eqEnabled: midi.eqEnabledDrafts[i] = value != 0
        case .eqLowGain: midi.eqLowGainDrafts[i] = value
        case .eqMidGain: midi.eqMidGainDrafts[i] = value
        case .eqHighGain: midi.eqHighGainDrafts[i] = value
        case .eqLowFrequency: midi.eqLowFrequencyDrafts[i] = value
        case .eqMidFrequency: midi.eqMidFrequencyDrafts[i] = value
        case .eqMidQ: midi.eqMidQDrafts[i] = value
        case .eqHighFrequency: midi.eqHighFrequencyDrafts[i] = value
        case .vEditPrimary: midi.mainTuningDrafts[i] = value
        case .vEditSecondary: midi.mainVEditSecondDrafts[i] = value
        case .vEditTertiary: midi.mainVEditThirdDrafts[i] = value
        case .subVEditPrimary: midi.subTuningDrafts[i] = value
        case .subVEditSecondary: midi.subVEditSecondDrafts[i] = value
        case .subVEditTertiary: midi.subVEditThirdDrafts[i] = value
        }
    }

    private static func pushKit(
        _ field: KitField,
        _ value: Int,
        _ midi: MIDIManager
    ) {
        switch field {
        case .volume: midi.kitVolumeDraft = Double(value) / 10
        case .pedalHiHatVolume: midi.pedalHiHatVolumeDraft = value
        case .crossStickVolume: midi.crossStickVolumeDraft = value
        case .crossStickEnabled: midi.crossStickEnabledDraft = value != 0
        case .hiHatBalance: midi.hiHatBalanceDraft = value
        case .ambienceEnabled: midi.ambienceEnabledDraft = value != 0
        case .ambienceLevel: midi.ambienceLevelDraft = value
        case .ambienceRoomType: midi.ambienceRoomTypeDraft = value
        case .ambienceRoomSize: midi.ambienceRoomSizeDraft = value
        case .ambienceRoomShape: midi.ambienceRoomShapeDraft = value
        case .ambienceWallType: midi.ambienceWallTypeDraft = value
        case .ambienceMicPosition: midi.ambienceMicPositionDraft = value
        case .reverbEnabled: midi.reverbEnabledDraft = value != 0
        case .reverbType: midi.reverbTypeDraft = value
        case .reverbLevel: midi.reverbLevelDraft = value
        case .reverbParameter(let index): midi.reverbParameterDrafts[index] = value
        case .mfxEnabled: midi.mfxEnabledDraft = value != 0
        case .mfxType: midi.mfxTypeDraft = value
        case .mfxLevel: midi.mfxLevelDraft = value
        case .mfxParameter(let index): midi.mfxParameterDrafts[index] = value
        case .masterCompEnabled: midi.masterCompEnabledDraft = value != 0
        case .masterCompType: midi.masterCompTypeDraft = value
        case .masterCompParameter(let index):
            midi.masterCompParameterDrafts[index] = value
        }
    }

    /// Grupuje zmiany w kroki wysyłki i porządkuje je tak, żeby zależności
    /// szły przed tym, co od nich zależy.
    private func plan() -> [SendStep] { plan(for: changes) }

    /// `reversed` znaczy „to jest powrót z próby".
    ///
    /// Priorytety opisują dwie różne rzeczy i tylko jedna z nich jest
    /// lustrzana. Warunek wstępny: warstwę SUB trzeba **włączyć**, zanim
    /// pojedzie jej instrument i głośność — przy powrocie, który warstwę
    /// gasi, gaszenie musi więc trafić na koniec, inaczej reszta jedzie do
    /// martwej warstwy. Reszta priorytetów to „zapis rodzica kasuje dzieci":
    /// instrument ustawia padowi fabryczny V-Edit, typ efektu zeruje jego
    /// parametry. Ta zależność działa tak samo w obie strony i odwrócona
    /// kasowałaby dopiero co przywrócone wartości.
    private func plan(
        for source: [KitChange],
        reversed: Bool = false
    ) -> [SendStep] {
        var steps: [SendStep] = []
        var layerZones: Set<Int> = []

        for change in source {
            if case .zone(let index, let field) = change.target,
               field.isLayerSetting {
                layerZones.insert(index)
            }
        }

        for zoneIndex in layerZones.sorted() {
            let grouped = source.filter { change in
                if case .zone(let index, let field) = change.target {
                    return index == zoneIndex && field.isLayerSetting
                }
                return false
            }
            // Warstwa SUB musi być włączona, gdy wchodzi do niej instrument
            // i głośność. Przy powrocie z próby, który warstwę **gasi**,
            // znaczy to, że gaszenie idzie na koniec — a nie na początek,
            // bo wtedy reszta pojechałaby do martwej warstwy. Powrót, który
            // warstwę zapala, ma tę samą kolejność co zwykła wysyłka.
            let endsDisabled = grouped.contains { change in
                if case .zone(_, .subEnabled) = change.target {
                    return change.to.number == 0
                }
                return false
            }
            steps.append(
                SendStep(
                    changes: grouped,
                    zoneIndex: zoneIndex,
                    priority: (reversed && endsDisabled) ? Int.max : 0,
                    sequence: steps.count
                ) { midi in
                    midi.writeLayerSettings(zoneIndex: zoneIndex)
                }
            )
        }

        for change in source {
            if case .zone(_, let field) = change.target, field.isLayerSetting {
                continue
            }
            let target = change.target
            steps.append(
                SendStep(
                    changes: [change],
                    zoneIndex: target.zoneIndex,
                    priority: target.sendPriority,
                    sequence: steps.count
                ) { midi in
                    KitEditor.invokeWriter(target, midi)
                }
            )
        }

        // `sorted` nie jest stabilne, a wszystkie ustawienia kitu mają ten sam
        // priorytet i ten sam „numer strefy" — bez trzeciego klucza kolejność
        // wysyłki (i podgląd „N z M") potrafiłaby się różnić od kolejności,
        // w jakiej powstawały zmiany.
        // Reszta priorytetów zostaje bez zmian również przy powrocie. Opisują
        // one nie warunek wstępny, tylko „zapis rodzica kasuje dzieci":
        // wgranie instrumentu ustawia padowi fabryczny V-Edit, a zmiana typu
        // efektu zeruje jego parametry. Ta zależność nie jest lustrzana —
        // odwrócona kasowałaby dopiero co przywrócone wartości.
        return steps.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            if lhs.zoneIndex != rhs.zoneIndex { return lhs.zoneIndex < rhs.zoneIndex }
            return lhs.sequence < rhs.sequence
        }
    }

    private static func invokeWriter(_ target: EditTarget, _ midi: MIDIManager) {
        switch target {
        case .zone(let index, let field):
            invokeZoneWriter(field, index, midi)
        case .kit(let field):
            invokeKitWriter(field, midi)
        case .text(let field):
            midi.writeKitText(field.writeIndex)
        case .note(let index):
            midi.writeMIDINote(index: index)
        }
    }

    private static func invokeZoneWriter(
        _ field: ZoneField,
        _ i: Int,
        _ midi: MIDIManager
    ) {
        switch field {
        case .mainInstrument:
            midi.writeInstrument(zoneIndex: i, isSub: false)
        case .subInstrument:
            midi.writeInstrument(zoneIndex: i, isSub: true)
        case .mainLevel:
            midi.writeZoneLevel(zoneIndex: i, isSub: false)
        case .subLevel:
            midi.writeZoneLevel(zoneIndex: i, isSub: true)
        case .pan:
            midi.writePan(zoneIndex: i)
        case .ambienceSend:
            midi.writeAmbienceSend(zoneIndex: i)
        case .mfxSend:
            midi.writeMFXSend(zoneIndex: i)
        case .reverbSend:
            midi.writeReverbSend(zoneIndex: i)
        case .eqEnabled:
            midi.writeEQEnabled(zoneIndex: i)
        case .eqLowGain:
            midi.writeEQGain(zoneIndex: i, bandIndex: 0)
        case .eqMidGain:
            midi.writeEQGain(zoneIndex: i, bandIndex: 1)
        case .eqHighGain:
            midi.writeEQGain(zoneIndex: i, bandIndex: 2)
        case .eqLowFrequency:
            midi.writeEQShape(zoneIndex: i, parameterIndex: 0)
        case .eqMidFrequency:
            midi.writeEQShape(zoneIndex: i, parameterIndex: 1)
        case .eqMidQ:
            midi.writeEQShape(zoneIndex: i, parameterIndex: 2)
        case .eqHighFrequency:
            midi.writeEQShape(zoneIndex: i, parameterIndex: 3)
        case .vEditPrimary:
            midi.writeVEditTuning(zoneIndex: i, isSub: false)
        case .subVEditPrimary:
            midi.writeVEditTuning(zoneIndex: i, isSub: true)
        case .vEditSecondary:
            midi.writeVEditParameter(zoneIndex: i, parameter: 2, isSub: false)
        case .vEditTertiary:
            midi.writeVEditParameter(zoneIndex: i, parameter: 3, isSub: false)
        case .subVEditSecondary:
            midi.writeVEditParameter(zoneIndex: i, parameter: 2, isSub: true)
        case .subVEditTertiary:
            midi.writeVEditParameter(zoneIndex: i, parameter: 3, isSub: true)
        case .subEnabled, .layerType, .fadePoint:
            midi.writeLayerSettings(zoneIndex: i)
        }
    }

    private static func invokeKitWriter(_ field: KitField, _ midi: MIDIManager) {
        switch field {
        case .volume:
            midi.writeKitVolume()
        case .pedalHiHatVolume:
            midi.writeKitCommonParameter(0)
        case .crossStickVolume:
            midi.writeKitCommonParameter(1)
        case .crossStickEnabled:
            midi.writeKitCommonParameter(2)
        case .hiHatBalance:
            midi.writeKitCommonParameter(3)
        case .ambienceEnabled:
            midi.writeAmbienceEnabled()
        case .ambienceLevel:
            midi.writeAmbienceLevel()
        case .ambienceRoomType:
            midi.writeAmbienceParameter(0)
        case .ambienceRoomSize:
            midi.writeAmbienceParameter(1)
        case .ambienceRoomShape:
            midi.writeAmbienceParameter(2)
        case .ambienceWallType:
            midi.writeAmbienceParameter(3)
        case .ambienceMicPosition:
            midi.writeAmbienceParameter(4)
        case .reverbEnabled:
            midi.writeReverb(0)
        case .reverbType:
            midi.writeReverb(1)
        case .reverbParameter(let index):
            midi.writeReverb(index + 2)
        case .reverbLevel:
            midi.writeReverb(10)
        case .mfxEnabled:
            midi.writeMFX(0)
        case .mfxType:
            midi.writeMFX(1)
        case .mfxLevel:
            midi.writeMFX(2)
        case .mfxParameter(let index):
            midi.writeMFX(index + 3)
        case .masterCompEnabled:
            midi.writeMasterComp(0)
        case .masterCompType:
            midi.writeMasterComp(1)
        case .masterCompParameter(let index):
            midi.writeMasterComp(index + 2)
        }
    }
}

/// Jeden krok wysyłki: jedna komenda do modułu i zmiany, które ona pokrywa.
private struct SendStep {
    let changes: [KitChange]
    let zoneIndex: Int
    let priority: Int
    /// Kolejność powstania kroku — ostatni klucz sortowania.
    let sequence: Int
    let write: (MIDIManager) -> Void

    func describe() -> String {
        guard let first = changes.first else { return "change" }
        return "\(first.groupName) · \(first.fieldLabel)"
    }
}
