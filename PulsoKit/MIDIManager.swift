import AppKit
import Combine
import CoreMIDI
import Foundation
import UniformTypeIdentifiers

typealias MIDIEndpointID = MIDIUniqueID

struct MIDIEndpointInfo: Identifiable, Hashable {
    let id: MIDIEndpointID
    let name: String
    fileprivate let reference: MIDIEndpointRef

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct TD17InstrumentInfo {
    let instrumentID: Int
    let levelTenthsDB: Int
    let isUserSample: Bool

    var levelText: String {
        levelTenthsDB == -601
            ? "-INF dB"
            : String(format: "%+.1f dB", Double(levelTenthsDB) / 10.0)
    }

    var displayName: String {
        if isUserSample {
            return String(format: "User Sample U%03d", instrumentID + 1)
        }
        return TD17InstrumentCatalog.instrument(for: instrumentID)?.name
            ?? "Unknown instrument"
    }

    var groupName: String {
        if isUserSample { return "USER SAMPLE" }
        return TD17InstrumentCatalog.instrument(for: instrumentID)?.group
            ?? "UNKNOWN"
    }

    var description: String {
        "\(displayName) (#\(instrumentID)), \(levelText), \(isUserSample ? "USER" : "PRESET")"
    }
}

struct TD17ZoneInfo: Identifiable {
    let index: Int
    let name: String
    let instrument: TD17InstrumentInfo

    var id: Int { index }
}

struct TD17LayerInfo: Identifiable {
    let zoneIndex: Int
    let zoneName: String
    let enabled: Bool
    let layerType: String
    let fadePoint: Int
    let instrument: TD17InstrumentInfo

    var id: Int { zoneIndex }

    var description: String {
        guard enabled else { return "\(zoneName): SUB disabled" }
        return "\(zoneName): \(instrument.displayName) (#\(instrument.instrumentID)), "
            + "\(instrument.levelText), \(layerType), Fade Point \(fadePoint)"
    }
}

struct TD17VEditInfo: Identifiable {
    let zoneIndex: Int
    let zoneName: String
    let instrumentGroup: String
    let primaryValue: Int
    let secondaryValue: Int
    let tertiaryValue: Int
    let values: [String]

    var id: Int { zoneIndex }
    var description: String { "\(zoneName): \(values.joined(separator: ", "))" }
    var supportsTuning: Bool {
        ["KICK", "SNARE", "CROSS STICK", "TOM"].contains(instrumentGroup)
    }
    var isCymbal: Bool {
        ["HI-HAT", "RIDE", "CRASH", "SPLASH/CHINA"].contains(instrumentGroup)
    }
}

enum TD17EQCatalog {
    static let lowFrequencies = [
        "20Hz", "25Hz", "31.5Hz", "40Hz", "50Hz", "63Hz",
        "80Hz", "100Hz", "125Hz", "160Hz", "200Hz", "250Hz",
        "315Hz", "400Hz", "500Hz", "630Hz", "800Hz", "1kHz"
    ]
    static let midFrequencies = lowFrequencies + [
        "1.25kHz", "1.6kHz", "2kHz", "2.5kHz", "3.15kHz", "4kHz",
        "5kHz", "6.3kHz", "8kHz", "10kHz", "12.5kHz", "16kHz"
    ]
    static let highFrequencies = [
        "1kHz", "1.25kHz", "1.6kHz", "2kHz", "2.5kHz", "3.15kHz",
        "4kHz", "5kHz", "6.3kHz", "8kHz", "10kHz", "12.5kHz", "16kHz"
    ]
    static let qValues = ["0.5", "1.0", "2.0", "4.0", "8.0"]
}

enum TD17AmbienceCatalog {
    static let roomTypes = [
        "BEACH", "LIVING ROOM", "BATH ROOM", "STUDIO", "GARAGE",
        "LOCKER ROOM", "THEATER", "CAVE", "GYMNASIUM", "DOME STADIUM",
        "BOOTH A", "BOOTH B", "STUDIO A", "STUDIO B", "BASEMENT",
        "JAZZ CLUB", "ROCK CLUB", "BALLROOM", "GATE", "CONCERT HALL",
        "SPORTS ARENA", "EXPO HALL", "BOTTLE", "CITY", "SPIRAL"
    ]
    static let roomSizes = ["TINY", "SMALL", "MEDIUM", "LARGE", "HUGE"]
    static let wallTypes = [
        "CURTAIN", "CLOTH", "WOOD", "PLASTER", "CONCRETE", "GLASS"
    ]
    static let micPositions = [
        "NEXT DOOR", "LOW FLOOR", "LOW", "MID LOW", "MID",
        "MID HIGH", "HIGH", "CEILING A", "CEILING B"
    ]
}

/// Ustawienia jednego wejścia triggera.
///
/// Odczytane ze sprzętu i potwierdzone porównaniem z ekranem modułu:
/// czułość i retrig cancel są **liczone od zera**, wzmocnienie obręczy jest
/// razy dziesięć, a czas skanowania w dziesiątych milisekundy.
struct TD17TriggerInfo: Identifiable {
    let input: Int
    let padTypeCode: Int
    let sensitivity: Int
    let rimGainTenths: Int
    let threshold: Int
    let retrigCancel: Int
    /// Odczytane, ale jeszcze nie pokazywane — w testowym module wszędzie 0.
    let extNoiseCancel: Int
    let headRimAdjust: Int
    let scanTimeTenths: Int
    let maskTimeMs: Int
    let curve: Int
    let crosstalkCancel: Int?

    var id: Int { input }

    var name: String {
        TD17TriggerCatalog.inputNames.indices.contains(input - 1)
            ? TD17TriggerCatalog.inputNames[input - 1]
            : "INPUT \(input)"
    }

    var padTypeName: String { TD17TriggerCatalog.padTypeName(padTypeCode) }
    var curveName: String { TD17TriggerCatalog.curveName(curve) }
    var rimGainText: String {
        String(format: "%.1f", Double(rimGainTenths) / 10)
    }
    var scanTimeText: String {
        String(format: "%.1f ms", Double(scanTimeTenths) / 10)
    }
}

/// Ustawienia wspólne dla wszystkich wejść.
struct TD17TriggerCommonInfo {
    let crossStickAdjust: Int
    let crosstalk: [Int]
    /// Dwa pierwsze bajty bloku, których znaczenia jeszcze nie znamy —
    /// trzymane po to, żeby dało się je porównać po zmianie w module.
    let rawHead: [UInt8]
}

enum TD17TriggerCatalog {
    /// Kolejność wejść na TD-17, potwierdzona zrzutem ze sprzętu.
    static let inputNames = [
        "KICK", "SNARE", "TOM 1", "TOM 2", "TOM 3",
        "HI-HAT", "CRASH 1", "CRASH 2", "RIDE", "AUX"
    ]

    /// Kody typów padów rozpoznane na żywym module. Lista jest niepełna —
    /// nieznany kod pokazujemy liczbą, zamiast zgadywać nazwę.
    static let padTypes: [Int: String] = [
        5: "KD (kick)",
        21: "PDX-12",
        22: "PDX-6 / tom",
        30: "CY-14C",
        34: "CY-8",
        35: "CY-5"
    ]

    static func padTypeName(_ code: Int) -> String {
        padTypes[code] ?? "type \(code)"
    }

    /// Kolejność krzywych z panelu modułu. LINEAR = 0 potwierdzone,
    /// reszta wymaga sprawdzenia.
    static let curves = [
        "LINEAR", "EXP1", "EXP2", "LOG1", "LOG2",
        "SPLINE", "LOUD1", "LOUD2"
    ]

    static func curveName(_ index: Int) -> String {
        curves.indices.contains(index) ? curves[index] : "curve \(index)"
    }
}

enum TD17ZoneCatalog {
    /// 20 stref w kolejności bloków KitUnit — wspólne dla ścieżki SysEx,
    /// plików TD0 i wizualizacji zestawu.
    static let names = [
        "KICK HEAD",
        "SNARE HEAD", "SNARE RIM",
        "TOM1 HEAD", "TOM1 RIM",
        "TOM2 HEAD", "TOM2 RIM",
        "TOM3 HEAD", "TOM3 RIM",
        "HI-HAT HEAD", "HI-HAT RIM",
        "CRASH1 HEAD", "CRASH1 RIM",
        "CRASH2 HEAD", "CRASH2 RIM",
        "RIDE HEAD", "RIDE RIM", "RIDE BELL",
        "AUX HEAD", "AUX RIM"
    ]
}

enum TD17ReverbCatalog {
    static let types = ["ROOM1", "ROOM2", "HALL1", "HALL2", "PLATE"]

    /// Nazwy parametrów reverbu w kolejności bloku SysEx (offsety 2…9).
    static let parameterNames = [
        "Pre Delay", "Time", "Density", "Diffusion",
        "LF Damp", "HF Damp", "Spread", "Tone"
    ]
}

enum TD17LayerCatalog {
    static let types = ["MIX", "FADE1", "FADE2", "SWITCH"]
}

enum TD17MIDINoteCatalog {
    /// 24 przypisania nut w kolejności bloku KitMIDI.
    static let names = [
        "KICK", "SNARE HEAD", "SNARE RIM", "SNARE XSTICK",
        "TOM1 HEAD", "TOM1 RIM", "TOM2 HEAD", "TOM2 RIM",
        "TOM3 HEAD", "TOM3 RIM",
        "HI-HAT OPEN BOW", "HI-HAT OPEN EDGE",
        "HI-HAT CLOSED BOW", "HI-HAT CLOSED EDGE", "HI-HAT PEDAL",
        "CRASH1 BOW", "CRASH1 EDGE", "CRASH2 BOW", "CRASH2 EDGE",
        "RIDE BOW", "RIDE EDGE", "RIDE BELL", "AUX HEAD", "AUX RIM"
    ]

    /// 128 oznacza OFF — nie jest to numer nuty.
    static func text(_ note: Int) -> String {
        note == 128 ? "OFF" : "\(note)"
    }
}

enum TD17MFXCatalog {
    static let types = [
        "DELAY", "TAPE ECHO", "REVERSE DELAY", "3TAP PAN DELAY",
        "OD->DELAY", "DS->DELAY", "CHORUS", "SPACE-D", "OD->CHORUS",
        "DS->CHORUS", "PHASER A", "PHASER B", "STEP PHASER", "FLANGER",
        "REVERB", "LONG REVERB", "SUPER FILTER", "FILTER+DRIVE", "AUTO WAH",
        "OD/DS->TWAH", "LOFI COMPRESS", "DISTORTION", "OVERDRIVE",
        "SATURATOR", "T-SCREAM", "BIT CRUSHER", "ISOLATOR", "RING MODULATOR",
        "PITCH SHIFTER", "AUTO PAN", "EQUALIZER", "SPECTRUM", "LOW BOOST",
        "ENHANCER", "HUMANIZER", "SLICER", "STEP FLANGER", "HEXA-CHORUS",
        "4 TAP PAN DELAY", "EH->FLANGER", "SPEAKER SIM"
    ]
}

enum TD17MasterCompCatalog {
    static let types = [
        "SINGLE SOFT COMP", "SINGLE HARD COMP", "SINGLE LIMITER",
        "SINGLE PARALLEL", "2 BAND SOFT COMP", "2 BAND HARD COMP",
        "2 BAND LIMITER", "2 BAND PARALLEL"
    ]
    static let parameterNames = [
        "Split Frequency", "Low Gain", "High Gain",
        "Low Threshold", "High Threshold", "Low Ratio", "High Ratio",
        "Low Knee", "High Knee", "Low Attack", "High Attack",
        "Low Release", "High Release", "Balance"
    ]
}

struct TD17MixInfo: Identifiable {
    let zoneIndex: Int
    let zoneName: String
    let pan: Int
    let eqEnabled: Bool
    let lowFrequency: String
    let lowGain: Int
    let midFrequency: String
    let midQ: String
    let midGain: Int
    let highFrequency: String
    let highGain: Int
    let ambienceSend: Int
    let mfxSend: Int
    let reverbSend: Int

    var id: Int { zoneIndex }

    var description: String {
        let panText = pan == 0 ? "CENTER" : (pan < 0 ? "L\(-pan)" : "R\(pan)")
        let eqText = eqEnabled
            ? "EQ ON [\(lowFrequency) \(gainText(lowGain)), "
                + "\(midFrequency) Q\(midQ) \(gainText(midGain)), "
                + "\(highFrequency) \(gainText(highGain))]"
            : "EQ OFF"
        return "\(zoneName): Pan \(panText), \(eqText), "
            + "Amb \(sendText(ambienceSend)), "
            + "MFX \(sendText(mfxSend)), Rev \(sendText(reverbSend))"
    }

    private func gainText(_ value: Int) -> String {
        value > 0 ? "+\(value) dB" : "\(value) dB"
    }

    private func sendText(_ value: Int) -> String {
        if value == -601 { return "-INF" }
        return String(format: "%+.1f dB", Double(value) / 10.0)
    }
}

struct TD17AmbienceInfo {
    let enabled: Bool
    let roomType: String
    let roomSize: String
    let roomShape: Int
    let wallType: String
    let micPosition: String
    let level: Int

    var description: String {
        "\(enabled ? "ON" : "OFF"), \(roomType), \(roomSize), "
            + "Shape \(roomShape), \(wallType), Mic \(micPosition), "
            + "Level \(levelText(level))"
    }
}

struct TD17ReverbInfo {
    let enabled: Bool
    let type: String
    let preDelay: Int
    let time: Int
    let density: Int
    let diffusion: Int
    let lowDamp: Int
    let highDamp: Int
    let spread: Int
    let tone: Int
    let level: Int

    var description: String {
        "\(enabled ? "ON" : "OFF"), \(type), Pre-delay \(preDelay) ms, "
            + "Time \(String(format: "%.1f", Double(time) / 10.0)) s, "
            + "Density \(density), Diffusion \(diffusion), "
            + "LF/HF Damp \(lowDamp)/\(highDamp), Spread \(spread), "
            + "Tone \(tone), Level \(levelText(level))"
    }
}

struct TD17MFXInfo {
    let enabled: Bool
    let type: String
    let level: Int
    let parameters: [Int]

    var description: String {
        "\(enabled ? "ON" : "OFF"), \(type), Level \(levelText(level))"
    }
}

struct TD17MasterCompInfo {
    let enabled: Bool
    let type: String
    let splitFrequency: Int
    let lowGain: Int
    let highGain: Int
    let lowThreshold: Int
    let highThreshold: Int
    let lowRatio: Int
    let highRatio: Int
    let lowKnee: Int
    let highKnee: Int
    let lowAttack: Int
    let highAttack: Int
    let lowRelease: Int
    let highRelease: Int
    let balance: Int

    var description: String {
        let split = splitFrequency == 0 ? "SINGLE" : "\(splitFrequency * 10) Hz"
        return "\(enabled ? "ON" : "OFF"), \(type), Split \(split), "
            + "Gain L/H \(halfDB(lowGain))/\(halfDB(highGain)), "
            + "Threshold L/H \(lowThreshold)/\(highThreshold) dB, "
            + "Ratio L/H \(lowRatio)/\(highRatio), Knee L/H \(lowKnee)/\(highKnee), "
            + "Attack L/H \(lowAttack)/\(highAttack), "
            + "Release L/H \(lowRelease)/\(highRelease), Balance \(balance)"
    }

    private func halfDB(_ value: Int) -> String {
        String(format: "%+.1f dB", Double(value) / 2.0)
    }
}

struct TD17KitCommonInfo {
    let name: String
    let subName: String
    let kitVolume: Int
    let pedalHiHatVolume: Int
    let crossStickVolume: Int
    let crossStickEnabled: Bool
    let hiHatBalance: Int

    var description: String {
        "Name \"\(name)\", Sub Name \"\(subName)\", "
            + "Kit \(levelText(kitVolume)), Pedal HH \(levelText(pedalHiHatVolume)), "
            + "XStick \(levelText(crossStickVolume)) "
            + "(\(crossStickEnabled ? "ON" : "OFF")), "
            + "HH Open/Close Balance \(hiHatBalance)"
    }
}

struct TD17MIDINoteInfo: Identifiable {
    let index: Int
    let name: String
    let note: Int

    var id: Int { index }
    var noteText: String { TD17MIDINoteCatalog.text(note) }
}

struct TD17SnapshotInstrumentRestore: Identifiable {
    let zoneIndex: Int
    let isSub: Bool
    let zoneName: String

    var id: String { "\(isSub ? "sub" : "main")-\(zoneIndex)" }
    var label: String { "\(isSub ? "SUB" : "MAIN") \(zoneName)" }
}

struct TD17SnapshotLevelRestore: Identifiable {
    let zoneIndex: Int
    let isSub: Bool
    let zoneName: String

    var id: String { "\(isSub ? "sub" : "main")-\(zoneIndex)-level" }
    var label: String { "\(isSub ? "SUB" : "MAIN") \(zoneName) Level" }
}

struct TD17SnapshotLayerRestore: Identifiable {
    let zoneIndex: Int
    let field: String
    let zoneName: String

    var id: String { "sub-\(zoneIndex)-layer-\(field)" }
    var fieldName: String {
        switch field {
        case "enabled": "ON/OFF"
        case "layerType": "Mode"
        default: "Fade Point"
        }
    }
    var label: String { "SUB \(zoneName) • \(fieldName)" }
}

struct TD17SnapshotPanRestore: Identifiable {
    let zoneIndex: Int
    let zoneName: String

    var id: String { "mixer-\(zoneIndex)-pan" }
    var label: String { "\(zoneName) Pan" }
}

struct TD17SnapshotMixSendRestore: Identifiable {
    let zoneIndex: Int
    let sendIndex: Int
    let zoneName: String

    var id: String { "mixer-\(zoneIndex)-send-\(sendIndex)" }
    var sendName: String {
        ["Ambience", "MFX", "Reverb"][sendIndex]
    }
    var label: String { "\(zoneName) \(sendName) Send" }
}

struct TD17SnapshotEQRestore: Identifiable {
    let zoneIndex: Int
    let field: String
    let zoneName: String

    var id: String { "mixer-\(zoneIndex)-eq-\(field)" }
    var fieldName: String {
        [
            "eqEnabled": "ON/OFF",
            "lowGain": "LOW Gain",
            "midGain": "MID Gain",
            "highGain": "HIGH Gain",
            "lowFrequency": "LOW Freq",
            "midFrequency": "MID Freq",
            "midQ": "MID Q",
            "highFrequency": "HIGH Freq"
        ][field] ?? field
    }
    var label: String { "\(zoneName) Pad EQ • \(fieldName)" }
}

struct TD17SnapshotAmbienceRestore: Identifiable {
    let field: String

    var id: String { "ambience-\(field)" }
    var fieldName: String {
        [
            "enabled": "ON/OFF",
            "roomType": "Room Type",
            "roomSize": "Room Size",
            "roomShape": "Room Shape",
            "wallType": "Wall Type",
            "micPosition": "Mic Position",
            "levelTenthsDB": "Level"
        ][field] ?? field
    }
    var label: String { "Ambience • \(fieldName)" }
}

struct TD17SnapshotReverbRestore: Identifiable {
    let field: String

    var id: String { "reverb-\(field)" }
    var fieldName: String {
        [
            "enabled": "ON/OFF", "type": "Type",
            "preDelay": "Pre Delay", "timeTenths": "Time",
            "density": "Density", "diffusion": "Diffusion",
            "lowDamp": "LF Damp", "highDamp": "HF Damp",
            "spread": "Spread", "tone": "Tone",
            "levelTenthsDB": "Level"
        ][field] ?? field
    }
    var label: String { "Reverb • \(fieldName)" }
}

struct TD17SnapshotMFXRestore: Identifiable {
    let parameterIndex: Int

    var id: String { "mfx-\(parameterIndex)" }
    var fieldName: String {
        switch parameterIndex {
        case 0: "ON/OFF"
        case 1: "Type"
        case 2: "Level"
        default: String(format: "P%02d", parameterIndex - 2)
        }
    }
    var label: String { "MFX • \(fieldName)" }
}

struct TD17SnapshotMasterCompRestore: Identifiable {
    let parameterIndex: Int

    var id: String { "master-comp-\(parameterIndex)" }
    var fieldName: String {
        switch parameterIndex {
        case 0: "ON/OFF"
        case 1: "Type"
        default: TD17MasterCompCatalog.parameterNames[parameterIndex - 2]
        }
    }
    var label: String { "Master Comp • \(fieldName)" }
}

struct TD17SnapshotMIDINoteRestore: Identifiable {
    let index: Int
    let name: String

    var id: String { "midi-note-\(index)" }
    var label: String { "MIDI \(name)" }
}

struct TD17SnapshotVEditRestore: Identifiable {
    let zoneIndex: Int
    let snapshotArrayIndex: Int
    let isSub: Bool
    let field: Int
    let zoneName: String

    var id: String {
        "\(isSub ? "sub" : "main")-\(snapshotArrayIndex)-\(field)"
    }
    var fieldName: String {
        switch field {
        case 1: "Parameter 1"
        case 2: "Parameter 2"
        default: "Parameter 3"
        }
    }
    var label: String {
        "V-Edit \(isSub ? "SUB" : "MAIN") \(zoneName) • \(fieldName)"
    }
}

/// Linia logu z trwałym identyfikatorem.
///
/// Identyfikator nie zmienia się przy obcinaniu bufora, więc lista w widoku
/// nie musi przeliczać tożsamości wszystkich wierszy po każdym obcięciu.
struct TD17LogLine: Identifiable {
    let id: Int
    let text: String
}

private func levelText(_ value: Int) -> String {
    if value == -601 { return "-INF" }
    return String(format: "%+.1f dB", Double(value) / 10.0)
}

@MainActor
final class MIDIManager: ObservableObject {
    @Published private(set) var inputs: [MIDIEndpointInfo] = []
    @Published private(set) var outputs: [MIDIEndpointInfo] = []
    @Published var selectedInputID: MIDIEndpointID?
    @Published var selectedOutputID: MIDIEndpointID?
    @Published private(set) var status = "Inicjalizacja CoreMIDI…"
    /// Log jako lista linii, a nie jeden `String`.
    ///
    /// Poprzednio było to `@Published String` sklejane przez `log +=`.
    /// Każdy dopisek kopiował cały tekst i unieważniał widok, a widok
    /// renderował całość jako jeden `Text` z zaznaczaniem. Przy kilku
    /// odczytach pod rząd (log rośnie, nikt go nie czyści) koszt rósł
    /// kwadratowo i odczyt kitu przestawał się mieścić w limicie czasu.
    @Published private(set) var logLines: [TD17LogLine] = []
    @Published private(set) var currentKitNumber: Int? {
        didSet {
            if let currentKitNumber { displayedKitNumber = currentKitNumber }
        }
    }

    /// Numer kitu **do pokazania**. `currentKitNumber` jest zerowany na czas
    /// odczytu, bo od niego zależą adresy zapisu — a przez to karta z numerem
    /// kitu znikała z nagłówka przy każdym odczycie razem z przyciskami zmiany
    /// kitu, które ten odczyt wywołały.
    @Published private(set) var displayedKitNumber: Int?

    @Published private(set) var currentKitName: String?
    @Published private(set) var zones: [TD17ZoneInfo] = []
    @Published private(set) var layers: [TD17LayerInfo] = []
    @Published private(set) var vEdits: [TD17VEditInfo] = []
    @Published private(set) var subVEdits: [TD17VEditInfo] = []
    @Published private(set) var mixInfos: [TD17MixInfo] = []
    @Published private(set) var ambience: TD17AmbienceInfo?
    @Published private(set) var reverb: TD17ReverbInfo?
    @Published private(set) var mfx: TD17MFXInfo?
    @Published private(set) var masterComp: TD17MasterCompInfo?
    @Published private(set) var kitCommon: TD17KitCommonInfo?
    @Published private(set) var midiNotes: [TD17MIDINoteInfo] = []
    @Published var kitVolumeDraft: Double = 0
    @Published var mainLevelDrafts: [Int: Double] = [:]
    @Published var subLevelDrafts: [Int: Double] = [:]
    @Published var mainInstrumentDrafts: [Int: Int] = [:]
    @Published var subInstrumentDrafts: [Int: Int] = [:]
    @Published var subEnabledDrafts: [Int: Bool] = [:]
    @Published var subLayerTypeDrafts: [Int: Int] = [:]
    @Published var subFadePointDrafts: [Int: Int] = [:]
    @Published var mainTuningDrafts: [Int: Int] = [:]
    @Published var subTuningDrafts: [Int: Int] = [:]
    @Published var mainVEditSecondDrafts: [Int: Int] = [:]
    @Published var subVEditSecondDrafts: [Int: Int] = [:]
    @Published var mainVEditThirdDrafts: [Int: Int] = [:]
    @Published var subVEditThirdDrafts: [Int: Int] = [:]
    @Published var panDrafts: [Int: Int] = [:]
    @Published var ambienceSendDrafts: [Int: Int] = [:]
    @Published var mfxSendDrafts: [Int: Int] = [:]
    @Published var reverbSendDrafts: [Int: Int] = [:]
    @Published var eqEnabledDrafts: [Int: Bool] = [:]
    @Published var eqLowGainDrafts: [Int: Int] = [:]
    @Published var eqMidGainDrafts: [Int: Int] = [:]
    @Published var eqHighGainDrafts: [Int: Int] = [:]
    @Published var eqLowFrequencyDrafts: [Int: Int] = [:]
    @Published var eqMidFrequencyDrafts: [Int: Int] = [:]
    @Published var eqMidQDrafts: [Int: Int] = [:]
    @Published var eqHighFrequencyDrafts: [Int: Int] = [:]
    @Published var ambienceEnabledDraft = false
    @Published var ambienceLevelDraft = -601
    @Published var ambienceRoomTypeDraft = 0
    @Published var ambienceRoomSizeDraft = 0
    @Published var ambienceRoomShapeDraft = 0
    @Published var ambienceWallTypeDraft = 0
    @Published var ambienceMicPositionDraft = 0
    @Published var reverbEnabledDraft = false
    @Published var reverbTypeDraft = 0
    @Published var reverbParameterDrafts: [Int: Int] = [:]
    @Published var reverbLevelDraft = -601
    @Published var mfxEnabledDraft = false
    @Published var mfxTypeDraft = 0
    @Published var mfxLevelDraft = -601
    @Published var mfxParameterDrafts: [Int: Int] = [:]
    @Published var masterCompEnabledDraft = false
    @Published var masterCompTypeDraft = 0
    @Published var masterCompParameterDrafts: [Int: Int] = [:]
    @Published var pedalHiHatVolumeDraft = -601
    @Published var crossStickVolumeDraft = -601
    @Published var crossStickEnabledDraft = false
    @Published var hiHatBalanceDraft = 0
    @Published var kitNameDraft = ""
    @Published var kitSubNameDraft = ""
    @Published var midiNoteDrafts: [Int: Int] = [:]
    @Published private(set) var importedSnapshotSummary: String?
    @Published private(set) var importedSnapshotDetails: [String] = []
    @Published private(set) var importedSnapshotSourceKitNumber: Int?
    @Published private(set) var authorizedSnapshotTargetKitNumber: Int?
    @Published private(set) var snapshotDifferences: [String]?
    @Published private(set) var isWriting = false {
        didSet {
            guard isWriting != oldValue else { return }
            writeGeneration &+= 1
            if isWriting {
                lastWriteConfirmed = false
                scheduleWriteWatchdog()
            }
        }
    }

    /// Czy **ostatni** zakończony zapis został potwierdzony przez moduł.
    ///
    /// Samo opadnięcie `isWriting` nie wystarczy: tak samo kończy się zapis
    /// potwierdzony, zapis, przy którym moduł odesłał inną wartość, i zapis
    /// przerwany przez watchdoga. Warstwa edycji brała każdy z nich za sukces
    /// i kasowała zmianę z listy jako wysłaną — także wtedy, gdy moduł ściął
    /// wartość albo w ogóle jej nie przyjął.
    ///
    /// Flaga jest ustawiana **jawnie** w każdej gałęzi weryfikacji. Wcześniej
    /// wynik był rozpoznawany po przedrostku linii logu — co znaczyło, że
    /// przetłumaczenie komunikatów po cichu zepsułoby całą wysyłkę.
    @Published private(set) var lastWriteConfirmed = false

    /// Rośnie po każdym **pełnym** odczycie kitu. Sygnał dla warstwy edycji,
    /// żeby przepisać wartości z modułu jako stan wyjściowy. Szybki odczyt
    /// (po zmianie kitu na module) daje tylko część danych, więc go pomijamy.
    @Published private(set) var kitReadGeneration = 0

    @Published private(set) var isReadingKit = false {
        didSet {
            guard oldValue, !isReadingKit,
                  readPhase == .complete, !isQuickRead
            else { return }
            kitReadGeneration &+= 1
            scheduleKitListScan()
        }
    }
    /// Trwa przywracanie wsadowe z kopii zapasowej.
    ///
    /// Opuszczenie tej flagi gasi też `isFastWriting`. Te dwie muszą schodzić
    /// razem: `isFastWriting` blokuje wszystkie przyciski przywracania, a gasi
    /// się tylko w ciele zadania szybkiego zapisu. Gdyby ktokolwiek inny —
    /// watchdog, przycisk Stop, przyszła ścieżka wyjścia — zgasił samo
    /// `isBatchRestoring`, zadanie kończyło się przez `guard` na początku
    /// pętli i zostawiało `isFastWriting` podniesione **na zawsze**:
    /// przyciski wyglądałyby na aktywne, a nie robiłyby nic, aż do
    /// ponownego uruchomienia programu.
    @Published private(set) var isBatchRestoring = false {
        didSet { if !isBatchRestoring { isFastWriting = false } }
    }
    @Published private(set) var batchRestoreProgress: String?
    @Published private(set) var stabilizationSecondsRemaining = 0
    @Published var automaticallyReadChangedKit = true

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var connectedInput: MIDIEndpointRef?
    private var sysExBuffer: [UInt8] = []
    private var pendingProgramChangeStatus: UInt8?
    private var automaticKitReadTask: Task<Void, Never>?

    /// Odroczony pełny odczyt po zmianie kitu na module.
    private var deferredFullReadTask: Task<Void, Never>?

    /// Pierwszy odczyt po starcie aplikacji albo po podpięciu modułu.
    private var initialReadTask: Task<Void, Never>?
    private var initialReadDone = false

    /// Zrzut SETUP: czy na ostatnie zapytanie przyszła odpowiedź.
    private var setupDumpActive = false
    private var setupDumpReplied = false

    /// Skan listy kitów: jego watchdog i numer pokolenia.
    private var kitListScanTask: Task<Void, Never>?
    private var kitListScanGeneration = 0
    private var kitListScanDone = false

    /// Moduł zmienił kit w trakcie innej operacji i numer kitu celowo nie
    /// został przestawiony. Trzeba się z nim zsynchronizować, gdy tylko
    /// bieżąca operacja się skończy.
    private var needsKitReconcile = false

    /// Czy przy poprzednim odświeżeniu moduł był widoczny — po to, żeby
    /// rozpoznać wypięcie kabla.
    private var moduleWasAvailable = false

    private var nextReadShouldBeQuick = false
    private var isQuickRead = false
    private var readGeneration = 0
    private var readPhase: ReadPhase = .idle
    private var pendingLayerCommon: LayerCommon?
    private var importedSnapshot: [String: Any]?
    private var snapshotDifferencePaths: Set<String> = []
    private var batchRestoreActions: [() -> Void] = []
    private var batchRestoreTotal = 0
    private var stabilizeAfterCurrentRead = false
    /// Rośnie przy każdej zmianie `isWriting` — czyli osobno przy starcie
    /// i przy końcu zapisu. Warstwa edycji używa tego, żeby upewnić się, że
    /// czyta werdykt **swojego** zapisu, a nie jakiegoś, który wcisnął się
    /// w międzyczasie. Bez `@Published`: nikt tego nie obserwuje, a każdy
    /// zapis podbijałby licznik dwa razy i przerysowywał cały interfejs.
    private(set) var writeGeneration = 0
    private var lastSendFailed = false

    /// Czy ostatnia wysyłka faktycznie zeszła na kabel.
    ///
    /// `write*` podnosi `isWriting` także wtedy, gdy `sendSysEx` odmówił —
    /// po terminie ważności albo bez wybranego wyjścia. Kto po wysyłce
    /// zapisuje sobie „to poszło do modułu", musi umieć te dwa przypadki
    /// rozróżnić.
    var lastSendReachedTheWire: Bool { !lastSendFailed }
    private var pendingLogLines: [String] = []
    private var nextLogLineID = 0
    private var logFlushTask: Task<Void, Never>?
    private var incomingContinuation: AsyncStream<[UInt8]>.Continuation?
    private var incomingTask: Task<Void, Never>?

    /// Górny limit linii logu. Starsze są odrzucane.
    private let maximumLogLines = 3000

    /// Po tylu sekundach bez zmiany fazy odczyt uznajemy za zerwany.
    private let readInactivityTimeoutSeconds = 12

    /// Ile sekund bez zmiany kitu na module czekamy, zanim dociągniemy resztę
    /// danych. Przy przewijaniu kitów pokrętłem każdy skok odsuwa ten moment,
    /// więc pełny odczyt (ok. 3 s) startuje dopiero, gdy wybór się ustali.
    private let deferredFullReadDelaySeconds = 5

    /// Po tylu sekundach bez potwierdzenia zapisu operacja jest przerywana.
    /// Musi być krótsze niż limit pollingu w `runNextBatchRestoreAction` (10 s),
    /// żeby to watchdog decydował o przerwaniu, a nie pętla wsadowa.
    private let writeVerificationTimeoutSeconds = 8

    /// Górny limit długości składanej ramki SysEx. Najdłuższy blok, jakiego
    /// oczekujemy od TD-17, to MFX (0x86 bajtów danych), więc 4 kB to zapas
    /// z bardzo dużym marginesem, a jednocześnie zabezpieczenie przed
    /// nieograniczonym rośnięciem bufora po urwanej ramce.
    private let maximumSysExLength = 4096

    // MARK: - Kanoniczne zakresy parametrów
    //
    // Jedno miejsce prawdy dla walidacji. Wcześniej te same zakresy były
    // wpisane osobno w każdej metodzie `write*`, a ścieżka szybkiego zapisu
    // nie sprawdzała ich w ogóle.

    /// Poziomy w dziesiątych częściach dB. -601 oznacza INF (cisza).
    nonisolated static let levelRange = -601...60

    /// Wysyłki efektów per strefa — tylko tłumienie, bez wzmocnienia.
    nonisolated static let sendLevelRange = -601...0

    /// Poziom główny Ambience / Reverb / MFX.
    ///
    /// Wcześniej wpisany jako -601…0. Log odczytu z TD-17 pokazuje jednak
    /// Reverb Level = +0.1 dB, czyli moduł potrafi zwrócić wartość dodatnią
    /// i węższy zakres blokował poprawne dane. Ta sama skala co pozostałe
    /// poziomy w urządzeniu — i ta sama, której od początku używała
    /// ścieżka plików TD0.
    nonisolated static let effectLevelRange = -601...60

    nonisolated static let hiHatBalanceRange = -64...63
    nonisolated static let panRange = -64...63
    nonisolated static let eqGainRange = -15...15
    nonisolated static let roomShapeRange = 0...100

    /// Zakres oferowany użytkownikowi przy ręcznej edycji Fade Point.
    nonisolated static let fadePointEditRange = 1...127

    /// Zakres, jaki może przyjść z modułu. Fade Point ma sens tylko dla
    /// FADE1/FADE2 — przy MIX i SWITCH moduł zwraca 0, więc dane odczytane
    /// ze sprzętu wolno walidować wyłącznie tym szerszym zakresem. Użycie
    /// tu zakresu edycyjnego blokowałoby szybki zapis całego snapshotu
    /// z powodu padów, których ten parametr w ogóle nie dotyczy.
    nonisolated static let fadePointStorageRange = 0...127

    /// Numer nuty MIDI; 128 to prawidłowa wartość oznaczająca OFF.
    nonisolated static let midiNoteRange = 0...128

    private enum ReadPhase: Equatable {
        case idle
        case currentKit
        case kitName
        case zone(Int)
        case layerCommon(Int)
        case layerInstrument(Int)
        case vEdit(Int)
        case subVEdit(Int)
        case ambience
        case reverb
        case mfx
        case masterComp
        case kitCommon
        case kitMIDI
        case kitVolumeVerify(Int)
        case zoneLevelVerify(Int, Int, Bool)
        case instrumentVerify(Int, Int, Bool)
        case layerSettingsVerify(Int, Bool, Int, Int)
        case vEditTuningVerify(Int, Int, Bool)
        case vEditParameterVerify(Int, Int, Int, Bool)
        case panVerify(Int, Int)
        case mixSendVerify(Int, Int, Int)
        case eqEnabledVerify(Int, Bool)
        case eqGainVerify(Int, Int, Int)
        case eqShapeVerify(Int, Int, Int)
        case ambienceEnabledVerify(Bool)
        case ambienceLevelVerify(Int)
        case ambienceParameterVerify(Int, Int)
        case reverbVerify(Int, Int)
        case mfxVerify(Int, Int)
        case masterCompVerify(Int, Int)
        case kitCommonParameterVerify(Int, Int)
        case kitTextVerify(Int, String)
        case midiNoteVerify(Int, Int)
        /// Oczekiwanie na potwierdzenie przełączenia kitu w module.
        case kitSelectVerify(Int)
        /// Skanowanie nazw wszystkich kitów — indeks aktualnie odpytywanego.
        case kitListName(Int)
        /// Odczyt ustawień triggerów: blok wspólny, potem wejścia 1…10.
        case triggerCommon
        case triggerInput(Int)
        case complete
    }

    private struct LayerCommon {
        let enabled: Bool
        let type: String
        let fadePoint: Int
        let mixInfo: TD17MixInfo
    }

    private struct FastSnapshotBlock {
        let name: String
        let address: [UInt8]
        let data: [UInt8]
    }

    private var zoneNames: [String] { profile.zoneNames }

    /// Czy któryś z portów w systemie wygląda na znany nam moduł.
    ///
    /// Nazwa została (`td17Detected`), bo używa jej kilkanaście miejsc,
    /// ale warunek dotyczy teraz każdego profilu z listy.
    var td17Detected: Bool { anyKnownModulePresent }

    /// Profil rozpoznany po **wybranych** portach.
    ///
    /// Celowo nie po pierwszym pasującym urządzeniu w systemie. Bajty idą na
    /// wybrane wyjście, więc to ono decyduje, z jakim modułem rozmawiamy.
    /// Przy TD-17 i TD-27 wpiętych naraz różnica między jednym a drugim to
    /// różnica między zapisem tam, gdzie trzeba, a zapisem do cudzego
    /// instrumentu adresami z niewłaściwej mapy.
    private var detectedProfileFromPortNames: ModuleProfile? {
        ModuleProfile.matching(
            outputName: outputs.first { $0.id == selectedOutputID }?.name,
            inputName: inputs.first { $0.id == selectedInputID }?.name
        )
    }

    /// Czy w systemie widać jakikolwiek znany moduł — niezależnie od wyboru.
    /// Używane tylko do zapalenia „wykryto", nigdy do adresowania.
    private var anyKnownModulePresent: Bool {
        (inputs + outputs).contains { ModuleProfile.matching(portName: $0.name) != nil }
    }

    /// Roland odpowiedział na zapytanie o tożsamość.
    ///
    /// Wykrywanie po nazwie portu działa tylko przez USB. Kto wpina moduł
    /// przez zwykły interfejs MIDI, ma port nazwany po interfejsie i program
    /// twierdziłby, że nie widzi modułu — mimo że wszystko działa.
    @Published private(set) var rolandIdentityDetected = false

    /// Moduł, z którym rozmawiamy. Domyślnie TD-17 — jedyny sprawdzony na
    /// sprzęcie. Zmienia się po rozpoznaniu portu albo po odpowiedzi
    /// Identity Reply.
    @Published private(set) var profile: ModuleProfile = .td17

    private var deviceRefreshTask: Task<Void, Never>?

    /// Odświeżenie listy urządzeń, ale nie częściej niż raz na 200 ms.
    ///
    /// CoreMIDI woła powiadomienie przy każdym pojawieniu się i zniknięciu
    /// portu, a wirtualne porty może tworzyć i kasować w pętli dowolna
    /// aplikacja. Każde powiadomienie przeglądało wszystkie punkty końcowe
    /// i dopisywało linię do logu — wystarczyło do zapchania głównego wątku,
    /// czyli zamrożenia okna.
    private func scheduleDeviceRefresh() {
        deviceRefreshTask?.cancel()
        deviceRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled else { return }
            self.deviceRefreshTask = nil
            self.refreshDevices()
        }
    }

    /// Czy czeka nieobsłużone powiadomienie o zmianie urządzeń.
    private var pendingDeviceRefresh = false

    /// Numer urządzenia z pierwszej przyjętej odpowiedzi DT1.
    ///
    /// Od tej chwili odpowiedzi z innym numerem są pomijane — patrz
    /// `decodeDT1`. Kasowany razem z wykryciem modułu, przy przepięciu kabla.
    private var moduleDeviceID: UInt8?

    /// Czy jest z czym rozmawiać: albo port nazywa się TD-17, albo ktoś
    /// po drugiej stronie przedstawił się jako Roland.
    var moduleAvailable: Bool { td17Detected || rolandIdentityDetected }

    /// Czy **wybrane** porty wyglądają na TD-17.
    ///
    /// `td17Detected` mówi tylko tyle, że moduł jest gdzieś w systemie.
    /// Przy kilku urządzeniach MIDI wybór potrafi zostać przy poprzednim
    /// i odczyt poleciałby nie tam, gdzie trzeba.
    var selectedPortsLookLikeTD17: Bool {
        let names = [
            inputs.first { $0.id == selectedInputID }?.name,
            outputs.first { $0.id == selectedOutputID }?.name
        ]
        // `allSatisfy`, nie `contains`: pytania idą na **wyjście**, więc
        // wejście z TD-17 i wyjście z innego interfejsu to dokładnie ten
        // przypadek, przed którym ten warunek ma chronić.
        return names.allSatisfy {
            guard let name = $0 else { return false }
            return name.localizedCaseInsensitiveContains(profile.portKeyword)
        }
    }

    var isOperationInProgress: Bool {
        isBusyWithSysEx || isAuditioningKit
    }

    /// Czy wolno rozpocząć pojedyncze przywrócenie z kopii.
    ///
    /// Samo `!isWriting` nie wystarczało. Między dwoma krokami serii z edytora
    /// flaga opada na kilkadziesiąt milisekund, a przez cały szybki zapis
    /// i przez trzydziestosekundowe ustawianie się modułu jest opuszczona na
    /// stałe. Wystarczyło w tym czasie kliknąć „Restore" w sekcji Backup, żeby
    /// drugi zapis wszedł w środek pierwszego: przestawiał fazę weryfikacji,
    /// przez co odpowiedź na tamten pierwszy nie pasowała już do niczego,
    /// a edytor melował „moduł nie potwierdził" o zmianie, która **doszła**.
    ///
    /// W trakcie samej serii wsadowej pytamy dalej tylko o `isWriting` — seria
    /// trzyma własną flagę i inaczej blokowałaby sama siebie.
    private var canStartSingleRestore: Bool {
        // Szybki zapis nie podnosi `isWriting` — leci blokami, bez weryfikacji
        // każdego z osobna. Bez osobnej flagi kliknięcie „Restore" w jego
        // trakcie przechodziło przez ten warunek, a co gorsza **pomijało
        // własne okno potwierdzenia**, bo te sprawdzają `!isBatchRestoring`.
        // Wchodziło więc w środek strumienia bloków, przestawiając fazę
        // weryfikacji — czyli dokładnie to, przed czym ten warunek ma bronić.
        if isFastWriting { return false }
        return isBatchRestoring ? !isWriting : !isBusyWithSysEx
    }

    /// Trwa szybki zapis całego kitu (seria bloków bez weryfikacji każdego).
    private var isFastWriting = false

    /// Trwa rozmowa SysEx z modułem.
    ///
    /// Osobno od `isOperationInProgress`, bo odsłuch **też** ma wstrzymywać
    /// resztę programu — odroczony odczyt kitu nie ma prawa wejść w środek
    /// grania, bo echo nuty rozwala niedokończoną ramkę. Ale sam odsłuch musi
    /// mieć czym wysyłać: gdyby nuty pytały o `isOperationInProgress`,
    /// pierwsza z nich zablokowałaby wszystkie następne.
    var isBusyWithSysEx: Bool {
        isWriting || isReadingKit || isBatchRestoring || isEditorSending
            || isScanningKitList || isDumpingSetup || isReadingTriggers
            || stabilizationSecondsRemaining > 0
    }

    /// Trwa zrzut obszaru ustawień modułu.
    @Published private(set) var isDumpingSetup = false

    // MARK: - Odsłuch

    /// Czy kliknięcie w pad ma go zagrać w module.
    @Published var auditionEnabled = true

    /// Siła uderzenia wysyłana przy odsłuchu.
    @Published var auditionVelocity = 100

    /// Kanał MIDI, na którym moduł przyjmuje nuty. TD-17 domyślnie 10.
    @Published var auditionChannel = 10

    /// Trwa przesłuchiwanie całego zestawu pad po padzie.
    @Published private(set) var isAuditioningKit = false

    /// Strefa, która **właśnie zabrzmiała** — do podświetlenia na scenie.
    ///
    /// Przy odsłuchu na słuchawkach dźwięk wychodzi z modułu, a program nie ma
    /// jak go usłyszeć. Wie za to dokładnie, którą nutę przed chwilą wysłał —
    /// i to wystarczy, żeby pokazać, co słychać.
    ///
    /// Ustawiane **tylko wtedy, gdy nuta faktycznie zeszła na kabel**.
    /// Podświetlenie pada, który nie zagrał, byłoby gorsze od jego braku:
    /// człowiek słyszy ciszę i widzi, że coś gra.
    @Published private(set) var nowPlayingZone: Int?

    private var nowPlayingTask: Task<Void, Never>?

    /// Nazwa strefy, która właśnie zabrzmiała — do pokazania w pasku.
    ///
    /// Nazwy bierzemy z profilu, bo TD-27 ma inny zestaw stref niż TD-17.
    var nowPlayingZoneName: String? {
        guard let zone = nowPlayingZone,
              profile.zoneNames.indices.contains(zone) else { return nil }
        return profile.zoneNames[zone]
    }

    /// Zapala podświetlenie strefy i gasi je po chwili.
    ///
    /// Czas dobrany tak, żeby przy przesłuchiwaniu całego zestawu (krok co
    /// 420 ms) podświetlenie gasło tuż przed zapaleniem następnego — widać
    /// wtedy wędrówkę po padach, a nie stale zapalony jeden.
    ///
    /// Celowo dłużej niż 120 ms do `note off`: bęben wybrzmiewa po zamknięciu
    /// nuty, więc podświetlenie ma iść za **dźwiękiem**, a nie za komunikatem.
    /// Przy krótkich brzmieniach (cross stick, zamknięty hi-hat) pad świeci
    /// przez chwilę po ucichnięciu i tak ma być — skracanie tego psuje
    /// czytelność przesłuchania.
    private func flagPlaying(_ zoneIndex: Int) {
        nowPlayingZone = zoneIndex
        nowPlayingTask?.cancel()
        nowPlayingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(360))
            guard let self, !Task.isCancelled else { return }
            // Gasimy wyłącznie **własne** podświetlenie. W międzyczasie mógł
            // zabrzmieć następny pad i to jego nie wolno zgasić.
            if self.nowPlayingZone == zoneIndex { self.nowPlayingZone = nil }
        }
    }

    private var auditionTask: Task<Void, Never>?
    private var auditionGeneration = 0

    /// Ustawienia triggerów odczytane z modułu.
    @Published private(set) var triggers: [TD17TriggerInfo] = []
    @Published private(set) var triggerCommon: TD17TriggerCommonInfo?
    @Published private(set) var isReadingTriggers = false

    /// Nazwy wszystkich kitów w module, numer → nazwa.
    ///
    /// Nie da się ich wyczytać inaczej niż po kolei — moduł oddaje nazwę
    /// jednego kitu na zapytanie. Sto wymian idzie w podobnym czasie co pełny
    /// odczyt jednego kitu, więc robimy to raz i trzymamy.
    @Published private(set) var kitNames: [Int: String] = [:]
    @Published private(set) var isScanningKitList = false
    @Published private(set) var kitListProgress: Int = 0

    /// Czy warstwa edycji wysyła właśnie serię zmian.
    ///
    /// Sama flaga `isWriting` nie wystarczy: między krokami wysyłki opada na
    /// kilkadziesiąt milisekund i w tej szparze wszystko, co pyta „czy coś
    /// trwa", widziało bezczynność. Wystarczyło, żeby odroczony odczyt kitu
    /// albo przycisk zmiany kitu wszedł w środek wysyłki, wyzerował numer kitu
    /// i zerwał resztę serii — a już wysłane kroki zostałyby zaraportowane
    /// jako potwierdzone cudzym werdyktem.
    @Published private(set) var isEditorSending = false

    func beginEditorSend() { isEditorSending = true }

    func endEditorSend() { isEditorSending = false }

    var snapshotNeedsTargetAuthorization: Bool {
        guard let source = importedSnapshotSourceKitNumber,
              let current = currentKitNumber
        else { return false }
        return source != current && authorizedSnapshotTargetKitNumber != current
    }

    init() {
        createMIDIClient()
        refreshDevices()
    }

    deinit {
        automaticKitReadTask?.cancel()
        deferredFullReadTask?.cancel()
        initialReadTask?.cancel()
        kitListScanTask?.cancel()
        logFlushTask?.cancel()
        incomingContinuation?.finish()
        incomingTask?.cancel()
        if let connectedInput {
            MIDIPortDisconnectSource(inputPort, connectedInput)
        }
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if outputPort != 0 { MIDIPortDispose(outputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }

    func refreshDevices() {
        guard !isOperationInProgress else {
            // Jedna linia na oczekiwanie, nie jedna na próbę. Ponawianie co
            // 200 ms przez czterominutową sondę to tysiąc identycznych linii,
            // które wypychają z logu dokładnie te bajty, po które sonda
            // została uruchomiona.
            if !pendingDeviceRefresh {
                appendLog("Device change noticed — will refresh when free")
            }
            pendingDeviceRefresh = true
            // Ponawiamy, zamiast gubić: podmiana modułu w trakcie odczytu
            // zostawiłaby profil poprzedniego na zawsze, a to jest dokładnie
            // ten stan, w którym program pisze nie tam, gdzie myśli.
            deviceRefreshTask?.cancel()
            deviceRefreshTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.deviceRefreshTask = nil
                self.refreshDevices()
            }
            return
        }
        pendingDeviceRefresh = false

        let previousInput = selectedInputID
        let previousOutput = selectedOutputID

        inputs = (0..<MIDIGetNumberOfSources()).compactMap {
            endpointInfo(for: MIDIGetSource($0))
        }
        outputs = (0..<MIDIGetNumberOfDestinations()).compactMap {
            endpointInfo(for: MIDIGetDestination($0))
        }

        // Automat sięga po „pierwszy lepszy" port dopiero wtedy, gdy jest
        // dokładnie jeden — czyli gdy nie ma czego pomylić.
        //
        // Wcześniej program podłączał się sam do pierwszego portu na liście.
        // Każda aplikacja na macOS może utworzyć wirtualny port MIDI, bez
        // żadnych uprawnień i bez pytania — a podłączone wejście może potem
        // przestawić numer bieżącego kitu komunikatem Program Change. Adresy
        // wszystkich zapisów liczą się z tego numeru, więc obce wejście
        // potrafiło skierować edycję użytkownika do zupełnie innego kitu
        // w prawdziwym module. Przy dwóch portach i więcej wybór należy
        // teraz do człowieka.
        selectedInputID = retainedSelection(previousInput, in: inputs)
            ?? td17Endpoint(in: inputs)?.id
            ?? (inputs.count == 1 ? inputs.first?.id : nil)

        selectedOutputID = retainedSelection(previousOutput, in: outputs)
            ?? td17Endpoint(in: outputs)?.id
            ?? (outputs.count == 1 ? outputs.first?.id : nil)

        // Przełączenie profilu, gdy po drugiej stronie jest inny moduł.
        // Idzie **wyłącznie** po nazwie portu, bo tylko ona jest pewna:
        // kodów rodziny i modelu z Identity Reply nie mamy potwierdzonych
        // dla żadnego z tych modułów, a zgadywanie na ich podstawie
        // przestawiłoby adresy zapisu na chybił trafił.
        if let detected = detectedProfileFromPortNames, detected != profile {
            appendLog(
                "Module changed: \(profile.displayName) → \(detected.displayName)"
                    + (detected.hasVerifiedMap
                        ? ""
                        : " — read only, address map not verified yet")
            )
            profile = detected
            initialReadDone = false
            kitListScanDone = false
            moduleDeviceID = nil
            // Wszystko, co opisywało poprzedni moduł, musi zniknąć. Dane
            // z TD-17 pokazane pod nagłówkiem TD-27 wprowadzają w błąd,
            // a zostawione drafty potrafią uzbroić warunki wstępne zapisu
            // wartościami wziętymi z zupełnie innego instrumentu.
            resetKitState()
            kitNames = [:]
            triggers = []
            triggerCommon = nil
            isReadingKit = false
            readPhase = .idle
            // Zadania uzbrojone dla poprzedniego modułu śpią i przez to nie
            // liczą się jako trwająca operacja. Obudzone po podmianie
            // poszłyby czytać nowy moduł mapą starego.
            automaticKitReadTask?.cancel()
            deferredFullReadTask?.cancel()
            kitListScanTask?.cancel()
            initialReadTask?.cancel()
            probeTask?.cancel()
            needsKitReconcile = false
            kitListProgress = 0
        }

        connectSelectedInput()

        // Wypięcie modułu odblokowuje jednorazowy automat, żeby po ponownym
        // wpięciu odczyt zrobił się sam. Bez tego kabel wyjęty i włożony
        // w tej samej sesji zostawiał pusty ekran do czasu kliknięcia.
        if connectedInput == nil || (moduleWasAvailable && !td17Detected) {
            initialReadDone = false
            rolandIdentityDetected = false
            // Po przepięciu kabla numer urządzenia trzeba poznać od nowa —
            // po drugiej stronie może być teraz inny moduł.
            moduleDeviceID = nil
        }
        moduleWasAvailable = td17Detected

        // Nazwę modułu podajemy tylko wtedy, gdy wynika z **wybranych**
        // portów. Inaczej przy TD-27 na magistrali i niewybranym wyjściu
        // nagłówek meldowałby „TD-17 detected" — czyli dokładnie to
        // pomylenie, przed którym broni rozpoznawanie po wyborze.
        if detectedProfileFromPortNames != nil {
            status = "\(profile.displayName) detected"
        } else if anyKnownModulePresent {
            status = "Module detected — select the input and output"
        } else {
            status = "No module detected"
        }
        appendLog("Refreshed: \(inputs.count) inputs, \(outputs.count) MIDI outputs")
        scheduleInitialKitRead()

        // Lista kitów zaraz po podpięciu modułu, nie dopiero po pierwszym
        // pełnym odczycie. Zadanie samo poczeka, aż odczyt się skończy —
        // dwie rozmowy z modułem naraz i tak są niemożliwe.
        if moduleAvailable, connectedInput != nil {
            scheduleKitListScan()
        }
    }

    /// Pierwszy pełny odczyt — po starcie aplikacji albo po podpięciu modułu.
    ///
    /// Bez tego program otwierał się pusty i nie było wiadomo, czy coś jest
    /// nie tak z połączeniem, czy po prostu nikt nic nie kliknął. Odczyt
    /// startuje raz na uruchomienie; potem kit śledzi już Program Change
    /// z modułu.
    ///
    /// Gdy nazwa portu nie zdradza TD-17 (moduł za zwykłym interfejsem MIDI),
    /// program pyta wprost — Identity Request. Roland odpowiada, kim jest,
    /// i dopiero wtedy ruszamy z odczytem. Cisza oznacza, że po drugiej
    /// stronie nie ma z kim rozmawiać, więc nie zużywamy jedynej próby.
    private func scheduleInitialKitRead() {
        // Anulowanie **przed** strażnikiem: inaczej wypięcie kabla zostawiało
        // w locie zadanie, które budziło się chwilę później i wysyłało
        // zapytanie w port, którego już nie ma.
        initialReadTask?.cancel()
        guard !initialReadDone, connectedInput != nil, selectedOutputID != nil
        else { return }

        initialReadTask = Task { @MainActor [weak self] in
            // CoreMIDI potrzebuje chwili po zestawieniu połączenia; wysłane
            // wcześniej RQ1 potrafi przepaść bez odpowiedzi. Podpięcie modułu
            // daje zwykle kilka powiadomień pod rząd — każde anuluje poprzednie
            // zadanie, więc wychodzi z tego zwykłe wygładzenie.
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            guard !self.isOperationInProgress else {
                // Ponowienie, a nie rezygnacja: skan listy kitów potrafi
                // wystartować kilkaset milisekund wcześniej i wtedy pierwszy
                // odczyt przepadał bez śladu, a okno zostawało puste.
                self.scheduleInitialKitRead()
                return
            }

            // Liczy się nazwa **wybranego** portu, a nie to, czy TD-17 jest
            // gdziekolwiek w systemie: przy kilku urządzeniach MIDI wybór
            // mógł zostać przy innym i odczyt poleciałby nie tam.
            if !self.selectedPortsLookLikeTD17, !self.rolandIdentityDetected {
                self.appendLog(
                    "AUTO: the selected port does not look like a TD-17 — asking for identity"
                )
                self.sendIdentityRequest()
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                guard self.rolandIdentityDetected else {
                    self.appendLog(
                        "AUTO: no reply from Roland — read skipped. "
                            + "Select the ports manually and use “Read full kit”."
                    )
                    return
                }
                self.status = "A Roland module replied"
            }

            guard !self.isOperationInProgress else {
                self.scheduleInitialKitRead()
                return
            }

            // Flaga dopiero tutaj: gdyby padła wcześniej, nieudana próba
            // (anulowana albo zjedzona przez inną operację) zużyłaby jedyną
            // szansę i nawet „Odśwież" nie mogłoby jej odzyskać.
            self.initialReadDone = true
            self.appendLog("AUTO: full kit read after launch")
            self.readCurrentKit()
        }
    }

    // MARK: - Odsłuch kitu

    /// Numer nuty, którą moduł kojarzy z daną strefą.
    ///
    /// Bierzemy stan **odczytany z modułu**, a nie wartość z listy zmian:
    /// niewysłana zmiana nuty jeszcze w module nie obowiązuje, więc odsłuch
    /// z jej użyciem trafiłby w inny pad, niż wskazuje palec.
    func auditionNote(forZone zoneIndex: Int) -> Int? {
        // Pierwsza **grająca** nuta, a nie pierwsza z listy: strefa potrafi
        // mieć główne przypisanie na OFF, a drugie normalne — wtedy pad
        // milczałby bez powodu.
        for index in TD17NoteMap.noteIndices(forZone: zoneIndex) {
            guard midiNotes.indices.contains(index) else { continue }
            let note = midiNotes[index].note
            // 128 to OFF, a nie numer nuty.
            if (0...127).contains(note) { return note }
        }
        return nil
    }

    /// Gra jedną strefę w module.
    ///
    /// Program nie ma czym zagrać sam — próbki siedzą w pamięci TD-17.
    /// Wysyłamy więc zwykłą nutę i dźwięk wychodzi z modułu, tak samo jak
    /// przy uderzeniu pałką.
    func playZone(_ zoneIndex: Int) {
        guard let note = auditionNote(forZone: zoneIndex) else { return }
        if playNote(note) { flagPlaying(zoneIndex) }
    }

    /// Zwraca `true`, gdy nuta naprawdę wyszła na kabel.
    @discardableResult
    func playNote(_ note: Int) -> Bool {
        guard (0...127).contains(note) else { return false }
        let channel = UInt8(max(1, min(16, auditionChannel)) - 1)
        let velocity = UInt8(max(1, min(127, auditionVelocity)))

        // Zamknięcie ma sens tylko wtedy, gdy otwarcie faktycznie poszło.
        // Inaczej po terminie ważności albo w środku odczytu z programu
        // wychodziłby sam `note off` — bajt na kablu z aplikacji, która
        // właśnie miała milczeć.
        guard sendShort([0x90 | channel, UInt8(note), velocity]) else { return false }

        // Bęben wybrzmiewa sam, ale nuta bez zamknięcia zostawia w module
        // wiszący dźwięk — przy hi-hacie słychać to od razu. Zamknięcie idzie
        // do **tego samego** wyjścia i z pominięciem strażników: nuta już
        // poszła, więc jej niezamknięcie jest gorsze od każdego powodu,
        // dla którego mielibyśmy tego nie wysłać.
        //
        // Zamknięcie czeka w kolejce, a nie tylko w uśpionym zadaniu: gdy
        // w tych 120 ms ruszy rozmowa SysEx, musimy je wypchnąć **przed** nią.
        // Bajt nuty, który wróci echem przez Soft Thru w środek ramki, zrywa
        // odbiór — a wyglądało to jak brak odpowiedzi z modułu.
        if let destination = outputs.first(where: { $0.id == selectedOutputID })?.reference {
            pendingNoteOffs.append((bytes: [0x80 | channel, UInt8(note), 0],
                                    destination: destination))
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                self?.flushPendingNoteOffs()
            }
        }
        return true
    }

    /// Nuty czekające na swoje zamknięcie.
    private var pendingNoteOffs: [(bytes: [UInt8], destination: MIDIEndpointRef)] = []

    /// Domyka wszystkie nuty, które jeszcze czekają na `note off`.
    ///
    /// Wołane po upływie czasu wybrzmienia **i** przed każdą ramką SysEx.
    /// Kolejka jest czyszczona przed wysyłką, więc powtórne wywołanie nie
    /// wyśle niczego dwa razy.
    private func flushPendingNoteOffs() {
        guard !pendingNoteOffs.isEmpty else { return }
        let queued = pendingNoteOffs
        pendingNoteOffs.removeAll()
        for item in queued { sendRaw(item.bytes, to: item.destination) }
    }

    /// Przesłuchuje cały zestaw, pad po padzie.
    func auditionKit() {
        guard !isAuditioningKit else {
            cancelAudition()
            return
        }
        // Liczba stref z profilu, nie wpisane na sztywno 20: TD-27 ma ich 24
        // i przy nim pętla urywałaby się przed końcem zestawu.
        auditionZones(Array(profile.zoneNames.indices))
    }

    /// Gra po kolei wskazane strefy.
    ///
    /// Wspólne wejście dla „Play kit" i dla odsłuchu po próbie („Try it") —
    /// oba muszą chodzić przez ten sam licznik pokoleń, bo inaczej dwie pętle
    /// nakładają się na siebie, a „Stop" zatrzymuje tylko jedną z nich.
    func auditionZones(_ zones: [Int]) {
        guard auditionEnabled, !zones.isEmpty else { return }
        guard selectedOutputID != nil else {
            appendLog("No MIDI output selected")
            return
        }

        // Poprzedni przebieg schodzi z drogi. `cancelAudition` podbija
        // pokolenie, więc stara pętla wyjdzie przy najbliższym sprawdzeniu.
        cancelAudition()

        isAuditioningKit = true
        auditionGeneration &+= 1
        let generation = auditionGeneration
        auditionTask = Task { @MainActor [weak self] in
            for zone in zones {
                // `auditionEnabled` też: wyłączenie głośnika w trakcie chowa
                // przycisk Stop, więc bez tego warunku pętla dograłaby do
                // końca, blokując resztę programu i nie dając się przerwać.
                guard let self, self.isAuditioningKit, self.auditionEnabled,
                      !Task.isCancelled, self.auditionGeneration == generation
                else { break }
                if self.auditionNote(forZone: zone) != nil {
                    self.playZone(zone)
                    try? await Task.sleep(for: .milliseconds(420))
                }
            }
            // Tylko własny przebieg gasi flagę — inaczej zakończenie starego
            // zadania zatrzymałoby dopiero co rozpoczęte.
            guard let self, self.auditionGeneration == generation else { return }
            self.isAuditioningKit = false
            // Ostatni pad zdąży się jeszcze pokazać — `flagPlaying` zgasi go
            // sam po swoim czasie.
        }
    }

    func cancelAudition() {
        auditionGeneration &+= 1
        auditionTask?.cancel()
        auditionTask = nil
        isAuditioningKit = false
        nowPlayingTask?.cancel()
        nowPlayingTask = nil
        nowPlayingZone = nil
        // Ostatnia nuta ma zostać domknięta od razu, a nie dopiero po swoich
        // 120 ms — „Stop" ma uciszać, a nie zostawiać wiszący dźwięk.
        flushPendingNoteOffs()
    }

    /// Krótka wiadomość kanałowa — trzy bajty, bez SysEx.
    ///
    /// Osobno od `sendSysEx`, bo nut przy odsłuchu leci dużo i nie mają
    /// czego szukać w logu komunikacji — zalałyby go tak, jak kiedyś zalewał
    /// go odczyt kitu.
    @discardableResult
    private func sendShort(_ bytes: [UInt8]) -> Bool {
        // Nut nie wysyłamy w środku odczytu ani zapisu: gdy moduł ma włączone
        // Soft Thru, echo nuty wpada w niedokończoną ramkę SysEx i cały
        // odczyt trzeba zaczynać od nowa. Pytamy o `isBusyWithSysEx`, a nie
        // o `isOperationInProgress`, bo to drugie zawiera już sam odsłuch.
        guard !isBusyWithSysEx else { return false }
        guard !isBlockedByExpiry else { return false }
        guard
            let selectedOutputID,
            let destination = outputs.first(where: { $0.id == selectedOutputID })
        else { return false }

        return sendRaw(bytes, to: destination.reference)
    }

    /// Trzy bajty prosto do wskazanego wyjścia, bez żadnych warunków.
    ///
    /// Zwraca, czy pakiet **naprawdę** poszedł. Odsłuch po tym pozna, czy
    /// wolno zapalić pad: rozbłysk przy ciszy w słuchawkach jest gorszy niż
    /// jego brak.
    @discardableResult
    private func sendRaw(_ bytes: [UInt8], to destination: MIDIEndpointRef) -> Bool {
        var packetList = MIDIPacketList()
        let packet = MIDIPacketListInit(&packetList)

        var added = false
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress, !buffer.isEmpty else { return }
            added = MIDIPacketListAdd(
                &packetList,
                MemoryLayout<MIDIPacketList>.size,
                packet,
                0,
                buffer.count,
                base
            ) != nil
        }
        guard added else { return false }
        return MIDISend(outputPort, destination, &packetList) == noErr
    }

    // MARK: - Ustawienia triggerów

    /// Czyta ustawienia wszystkich dziesięciu wejść.
    ///
    /// Mapa adresów pochodzi ze zrzutu z żywego modułu i została sprawdzona
    /// przez porównanie z jego ekranem: blok wspólny pod `02 00 00 20`,
    /// a potem po jednym bloku na wejście, co 128 adresów.
    ///
    /// **Wyłącznie odczyt.** Zapis dochodzi dopiero wtedy, gdy wartości na
    /// ekranie programu zgodzą się co do liczby z tym, co pokazuje moduł.
    func readTriggerSettings() {
        guard profile.hasVerifiedMap else {
            appendLog(
                "\(profile.displayName): address map not verified — "
                    + "this is read only. Use “Probe kit area” in the Log tab."
            )
            status = "\(profile.displayName): read only"
            return
        }
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }
        guard selectedOutputID != nil else {
            appendLog("No MIDI output selected")
            return
        }

        triggers = []
        triggerCommon = nil
        isReadingTriggers = true
        readPhase = .triggerCommon
        status = "Reading trigger settings…"
        appendLog("TRIGGERS: reading (read only)")
        sendRQ1(
            address: [0x02, 0x00, 0x00, 0x20],
            size: [0x00, 0x00, 0x00, 0x20]
        )

        // Watchdog: liczy bezczynność, tak samo jak przy odczycie kitu.
        Task { @MainActor [weak self] in
            var lastCount = -1
            var idleSeconds = 0
            while true {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                guard let self, self.isReadingTriggers else { return }

                if self.triggers.count == lastCount {
                    idleSeconds += 1
                } else {
                    lastCount = self.triggers.count
                    idleSeconds = 0
                }
                guard idleSeconds >= 6 else { continue }

                self.isReadingTriggers = false
                // Niepełny odczyt kasujemy: tabela z siedmioma wierszami
                // wygląda jak komplet i nikt by nie zauważył, że brakuje
                // trzech wejść.
                self.triggers = []
                self.readPhase = .idle
                self.status = "Trigger read aborted"
                self.appendLog("ABORTED: triggers — no reply for 6 s")
                return
            }
        }
    }

    private func requestTriggerInput(_ input: Int) {
        sendRQ1(
            address: addBase128(
                [0x02, 0x00, 0x00, 0x00],
                offset: encodeBase128(input * 0x80)
            ),
            // Ten sam rozmiar, którym zapytał zrzut i na który moduł
            // odpowiedział — nie ma powodu próbować innego.
            size: [0x00, 0x00, 0x00, 0x20]
        )
    }

    // MARK: - Zrzut ustawień modułu

    /// Czyta na ślepo obszar ustawień modułu i wypisuje surowe bajty do logu.
    ///
    /// Kity siedzą pod `03 00 00 00`, a numer bieżącego kitu — jedyne, co
    /// z obszaru ustawień znamy — pod `00 00 00 00`. Reszty mapy nie mamy,
    /// więc jedyny sposób, żeby ją poznać, to zapytać po kolei i porównać
    /// odpowiedzi z tym, co moduł pokazuje na swoim ekranie.
    ///
    /// To **wyłącznie odczyt**. Nic tu nie zapisuje.
    /// Zrzut surowych bajtów z obszaru **jednego kitu**.
    ///
    /// Do rozpoznania układu pamięci nieznanego modułu. Dokładnie tą drogą
    /// powstała mapa triggerów TD-17: prosimy o kolejne kawałki, wypisujemy
    /// je szesnastkowo do logu i porównujemy z tym, co moduł pokazuje na
    /// swoim ekranie. Zgadywanie offsetów z dokumentacji daje mapę, której
    /// nikt nie potwierdził — a pod niepotwierdzony adres nie wolno pisać.
    ///
    /// **Wyłącznie odczyt.** Nie wysyła ani jednego DT1.
    func probeKitArea() {
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }
        guard selectedOutputID != nil else {
            appendLog("No MIDI output selected")
            return
        }
        // Przy nieznanej mapie numer bieżącego kitu też jest nieznany —
        // odczyt strukturalny jest wtedy wyłączony. Sonda jest jedynym
        // narzędziem, jakie zostaje, więc nie może od niego zależeć: bez
        // numeru bierzemy kit 1, czyli sam początek obszaru.
        let kitNumber = currentKitNumber ?? 1
        let base = kitAddress(kitIndex: kitNumber - 1)
        isDumpingSetup = true
        setupDumpActive = true
        status = "Probing the kit area…"
        appendLog(
            "KIT PROBE: \(profile.displayName), kit \(kitNumber)"
                + (currentKitNumber == nil ? " (assumed)" : "")
                + ", base \(hex(base)) — read only"
        )

        probeTask = Task { @MainActor [weak self] in
            // Odstęp między kitami to 0x8000 w bazie 128; tyle wystarczy,
            // żeby objąć cały jeden kit i nie wejść w następny.
            let span = 0x8000
            let chunk = 0x20
            var answered = 0
            var scanned = 0

            // `defer` zamiast sprzątania na końcu pętli: przerwanie w środku
            // — przyciskiem Stop, zniknięciem obiektu, czymkolwiek — musi
            // opuścić obie flagi. Zostawiona `isDumpingSetup` znaczy, że
            // program do końca swojego życia uważa, że coś trwa, i odmawia
            // wszystkiego.
            defer {
                self?.setupDumpActive = false
                self?.isDumpingSetup = false
                self?.probeTask = nil
            }

            for offset in stride(from: 0, to: span, by: chunk) {
                guard let manager = self,
                      manager.setupDumpActive,
                      !Task.isCancelled
                else { break }

                scanned += 1
                manager.setupDumpReplied = false
                manager.sendRQ1(
                    address: manager.addBase128(
                        base,
                        offset: manager.encodeBase128(offset)
                    ),
                    size: manager.encodeBase128(chunk)
                )
                for _ in 0..<6 {
                    try? await Task.sleep(for: .milliseconds(40))
                    if manager.setupDumpReplied { break }
                }
                if manager.setupDumpReplied { answered += 1 }

                // Nieznany obszar potrafi milczeć na wszystko. Po stu
                // kolejnych pytaniach bez jednej odpowiedzi nie ma sensu
                // trzymać programu przez następne cztery minuty.
                if scanned >= 100, answered == 0 {
                    manager.appendLog(
                        "KIT PROBE: no reply to the first 100 requests — "
                            + "the module does not expose this area, or the "
                            + "base address is wrong. Stopping."
                    )
                    break
                }

                if scanned % 128 == 0 {
                    manager.status =
                        "Probing… \(scanned)/\(span / chunk), \(answered) answered"
                }
            }

            guard let self else { return }
            self.status = "Kit probe finished"
            self.appendLog(
                "KIT PROBE: finished, \(answered) of \(scanned) block(s) "
                    + "answered. Copy the log and send it over."
            )
        }
    }

    /// Przerywa zrzut surowych bajtów — sondę albo zrzut ustawień.
    ///
    /// Obie operacje dzielą `setupDumpActive` i `isDumpingSetup`, więc
    /// przerwanie musi gasić jedno i drugie niezależnie od tego, która
    /// z nich trwa. Zostawiona flaga blokuje cały program.
    func cancelProbe() {
        probeTask?.cancel()
        probeTask = nil
        setupDumpActive = false
        isDumpingSetup = false
        status = "Stopped"
        appendLog("Dump stopped by the user")
    }

    private var probeTask: Task<Void, Never>?

    func dumpModuleSetup() {
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }
        guard selectedOutputID != nil else {
            appendLog("No MIDI output selected")
            return
        }

        isDumpingSetup = true
        setupDumpActive = true
        status = "Dumping module setup…"
        appendLog("SETUP DUMP: reading the module setup area (read only)")

        Task { @MainActor [weak self] in
            // Zasięg dobrany po pierwszym zrzucie ze sprzętu:
            // • 00 — sam numer kitu, jeden bajt,
            // • 01 — ustawienia ogólne, bloki co 128,
            // • 02 — triggery: blok wspólny plus blok na wejście co 128.
            //   Modułowi odpowiedziało siedem wejść, a fizycznych jest
            //   dziesięć — reszta leżała poza zasięgiem pierwszego skanu.
            let roots: [([UInt8], Int)] = [
                ([0x00, 0x00, 0x00, 0x00], 0x100),
                ([0x01, 0x00, 0x00, 0x00], 0x800),
                ([0x02, 0x00, 0x00, 0x00], 0x1000)
            ]
            let chunk = 0x20
            var answered = 0

            // Sprzątanie na każdym wyjściu, tak samo jak w sondzie. Bez tego
            // przerwanie zrzutu w środku zostawiało `isDumpingSetup`
            // podniesione na zawsze — a wtedy program do końca swojego życia
            // uważa, że coś trwa, i odmawia wszystkiego.
            defer {
                self?.setupDumpActive = false
                self?.isDumpingSetup = false
            }

            for (root, span) in roots {
                // Jedno rozpakowanie na pętlę: powtórne `guard let self`
                // w środku dotyczyłoby już rozpakowanej wartości i nie
                // przeszłoby kompilacji.
                guard let manager = self, manager.setupDumpActive else { break }
                manager.appendLog("SETUP DUMP: block \(manager.hex(root))")

                for offset in stride(from: 0, to: span, by: chunk) {
                    guard manager.setupDumpActive, !Task.isCancelled else { break }
                    manager.setupDumpReplied = false
                    manager.sendRQ1(
                        address: manager.addBase128(
                            root,
                            offset: manager.encodeBase128(offset)
                        ),
                        size: manager.encodeBase128(chunk)
                    )

                    // Nieistniejący adres nie odpowiada w ogóle, więc każdy
                    // krok ma własny krótki limit zamiast jednego wspólnego.
                    // Moduł odpowiada w kilkadziesiąt milisekund, więc 240 ms
                    // z zapasem wystarczy — przy 200 adresach każde zbędne
                    // sto milisekund to dwadzieścia sekund czekania.
                    for _ in 0..<6 {
                        try? await Task.sleep(for: .milliseconds(40))
                        if manager.setupDumpReplied { break }
                    }
                    if manager.setupDumpReplied { answered += 1 }
                }
            }

            guard let self else { return }
            self.status = "Setup dump finished"
            self.appendLog(
                "SETUP DUMP: finished, \(answered) block(s) answered"
            )
        }
    }

    // MARK: - Lista kitów

    /// Dociąga listę kitów, gdy tylko moduł przestanie być zajęty.
    ///
    /// Raz na sesję. Zadanie ponawia się co pół sekundy, dopóki trwa cokolwiek
    /// innego — pierwszy odczyt kitu ma pierwszeństwo, bo lista jest wygodą
    /// przy wybieraniu, a nie warunkiem pracy.
    private func scheduleKitListScan() {
        // `kitNames` nie nadaje się na warunek: zwykły odczyt kitu dopisuje
        // do niego nazwę bieżącego kitu, więc słownik nigdy nie jest pusty
        // w momencie, w którym to sprawdzamy.
        guard !kitListScanDone else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled, !self.kitListScanDone else { return }
            // Moduł mógł zniknąć, odkąd zadanie powstało — bez tego skan
            // waliłby zapytaniami w cudze urządzenie i blokował program
            // do czasu watchdoga.
            guard self.moduleAvailable, self.connectedInput != nil else { return }
            // Pierwszy odczyt kitu ma pierwszeństwo: bez niego okno jest puste,
            // a lista kitów to tylko wygoda przy wybieraniu.
            guard self.initialReadDone else {
                self.scheduleKitListScan()
                return
            }
            guard !self.isOperationInProgress else {
                // Po odczycie potrafi od razu ruszyć utrwalanie albo wysyłka.
                // Bez ponowienia lista przepadłaby na całą sesję.
                self.scheduleKitListScan()
                return
            }
            self.scanKitList()
        }
    }

    /// Odczytuje nazwy wszystkich stu kitów.
    ///
    /// Jedno zapytanie na kit, jedno po drugim — moduł nie umie oddać ich
    /// hurtem. Watchdog jest ten sam co przy odczycie kitu, więc martwe łącze
    /// nie zawiesi tego na zawsze.
    func scanKitList() {
        guard profile.hasVerifiedMap else {
            // Zaznaczamy jako zrobione, żeby każde kolejne odświeżenie
            // urządzeń nie zaczynało tego od nowa.
            kitListScanDone = true
            appendLog(
                "\(profile.displayName): kit names cannot be read until the "
                    + "address map is confirmed."
            )
            return
        }
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }

        kitListScanTask?.cancel()
        kitListScanGeneration &+= 1
        let generation = kitListScanGeneration
        kitListScanDone = true
        isScanningKitList = true
        kitListProgress = 0
        readPhase = .kitListName(0)
        status = "Reading kit list…"
        appendLog("Reading the names of all kits")
        requestKitName(kitIndex: 0)

        // Watchdog: liczy bezczynność, tak samo jak przy odczycie kitu.
        // Pokolenie pilnuje, żeby stary watchdog nie przerwał nowego skanu.
        kitListScanTask = Task { @MainActor [weak self] in
            var lastProgress = -1
            var idleSeconds = 0

            while true {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                guard let self, self.isScanningKitList,
                      self.kitListScanGeneration == generation
                else { return }

                if self.kitListProgress == lastProgress {
                    idleSeconds += 1
                } else {
                    lastProgress = self.kitListProgress
                    idleSeconds = 0
                }
                guard idleSeconds >= self.readInactivityTimeoutSeconds else {
                    continue
                }

                self.isScanningKitList = false
                self.kitListProgress = 0
                // Skan padł — pozwalamy spróbować jeszcze raz.
                self.kitListScanDone = false
                self.readPhase = .idle
                self.status = "Kit list read aborted"
                self.appendLog(
                    "ABORTED: kit list — no reply for "
                        + "\(self.readInactivityTimeoutSeconds) s"
                )
                return
            }
        }
    }

    // MARK: - Przełączanie kitu w module

    func selectPreviousKit() {
        guard let current = displayedKitNumber else { return }
        selectKit(current - 1)
    }

    func selectNextKit() {
        guard let current = displayedKitNumber else { return }
        selectKit(current + 1)
    }

    /// Przełącza kit w module.
    ///
    /// Numer bieżącego kitu leży pod adresem `00 00 00 00` — dokładnie tym,
    /// spod którego czytamy go przy każdym odczycie. Zapis pod ten sam adres
    /// przestawia moduł, więc nie trzeba zgadywać kanału MIDI, na którym
    /// przyjmuje Program Change.
    ///
    /// Po potwierdzeniu leci pełny odczyt, bo w module stoi już inny kit.
    func selectKit(_ number: Int) {
        guard profile.hasVerifiedMap else {
            appendLog(
                "\(profile.displayName): address map not verified — "
                    + "this is read only. Use “Probe kit area” in the Log tab."
            )
            status = "\(profile.displayName): read only"
            return
        }
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }
        guard (1...profile.kitCount).contains(number) else { return }
        guard number != displayedKitNumber else { return }

        // Odroczony odczyt poprzedniego wyboru jest już nieaktualny.
        deferredFullReadTask?.cancel()
        automaticKitReadTask?.cancel()

        let index = number - 1
        sendDT1(address: [0x00, 0x00, 0x00, 0x00], data: [UInt8(index)])
        appendLog("Switching the module to kit \(number); waiting for confirmation…")
        status = "Switching to kit \(number)…"
        isWriting = true
        readPhase = .kitSelectVerify(index)

        // Pół sekundy, a nie 180 ms jak przy zwykłym parametrze: przeładowanie
        // całego kitu jest w module dużo cięższe niż zapis jednej wartości,
        // a odpytany za wcześnie potrafi jeszcze zgłosić stary numer.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, self.readPhase == .kitSelectVerify(index) else { return }
            self.sendRQ1(
                address: [0x00, 0x00, 0x00, 0x00],
                size: [0x00, 0x00, 0x00, 0x01]
            )
        }
    }

    func connectSelectedInput() {
        guard !isOperationInProgress else { return }

        if let connectedInput {
            MIDIPortDisconnectSource(inputPort, connectedInput)
            self.connectedInput = nil
        }

        guard
            let selectedInputID,
            let endpoint = inputs.first(where: { $0.id == selectedInputID })
        else {
            return
        }

        let result = MIDIPortConnectSource(inputPort, endpoint.reference, nil)
        if result == noErr {
            connectedInput = endpoint.reference
            appendLog("Input: \(endpoint.name)")
        } else {
            appendLog("CoreMIDI input connection error: \(result)")
        }
    }

    func sendIdentityRequest() {
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }
        // Każde pytanie waliduje od nowa. Bez tego flaga raz zapalona przez
        // dowolny sprzęt Rolanda na łączu świeciłaby do końca sesji — także
        // po wyłączeniu modułu.
        rolandIdentityDetected = false
        sendSysEx([0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7])
    }

    /// Kasuje cały stan opisujący jeden kit.
    ///
    /// Wyciągnięte z `readCurrentKit`, bo potrzebuje tego również
    /// przełączenie modułu: dane z TD-17 wyświetlone pod nagłówkiem TD-27
    /// wprowadzają w błąd, a zostawione drafty potrafią uzbroić warunki
    /// wstępne zapisu wartościami z **innego** modułu.
    private func resetKitState() {
        currentKitNumber = nil
        currentKitName = nil
        zones = []
        layers = []
        vEdits = []
        subVEdits = []
        mixInfos = []
        ambience = nil
        reverb = nil
        mfx = nil
        masterComp = nil
        kitCommon = nil
        midiNotes = []
        mainLevelDrafts = [:]
        subLevelDrafts = [:]
        mainInstrumentDrafts = [:]
        subInstrumentDrafts = [:]
        subEnabledDrafts = [:]
        subLayerTypeDrafts = [:]
        subFadePointDrafts = [:]
        mainTuningDrafts = [:]
        subTuningDrafts = [:]
        mainVEditSecondDrafts = [:]
        subVEditSecondDrafts = [:]
        mainVEditThirdDrafts = [:]
        subVEditThirdDrafts = [:]
        panDrafts = [:]
        ambienceSendDrafts = [:]
        mfxSendDrafts = [:]
        reverbSendDrafts = [:]
        eqEnabledDrafts = [:]
        eqLowGainDrafts = [:]
        eqMidGainDrafts = [:]
        eqHighGainDrafts = [:]
        eqLowFrequencyDrafts = [:]
        eqMidFrequencyDrafts = [:]
        eqMidQDrafts = [:]
        eqHighFrequencyDrafts = [:]
        ambienceEnabledDraft = false
        ambienceLevelDraft = -601
        ambienceRoomTypeDraft = 0
        ambienceRoomSizeDraft = 0
        ambienceRoomShapeDraft = 0
        ambienceWallTypeDraft = 0
        ambienceMicPositionDraft = 0
        reverbEnabledDraft = false
        reverbTypeDraft = 0
        reverbParameterDrafts = [:]
        reverbLevelDraft = -601
        mfxEnabledDraft = false
        mfxTypeDraft = 0
        mfxLevelDraft = -601
        mfxParameterDrafts = [:]
        masterCompEnabledDraft = false
        masterCompTypeDraft = 0
        masterCompParameterDrafts = [:]
        pedalHiHatVolumeDraft = -601
        crossStickVolumeDraft = -601
        crossStickEnabledDraft = false
        hiHatBalanceDraft = 0
        midiNoteDrafts = [:]
        pendingLayerCommon = nil
    }

    func readCurrentKit() {
        guard !isOperationInProgress else {
            nextReadShouldBeQuick = false
            appendLog("A read or write is already in progress")
            return
        }
        // Czytanie kitu adresami wziętymi z innego modułu daje śmieci,
        // a śmieci pokazane jako wartości parametrów są gorsze niż uczciwe
        // „nie wiem". Od poznania nieznanej mapy jest sonda.
        guard profile.hasVerifiedMap else {
            nextReadShouldBeQuick = false
            appendLog(
                "\(profile.displayName): the kit layout is not mapped yet. "
                    + "Use “Probe kit area” in the Log tab and send the log over."
            )
            status = "\(profile.displayName): kit layout not mapped yet"
            return
        }

        readGeneration += 1
        let generation = readGeneration
        isQuickRead = nextReadShouldBeQuick
        nextReadShouldBeQuick = false
        resetKitState()
        isWriting = false
        pendingLayerCommon = nil
        isReadingKit = true
        status = "Reading the complete kit data…"
        readPhase = .currentKit
        sendRQ1(address: [0x00, 0x00, 0x00, 0x00], size: [0x00, 0x00, 0x00, 0x01])

        // Watchdog odczytu liczy bezczynność, a nie łączny czas.
        //
        // Poprzednio był to sztywny limit 60 s na cały odczyt. Odczyt to
        // ponad 100 wymian pytanie–odpowiedź; gdy komputer jest obciążony
        // (albo gdy log urósł i zżerał czas na przerysowywanie widoku),
        // przekraczał ten limit mimo że szedł do przodu i był przerywany
        // w połowie. Teraz liczy się tylko to, czy przez 12 sekund nie
        // zmieniła się faza — czyli czy odczyt naprawdę stanął.
        Task { @MainActor [weak self] in
            var lastPhase: ReadPhase?
            var idleSeconds = 0

            while true {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                guard let self,
                      self.isReadingKit,
                      self.readGeneration == generation
                else { return }

                if self.readPhase == lastPhase {
                    idleSeconds += 1
                } else {
                    lastPhase = self.readPhase
                    idleSeconds = 0
                }

                guard idleSeconds >= self.readInactivityTimeoutSeconds else {
                    continue
                }

                self.isReadingKit = false
                self.readPhase = .idle
                self.stabilizeAfterCurrentRead = false
                // Odczyt, który padł, nie może zużywać jedynej automatycznej
                // próby — inaczej „Odśwież" nie miałby czego wznowić.
                self.initialReadDone = false
                self.status = "Read aborted — the module stopped responding"
                self.appendLog(
                    "ABORTED: no reply for "
                        + "\(self.readInactivityTimeoutSeconds) s "
                        + "(phase: \(lastPhase.map(String.init(describing:)) ?? "?"))"
                )
                return
            }
        }
    }

    /// Pilnuje, żeby brak odpowiedzi weryfikacyjnej nie zablokował aplikacji.
    ///
    /// `isWriting` jest kasowane wyłącznie wtedy, gdy przyjdzie odpowiedź
    /// weryfikacyjna — obojętne, czy zgodna, czy nie. Jeśli moduł nie odpowie
    /// w ogóle (odpięty kabel, zgubiony pakiet, zmiana kitu w trakcie zapisu),
    /// bez tego watchdoga flaga zostawała ustawiona na stałe, a
    /// `isOperationInProgress` blokowało każdą kolejną operację — łącznie
    /// z ponownym odczytem, który jako jedyny potrafił ją skasować.
    private func scheduleWriteWatchdog() {
        let generation = writeGeneration
        let seconds = writeVerificationTimeoutSeconds
        // Jeśli ostatnia wysyłka w ogóle nie doszła do skutku (brak wyjścia
        // MIDI, błąd CoreMIDI), nie ma na co czekać — moduł nie dostał
        // pytania, więc nie odpowie. Przerywamy od razu zamiast po 8 s.
        let sendFailed = lastSendFailed

        Task { @MainActor [weak self] in
            if !sendFailed {
                try? await Task.sleep(for: .seconds(seconds))
            }
            guard let self,
                  self.isWriting,
                  self.writeGeneration == generation
            else { return }
            self.abortStalledWrite(sendFailed: sendFailed)
        }
    }

    private func abortStalledWrite(sendFailed: Bool = false) {
        let phase = readPhase
        isWriting = false
        readPhase = .idle
        pendingLayerCommon = nil

        if sendFailed {
            status = "Write aborted — the data could not be sent"
            appendLog(
                "ABORTED: the message was never sent (phase: \(phase)). "
                    + "Check the MIDI output selection and the connection to the module."
            )
        } else {
            status = "Write aborted — the module did not confirm the change"
            appendLog(
                "ABORTED: no write confirmation within "
                    + "\(writeVerificationTimeoutSeconds) s (phase: \(phase)). "
                    + "Check the MIDI connection and read the kit again."
            )
        }

        if isBatchRestoring {
            isBatchRestoring = false
            batchRestoreProgress = nil
            batchRestoreActions = []
            appendLog("RESTORE ALL: aborted — the module did not confirm the write")
        }
    }

    func writeKitVolume() {
        guard !isWriting else { return }
        guard let currentKitNumber else {
            appendLog("Read the current kit first")
            return
        }

        let tenths = min(60, max(-600, Int((kitVolumeDraft * 10).rounded())))
        let address = kitVolumeAddress(kitIndex: currentKitNumber - 1)
        sendDT1(address: address, data: encodeSigned16Nibbles(tenths))
        appendLog("Write Kit volume: \(levelText(tenths)); waiting for verification…")
        status = "Verifying Kit volume…"
        isWriting = true
        readPhase = .kitVolumeVerify(tenths)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self, self.readPhase == .kitVolumeVerify(tenths) else { return }
            self.requestKitCommon(kitIndex: currentKitNumber - 1)
        }
    }

    func writeZoneLevel(zoneIndex: Int, isSub: Bool) {
        guard !isWriting else { return }
        guard let currentKitNumber else {
            appendLog("Read the current kit first")
            return
        }
        let drafts = isSub ? subLevelDrafts : mainLevelDrafts
        guard let draft = drafts[zoneIndex], zoneNames.indices.contains(zoneIndex) else {
            appendLog("No level value for the selected zone")
            return
        }

        let rawTenths = Int((draft * 10).rounded())
        let tenths = rawTenths <= -601
            ? -601
            : min(60, max(-600, rawTenths))
        let baseAddress = isSub
            ? layerInstrumentAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
            : zoneAddress(index: zoneIndex, kitIndex: currentKitNumber - 1)
        let levelAddress = addBase128(baseAddress, offset: [0x00, 0x00, 0x04])
        sendDT1(address: levelAddress, data: encodeSigned16Nibbles(tenths))

        let layerName = isSub ? "SUB" : "MAIN"
        appendLog(
            "Write \(layerName) \(zoneNames[zoneIndex]) Level: "
                + "\(levelText(tenths)); waiting for verification…"
        )
        status = "Verifying \(layerName) \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .zoneLevelVerify(zoneIndex, tenths, isSub)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .zoneLevelVerify(zoneIndex, tenths, isSub)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x09]
            )
        }
    }

    func writeInstrument(zoneIndex: Int, isSub: Bool) {
        guard !isWriting else { return }
        guard let currentKitNumber else {
            appendLog("Read the current kit first")
            return
        }
        let drafts = isSub ? subInstrumentDrafts : mainInstrumentDrafts
        guard let instrumentID = drafts[zoneIndex],
              TD17InstrumentCatalog.instruments.indices.contains(instrumentID),
              zoneNames.indices.contains(zoneIndex)
        else {
            appendLog("Invalid instrument for the selected zone")
            return
        }

        let baseAddress = isSub
            ? layerInstrumentAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
            : zoneAddress(index: zoneIndex, kitIndex: currentKitNumber - 1)
        sendDT1(
            address: baseAddress,
            data: encodeUnsigned16Nibbles(instrumentID)
        )

        let layerName = isSub ? "SUB" : "MAIN"
        let definition = TD17InstrumentCatalog.instruments[instrumentID]
        appendLog(
            "Write \(layerName) \(zoneNames[zoneIndex]) Instrument: "
                + "\(definition.name) (#\(instrumentID)); waiting for verification…"
        )
        status = "Verifying instrument \(layerName) \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .instrumentVerify(zoneIndex, instrumentID, isSub)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .instrumentVerify(zoneIndex, instrumentID, isSub)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x09]
            )
        }
    }

    func writeLayerSettings(zoneIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              let enabled = subEnabledDrafts[zoneIndex],
              let type = subLayerTypeDrafts[zoneIndex],
              let fadePoint = subFadePointDrafts[zoneIndex],
              zoneNames.indices.contains(zoneIndex),
              (0...3).contains(type),
              // Zakres składowania, nie edycyjny. Przy warstwie MIX i SWITCH
              // moduł trzyma tu 0, a zapis przyjmował dopiero 1 — samo
              // włączenie warstwy SUB na takim padzie podnosiło więc Fade
              // Point z 0 na 1: wartość, której użytkownik nie dotykał i która
              // nie pojawiła się na liście zmian. Gdy moduł wracał do zera,
              // weryfikacja nie zgadzała się z wysłaną wartością i cała reszta
              // serii szła do kosza.
              Self.fadePointStorageRange.contains(fadePoint)
        else {
            appendLog("Invalid SUB layer settings")
            return
        }

        let baseAddress = layerCommonAddress(
            zoneIndex: zoneIndex,
            kitIndex: currentKitNumber - 1
        )
        let settingsAddress = addBase128(
            baseAddress,
            offset: [0x00, 0x00, 0x02]
        )
        sendDT1(
            address: settingsAddress,
            data: [enabled ? 1 : 0, UInt8(type), UInt8(fadePoint)]
        )

        let typeNames = TD17LayerCatalog.types
        appendLog(
            "Write SUB \(zoneNames[zoneIndex]) Layer: "
                + "\(enabled ? "ON" : "OFF"), \(typeNames[type]), Fade \(fadePoint); "
                + "waiting for verification…"
        )
        status = "Verifying SUB layering \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .layerSettingsVerify(zoneIndex, enabled, type, fadePoint)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .layerSettingsVerify(
                    zoneIndex,
                    enabled,
                    type,
                    fadePoint
                  )
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x1C]
            )
        }
    }

    func writeVEditTuning(zoneIndex: Int, isSub: Bool) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              zoneNames.indices.contains(zoneIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let drafts = isSub ? subTuningDrafts : mainTuningDrafts
        let edit = isSub
            ? subVEdits.first(where: { $0.zoneIndex == zoneIndex })
            : vEdits.first(where: { $0.zoneIndex == zoneIndex })
        guard let edit, let tuning = drafts[zoneIndex] else {
            appendLog("Missing value of the first V-Edit parameter")
            return
        }
        let allowedRange: ClosedRange<Int> = edit.supportsTuning
            ? -100...100
            : (edit.isCymbal ? 0...78 : -4800...4800)
        guard allowedRange.contains(tuning) else {
            appendLog("Invalid value of the first V-Edit parameter")
            return
        }

        let baseAddress = isSub
            ? subVEditAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
            : vEditAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
        let tuningAddress = addBase128(
            baseAddress,
            offset: [0x00, 0x00, 0x01]
        )
        sendDT1(address: tuningAddress, data: encodeSigned16Nibbles(tuning))

        let layerName = isSub ? "SUB" : "MAIN"
        let parameterName = edit.supportsTuning
            ? "Tuning"
            : (edit.isCymbal ? "Size" : "Pitch")
        appendLog(
            "Write V-EDIT \(layerName) \(zoneNames[zoneIndex]) \(parameterName): "
                + "\(signedText(tuning)); waiting for verification…"
        )
        status = "Verifying V-Edit \(layerName) \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .vEditTuningVerify(zoneIndex, tuning, isSub)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .vEditTuningVerify(zoneIndex, tuning, isSub)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x21]
            )
        }
    }

    func writeVEditParameter(zoneIndex: Int, parameter: Int, isSub: Bool) {
        guard !isWriting, parameter == 2 || parameter == 3 else { return }
        guard let currentKitNumber,
              let edit = isSub
                ? subVEdits.first(where: { $0.zoneIndex == zoneIndex })
                : vEdits.first(where: { $0.zoneIndex == zoneIndex })
        else {
            appendLog("Read the current kit first")
            return
        }

        let drafts = parameter == 2
            ? (isSub ? subVEditSecondDrafts : mainVEditSecondDrafts)
            : (isSub ? subVEditThirdDrafts : mainVEditThirdDrafts)
        guard let value = drafts[zoneIndex],
              vEditRange(group: edit.instrumentGroup, parameter: parameter)
                .contains(value)
        else {
            appendLog("Invalid V-Edit parameter value \(parameter)")
            return
        }

        let baseAddress = isSub
            ? subVEditAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
            : vEditAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
        let parameterOffset = parameter == 2 ? 5 : 9
        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, UInt8(parameterOffset)]
            ),
            data: encodeSigned16Nibbles(value)
        )

        let layerName = isSub ? "SUB" : "MAIN"
        appendLog(
            "Write V-EDIT \(layerName) \(zoneNames[zoneIndex]) "
                + "Param \(parameter): \(value); waiting for verification…"
        )
        status = "Verifying V-Edit \(layerName) \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .vEditParameterVerify(zoneIndex, parameter, value, isSub)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .vEditParameterVerify(
                    zoneIndex,
                    parameter,
                    value,
                    isSub
                  )
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x21]
            )
        }
    }

    func writePan(zoneIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              zoneNames.indices.contains(zoneIndex),
              let pan = panDrafts[zoneIndex],
              (-64...63).contains(pan)
        else {
            appendLog("Invalid pan value")
            return
        }

        let baseAddress = layerCommonAddress(
            zoneIndex: zoneIndex,
            kitIndex: currentKitNumber - 1
        )
        sendDT1(address: baseAddress, data: encodeSignedByteNibbles(pan))

        appendLog(
            "Write \(zoneNames[zoneIndex]) Pan: \(panText(pan)); "
                + "waiting for verification…"
        )
        status = "Verifying pan \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .panVerify(zoneIndex, pan)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .panVerify(zoneIndex, pan)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x1C]
            )
        }
    }

    func writeAmbienceSend(zoneIndex: Int) {
        writeMixSend(zoneIndex: zoneIndex, sendIndex: 0)
    }

    func writeMFXSend(zoneIndex: Int) {
        writeMixSend(zoneIndex: zoneIndex, sendIndex: 1)
    }

    func writeReverbSend(zoneIndex: Int) {
        writeMixSend(zoneIndex: zoneIndex, sendIndex: 2)
    }

    private func writeMixSend(zoneIndex: Int, sendIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              zoneNames.indices.contains(zoneIndex),
              (0...2).contains(sendIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let drafts = [
            ambienceSendDrafts,
            mfxSendDrafts,
            reverbSendDrafts
        ]
        guard let value = drafts[sendIndex][zoneIndex],
              Self.sendLevelRange.contains(value)
        else {
            appendLog("Invalid effect send value")
            return
        }

        let baseAddress = layerCommonAddress(
            zoneIndex: zoneIndex,
            kitIndex: currentKitNumber - 1
        )
        let offsets = [16, 20, 24]
        let names = ["Ambience", "MFX", "Reverb"]
        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, UInt8(offsets[sendIndex])]
            ),
            data: encodeSigned16Nibbles(value)
        )

        appendLog(
            "Write \(zoneNames[zoneIndex]) \(names[sendIndex]) Send: "
                + "\(levelText(value)); waiting for verification…"
        )
        status = "Verifying \(names[sendIndex]) Send \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .mixSendVerify(zoneIndex, sendIndex, value)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .mixSendVerify(zoneIndex, sendIndex, value)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x1C]
            )
        }
    }

    func writeEQEnabled(zoneIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              zoneNames.indices.contains(zoneIndex),
              let enabled = eqEnabledDrafts[zoneIndex]
        else {
            appendLog("Read the current kit first")
            return
        }

        let baseAddress = layerCommonAddress(
            zoneIndex: zoneIndex,
            kitIndex: currentKitNumber - 1
        )
        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, 0x05]
            ),
            data: [enabled ? 1 : 0]
        )

        appendLog(
            "Write \(zoneNames[zoneIndex]) Pad EQ: "
                + "\(enabled ? "ON" : "OFF"); waiting for verification…"
        )
        status = "Verifying Pad EQ \(zoneNames[zoneIndex])…"
        isWriting = true
        readPhase = .eqEnabledVerify(zoneIndex, enabled)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .eqEnabledVerify(zoneIndex, enabled)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x1C]
            )
        }
    }

    func writeEQGain(zoneIndex: Int, bandIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              zoneNames.indices.contains(zoneIndex),
              (0...2).contains(bandIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let drafts = [eqLowGainDrafts, eqMidGainDrafts, eqHighGainDrafts]
        guard let gain = drafts[bandIndex][zoneIndex],
              (-15...15).contains(gain)
        else {
            appendLog("Invalid Pad EQ gain value")
            return
        }

        let baseAddress = layerCommonAddress(
            zoneIndex: zoneIndex,
            kitIndex: currentKitNumber - 1
        )
        let offsets = [7, 11, 14]
        let names = ["LOW", "MID", "HIGH"]
        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, UInt8(offsets[bandIndex])]
            ),
            data: encodeSignedByteNibbles(gain)
        )

        appendLog(
            "Write \(zoneNames[zoneIndex]) Pad EQ \(names[bandIndex]) Gain: "
                + "\(signedDBText(gain)); waiting for verification…"
        )
        status = "Verifying Pad EQ \(names[bandIndex])…"
        isWriting = true
        readPhase = .eqGainVerify(zoneIndex, bandIndex, gain)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .eqGainVerify(zoneIndex, bandIndex, gain)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x1C]
            )
        }
    }

    func writeEQShape(zoneIndex: Int, parameterIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              zoneNames.indices.contains(zoneIndex),
              (0...3).contains(parameterIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let drafts = [
            eqLowFrequencyDrafts,
            eqMidFrequencyDrafts,
            eqMidQDrafts,
            eqHighFrequencyDrafts
        ]
        let lists = eqShapeLists
        guard let value = drafts[parameterIndex][zoneIndex],
              lists[parameterIndex].indices.contains(value)
        else {
            appendLog("Invalid Pad EQ parameter")
            return
        }

        let baseAddress = layerCommonAddress(
            zoneIndex: zoneIndex,
            kitIndex: currentKitNumber - 1
        )
        let offsets = [6, 9, 10, 13]
        let names = ["LOW Freq", "MID Freq", "MID Q", "HIGH Freq"]
        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, UInt8(offsets[parameterIndex])]
            ),
            data: [UInt8(value)]
        )

        appendLog(
            "Write \(zoneNames[zoneIndex]) Pad EQ \(names[parameterIndex]): "
                + "\(lists[parameterIndex][value]); waiting for verification…"
        )
        status = "Verifying Pad EQ \(names[parameterIndex])…"
        isWriting = true
        readPhase = .eqShapeVerify(zoneIndex, parameterIndex, value)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .eqShapeVerify(
                      zoneIndex,
                      parameterIndex,
                      value
                  )
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x1C]
            )
        }
    }

    func writeAmbienceEnabled() {
        guard !isWriting else { return }
        guard let currentKitNumber else {
            appendLog("Read the current kit first")
            return
        }

        let address = ambienceAddress(kitIndex: currentKitNumber - 1)
        sendDT1(address: address, data: [ambienceEnabledDraft ? 1 : 0])
        appendLog(
            "Write Ambience: \(ambienceEnabledDraft ? "ON" : "OFF"); "
                + "waiting for verification…"
        )
        status = "Verifying Ambience ON/OFF…"
        isWriting = true
        readPhase = .ambienceEnabledVerify(ambienceEnabledDraft)
        verifyAmbience(after: .milliseconds(180), address: address)
    }

    func writeAmbienceLevel() {
        guard !isWriting else { return }
        guard let currentKitNumber,
              Self.effectLevelRange.contains(ambienceLevelDraft)
        else {
            appendLog("Invalid Ambience level")
            return
        }

        let baseAddress = ambienceAddress(kitIndex: currentKitNumber - 1)
        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, 0x06]
            ),
            data: encodeSigned16Nibbles(ambienceLevelDraft)
        )
        appendLog(
            "Write Ambience level: \(levelText(ambienceLevelDraft)); "
                + "waiting for verification…"
        )
        status = "Verifying Ambience level…"
        isWriting = true
        readPhase = .ambienceLevelVerify(ambienceLevelDraft)
        verifyAmbience(after: .milliseconds(180), address: baseAddress)
    }

    func writeAmbienceParameter(_ parameterIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              (0...4).contains(parameterIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let values = [
            ambienceRoomTypeDraft,
            ambienceRoomSizeDraft,
            ambienceRoomShapeDraft,
            ambienceWallTypeDraft,
            ambienceMicPositionDraft
        ]
        let value = values[parameterIndex]
        let valid = [
            TD17AmbienceCatalog.roomTypes.indices.contains(value),
            TD17AmbienceCatalog.roomSizes.indices.contains(value),
            (0...100).contains(value),
            TD17AmbienceCatalog.wallTypes.indices.contains(value),
            TD17AmbienceCatalog.micPositions.indices.contains(value)
        ][parameterIndex]
        guard valid else {
            appendLog("Invalid Ambience parameter")
            return
        }

        let baseAddress = ambienceAddress(kitIndex: currentKitNumber - 1)
        let names = ["Room Type", "Room Size", "Room Shape", "Wall Type", "Mic Position"]
        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, UInt8(parameterIndex + 1)]
            ),
            data: [UInt8(value)]
        )
        appendLog(
            "Write Ambience \(names[parameterIndex]): "
                + "\(ambienceParameterText(parameterIndex, value)); "
                + "waiting for verification…"
        )
        status = "Verifying Ambience \(names[parameterIndex])…"
        isWriting = true
        readPhase = .ambienceParameterVerify(parameterIndex, value)
        verifyAmbience(after: .milliseconds(180), address: baseAddress)
    }

    private func verifyAmbience(
        after delay: Duration,
        address: [UInt8]
    ) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self else { return }
            switch self.readPhase {
            case .ambienceEnabledVerify,
                 .ambienceLevelVerify,
                 .ambienceParameterVerify:
                self.sendRQ1(
                    address: address,
                    size: [0x00, 0x00, 0x00, 0x0A]
                )
            default:
                break
            }
        }
    }

    func writeReverb(_ parameterIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              (0...10).contains(parameterIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let baseAddress = reverbAddress(kitIndex: currentKitNumber - 1)
        let names = ["ON/OFF", "Type"]
            + TD17ReverbCatalog.parameterNames
            + ["Level"]
        let value: Int
        let offset: Int
        let data: [UInt8]

        if parameterIndex == 0 {
            value = reverbEnabledDraft ? 1 : 0
            offset = 0
            data = [UInt8(value)]
        } else if parameterIndex == 1 {
            value = reverbTypeDraft
            guard (0...4).contains(value) else {
                appendLog("Invalid Reverb type")
                return
            }
            offset = 1
            data = [UInt8(value)]
        } else if parameterIndex == 10 {
            value = reverbLevelDraft
            guard Self.effectLevelRange.contains(value) else {
                appendLog("Invalid Reverb level")
                return
            }
            offset = 10
            data = encodeSigned16Nibbles(value)
        } else {
            guard let draft = reverbParameterDrafts[parameterIndex - 2],
                  (0...127).contains(draft)
            else {
                appendLog("Invalid Reverb parameter")
                return
            }
            value = draft
            offset = parameterIndex
            data = [UInt8(value)]
        }

        sendDT1(
            address: addBase128(
                baseAddress,
                offset: [0x00, 0x00, UInt8(offset)]
            ),
            data: data
        )
        appendLog(
            "Write Reverb \(names[parameterIndex]): "
                + "\(reverbValueText(parameterIndex, value)); "
                + "waiting for verification…"
        )
        status = "Verifying Reverb \(names[parameterIndex])…"
        isWriting = true
        readPhase = .reverbVerify(parameterIndex, value)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .reverbVerify(parameterIndex, value)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x0E]
            )
        }
    }

    func writeMFX(_ parameterIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              (0...34).contains(parameterIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let baseAddress = mfxAddress(kitIndex: currentKitNumber - 1)
        let value: Int
        let offset: Int
        let data: [UInt8]
        let name: String

        if parameterIndex == 0 {
            value = mfxEnabledDraft ? 1 : 0
            offset = 1
            data = [UInt8(value)]
            name = "ON/OFF"
        } else if parameterIndex == 1 {
            value = mfxTypeDraft
            guard TD17MFXCatalog.types.indices.contains(value) else {
                appendLog("Invalid MFX type")
                return
            }
            offset = 0
            data = [UInt8(value)]
            name = "Type"
        } else if parameterIndex == 2 {
            value = mfxLevelDraft
            guard Self.effectLevelRange.contains(value) else {
                appendLog("Invalid MFX level")
                return
            }
            offset = 2
            data = encodeSigned16Nibbles(value)
            name = "Level"
        } else {
            let rawIndex = parameterIndex - 3
            guard let draft = mfxParameterDrafts[rawIndex],
                  (-32768...32767).contains(draft)
            else {
                appendLog("Invalid MFX parameter")
                return
            }
            value = draft
            offset = 6 + rawIndex * 4
            data = encodeSigned16Nibbles(value)
            name = String(format: "P%02d", rawIndex + 1)
        }

        sendDT1(
            address: addBase128(
                baseAddress,
                offset: encodeBase128(offset)
            ),
            data: data
        )
        appendLog(
            "Write MFX \(name): \(mfxValueText(parameterIndex, value)); "
                + "waiting for verification…"
        )
        status = "Verifying MFX \(name)…"
        isWriting = true
        readPhase = .mfxVerify(parameterIndex, value)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .mfxVerify(parameterIndex, value)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x01, 0x06]
            )
        }
    }

    func writeMasterComp(_ parameterIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              (0...15).contains(parameterIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let baseAddress = masterCompAddress(kitIndex: currentKitNumber - 1)
        let value: Int
        let offset: Int
        let data: [UInt8]
        let name: String

        if parameterIndex == 0 {
            value = masterCompEnabledDraft ? 1 : 0
            offset = 0
            data = [UInt8(value)]
            name = "ON/OFF"
        } else if parameterIndex == 1 {
            value = masterCompTypeDraft
            guard TD17MasterCompCatalog.types.indices.contains(value) else {
                appendLog("Invalid Master Comp type")
                return
            }
            offset = 1
            data = [UInt8(value)]
            name = "Type"
        } else {
            let rawIndex = parameterIndex - 2
            guard let draft = masterCompParameterDrafts[rawIndex] else {
                appendLog("Missing Master Comp parameter")
                return
            }
            value = draft
            name = TD17MasterCompCatalog.parameterNames[rawIndex]

            if rawIndex == 0 {
                guard (0...65535).contains(value) else {
                    appendLog("Invalid Split Frequency")
                    return
                }
                offset = 2
                data = encodeUnsigned16Nibbles(value)
            } else if (1...4).contains(rawIndex) {
                guard (-128...127).contains(value) else {
                    appendLog("Invalid Master Comp parameter")
                    return
                }
                offset = [0, 6, 8, 10, 12][rawIndex]
                data = encodeSignedByteNibbles(value)
            } else {
                guard (0...127).contains(value) else {
                    appendLog("Invalid Master Comp parameter")
                    return
                }
                offset = rawIndex + 9
                data = [UInt8(value)]
            }
        }

        sendDT1(
            address: addBase128(baseAddress, offset: encodeBase128(offset)),
            data: data
        )
        appendLog(
            "Write Master Comp \(name): \(masterCompValueText(parameterIndex, value)); "
                + "waiting for verification…"
        )
        status = "Verifying Master Comp \(name)…"
        isWriting = true
        readPhase = .masterCompVerify(parameterIndex, value)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .masterCompVerify(parameterIndex, value)
            else { return }
            self.sendRQ1(
                address: baseAddress,
                size: [0x00, 0x00, 0x00, 0x17]
            )
        }
    }

    func writeKitCommonParameter(_ parameterIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              (0...3).contains(parameterIndex)
        else {
            appendLog("Read the current kit first")
            return
        }

        let baseAddress = kitAddress(kitIndex: currentKitNumber - 1)
        let values = [
            pedalHiHatVolumeDraft,
            crossStickVolumeDraft,
            crossStickEnabledDraft ? 1 : 0,
            hiHatBalanceDraft
        ]
        let names = [
            "Pedal HH Volume", "XStick Volume", "XStick ON/OFF", "HH Balance"
        ]
        let offsets = [32, 36, 40, 41]
        let value = values[parameterIndex]
        let data: [UInt8]

        if parameterIndex < 2 {
            guard (-601...60).contains(value) else {
                appendLog("Invalid Kit Common level")
                return
            }
            data = encodeSigned16Nibbles(value)
        } else if parameterIndex == 2 {
            data = [UInt8(value)]
        } else {
            guard (-64...63).contains(value) else {
                appendLog("Invalid HH Balance")
                return
            }
            data = encodeSignedByteNibbles(value)
        }

        sendDT1(
            address: addBase128(
                baseAddress,
                offset: encodeBase128(offsets[parameterIndex])
            ),
            data: data
        )
        appendLog(
            "Write Kit Common \(names[parameterIndex]): "
                + "\(kitCommonValueText(parameterIndex, value)); "
                + "waiting for verification…"
        )
        status = "Verifying \(names[parameterIndex])…"
        isWriting = true
        readPhase = .kitCommonParameterVerify(parameterIndex, value)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .kitCommonParameterVerify(
                      parameterIndex,
                      value
                  )
            else { return }
            self.requestKitCommon(kitIndex: currentKitNumber - 1)
        }
    }

    func writeKitText(_ fieldIndex: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber, (0...1).contains(fieldIndex) else {
            appendLog("Read the current kit first")
            return
        }

        let limits = [12, 16]
        let offsets = [0, 12]
        let names = ["Kit name", "Kit description"]
        let source = fieldIndex == 0 ? kitNameDraft : kitSubNameDraft
        let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines)

        guard fieldIndex == 1 || !normalized.isEmpty else {
            appendLog("\(names[fieldIndex]) cannot be empty")
            return
        }
        guard normalized.unicodeScalars.allSatisfy({ $0.isASCII }),
              normalized.utf8.count <= limits[fieldIndex]
        else {
            appendLog(
                "\(names[fieldIndex]): use at most \(limits[fieldIndex]) ASCII characters"
            )
            return
        }

        let padded = normalized.padding(
            toLength: limits[fieldIndex],
            withPad: " ",
            startingAt: 0
        )
        let address = addBase128(
            kitAddress(kitIndex: currentKitNumber - 1),
            offset: encodeBase128(offsets[fieldIndex])
        )
        sendDT1(address: address, data: Array(padded.utf8))
        appendLog(
            "Write \(names[fieldIndex]): \"\(normalized)\"; "
                + "waiting for verification…"
        )
        status = "Verifying \(names[fieldIndex].lowercased())…"
        isWriting = true
        readPhase = .kitTextVerify(fieldIndex, normalized)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .kitTextVerify(fieldIndex, normalized)
            else { return }
            self.requestKitCommon(kitIndex: currentKitNumber - 1)
        }
    }

    func writeMIDINote(index: Int) {
        guard !isWriting else { return }
        guard let currentKitNumber,
              midiNotes.indices.contains(index),
              let note = midiNoteDrafts[index],
              (0...128).contains(note)
        else {
            appendLog("Invalid MIDI assignment")
            return
        }

        let baseAddress = kitMIDIAddress(kitIndex: currentKitNumber - 1)
        let offset = index * 4
        sendDT1(
            address: addBase128(baseAddress, offset: encodeBase128(offset)),
            data: encodeUnsigned16Nibbles(note)
        )
        appendLog(
            "Write MIDI \(midiNotes[index].name): "
                + "\(TD17MIDINoteCatalog.text(note)); "
                + "waiting for verification…"
        )
        status = "Verifying MIDI assignment…"
        isWriting = true
        readPhase = .midiNoteVerify(index, note)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(180))
            guard let self,
                  self.readPhase == .midiNoteVerify(index, note)
            else { return }
            self.requestKitMIDI(kitIndex: currentKitNumber - 1)
        }
    }

    private func sendSysEx(_ bytes: [UInt8]) {
        // Najpierw domykamy wiszące nuty. Zamknięcie wypuszczone w środek
        // ramki wraca echem i rozwala jej odbiór; puszczone tuż przed nią
        // nie przeszkadza nikomu.
        flushPendingNoteOffs()

        // Jedno wąskie gardło dla całego ruchu wychodzącego — także dla serii,
        // która wystartowała jeszcze przed terminem.
        guard !isBlockedByExpiry else {
            lastSendFailed = true
            return
        }
        guard
            let selectedOutputID,
            let destination = outputs.first(where: { $0.id == selectedOutputID })
        else {
            lastSendFailed = true
            appendLog("No MIDI output selected")
            return
        }

        var packetList = MIDIPacketList()
        let packet = MIDIPacketListInit(&packetList)

        // Wynik `MIDIPacketListAdd` trzeba sprawdzić. Gdy dane nie mieszczą
        // się w jednym pakiecie, funkcja zwraca `nil`, liczba pakietów zostaje
        // zerem, a `MIDISend` melduje sukces mimo że nie wysłał ani bajtu.
        // Bez tego warunku zapis, który nigdy nie opuścił programu, byłby
        // zaraportowany jako wysłany — a przy szybkim zapisie kitu decyduje to
        // o tym, czy program w ogóle zauważy, że przerwał w połowie.
        var added = false
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress, !buffer.isEmpty else { return }
            added = MIDIPacketListAdd(
                &packetList,
                MemoryLayout<MIDIPacketList>.size,
                packet,
                0,
                buffer.count,
                base
            ) != nil
        }
        guard added else {
            lastSendFailed = true
            appendLog(
                "TX ERROR: the message does not fit in a single MIDI packet "
                    + "(\(bytes.count) B)"
            )
            return
        }

        let result = MIDISend(outputPort, destination.reference, &packetList)
        lastSendFailed = result != noErr
        if result == noErr {
            appendLog("TX: \(hex(bytes))")
        } else {
            appendLog("CoreMIDI send error: \(result)")
        }
    }

    /// Po terminie ważności nic nie wychodzi na łącze — także z operacji,
    /// które zdążyły wystartować przed północą.
    private var isBlockedByExpiry: Bool {
        if AppExpiry.hasExpired {
            appendLog("This test version has expired — nothing was sent")
            return true
        }
        return false
    }

    private func sendRQ1(address: [UInt8], size: [UInt8]) {
        let checksum = rolandChecksum(address + size)
        let message: [UInt8] =
            [0xF0, 0x41, 0x10] + profile.modelID + [0x11]
            + address
            + size
            + [checksum, 0xF7]
        sendSysEx(message)
    }

    private func sendDT1(address: [UInt8], data: [UInt8]) {
        // Jedyne miejsce w programie, którym cokolwiek trafia do pamięci
        // modułu — więc tu stoi bezpiecznik. Moduł bez potwierdzonej na
        // sprzęcie mapy adresów jest wyłącznie do odczytu: zapis pod źle
        // odgadnięty adres trafia w nieznane miejsce cudzego instrumentu.
        guard profile.allowsWriting else {
            lastSendFailed = true
            appendLog(
                "WRITE BLOCKED — \(profile.displayName) is read only in this "
                    + "version. Its address map has not been verified against "
                    + "real hardware yet."
            )
            status = "\(profile.displayName): read only"
            return
        }

        let checksum = rolandChecksum(address + data)
        let message: [UInt8] =
            [0xF0, 0x41, 0x10] + profile.modelID + [0x12]
            + address
            + data
            + [checksum, 0xF7]
        sendSysEx(message)
    }

    func clearLog() {
        logFlushTask?.cancel()
        logFlushTask = nil
        pendingLogLines.removeAll(keepingCapacity: true)
        logLines = []
    }

    /// Cały log jako tekst — wyłącznie do kopiowania do schowka.
    /// Nie używać w widoku: składanie jest O(n).
    func logText() -> String {
        (logLines.map(\.text) + pendingLogLines).joined(separator: "\n")
    }

    /// Liczba linii łącznie z tymi, które czekają na odświeżenie widoku.
    var logLineCount: Int {
        logLines.count + pendingLogLines.count
    }

    func exportCurrentKitSnapshot() {
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }
        guard let currentKitNumber, let kitCommon else {
            appendLog("Read the entire current kit first")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export a TD-17 kit"
        panel.nameFieldStringValue =
            "\(kitCommon.name.replacingOccurrences(of: " ", with: "_"))_Kit\(currentKitNumber).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try JSONSerialization.data(
                withJSONObject: snapshotDictionary(
                    kitNumber: currentKitNumber,
                    common: kitCommon
                ),
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
            try data.write(to: url, options: .atomic)
            appendLog("Kit snapshot exported: \(url.lastPathComponent)")
            status = "Saved \(url.lastPathComponent)"
        } catch {
            appendLog("Snapshot export error: \(error.localizedDescription)")
            status = "Could not save the snapshot"
        }
    }

    func importSnapshotPreview() {
        guard !isOperationInProgress else {
            appendLog("Wait for the current MIDI operation to finish")
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Load a TD-17 kit snapshot"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let values = try url.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            )
            guard values.isRegularFile == true else {
                throw SnapshotError.invalid("The selected item is not a regular file")
            }
            guard let fileSize = values.fileSize, fileSize <= 1_000_000 else {
                throw SnapshotError.invalid("The file exceeds the safe 1 MB limit")
            }

            // Limit egzekwowany jeszcze raz, przy samym czytaniu. Poprzednio
            // rozmiar sprawdzało się na ścieżce, a potem otwierało tę ścieżkę
            // ponownie — plik, który urósł między jednym a drugim, wchodził
            // do pamięci w całości.
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            // `read(upToCount:)`, nie `readData(ofLength:)` — to drugie przy
            // błędzie wejścia-wyjścia rzuca wyjątek Objective-C, którego Swift
            // nie potrafi przechwycić: zniknięty w trakcie dysk sieciowy albo
            // wypięty pendrive zabijał program bez słowa. Ta wersja zgłasza
            // zwykły błąd, który łapie `catch` poniżej.
            let data = try handle.read(upToCount: 1_000_001) ?? Data()
            guard data.count <= 1_000_000 else {
                throw SnapshotError.invalid("The file exceeds the safe 1 MB limit")
            }
            guard let root = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
            else {
                throw SnapshotError.invalid("The file does not contain a JSON object")
            }
            try validateJSONTree(root, depth: 0)
            let preview = try validateSnapshot(root)
            importedSnapshot = root
            importedSnapshotSourceKitNumber = root["kitNumber"] as? Int
            authorizedSnapshotTargetKitNumber = nil
            importedSnapshotSummary = preview.summary
            importedSnapshotDetails = preview.details
            snapshotDifferences = nil
            snapshotDifferencePaths = []
            appendLog("Snapshot loaded for preview: \(url.lastPathComponent)")
            appendLog("SNAPSHOT: \(preview.summary)")
            status = "Snapshot sprawdzony — bez zmian w module"
            if readPhase == .complete, kitCommon != nil {
                compareImportedSnapshot()
            }
        } catch {
            importedSnapshot = nil
            importedSnapshotSourceKitNumber = nil
            authorizedSnapshotTargetKitNumber = nil
            importedSnapshotSummary = nil
            importedSnapshotDetails = []
            snapshotDifferences = nil
            snapshotDifferencePaths = []
            appendLog("Odrzucono snapshot: \(error.localizedDescription)")
            status = "Invalid snapshot"
        }
    }

    func compareImportedSnapshot() {
        guard var imported = importedSnapshot,
              let currentKitNumber,
              let kitCommon
        else {
            appendLog("Read a kit first and load a valid snapshot")
            status = "Missing data to compare"
            return
        }

        guard let snapshotKit = imported["kitNumber"] as? Int,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber)
        else {
            appendLog(
                "COMPARE blocked: the snapshot comes from a different kit. "
                    + "Authorise the current kit as the import target first."
            )
            status = "The snapshot needs the target kit to be authorised"
            return
        }

        var current = snapshotDictionary(
            kitNumber: currentKitNumber,
            common: kitCommon
        )
        imported["kitNumber"] = currentKitNumber
        imported.removeValue(forKey: "exportedAt")
        current.removeValue(forKey: "exportedAt")

        var differences: [String] = []
        var paths: Set<String> = []
        compareJSON(
            imported,
            current,
            path: "",
            differences: &differences,
            differencePaths: &paths
        )
        snapshotDifferences = differences
        snapshotDifferencePaths = paths

        if differences.isEmpty {
            appendLog("COMPARE: the snapshot and the current kit are identical")
            status = "No differences from the snapshot"
        } else {
            appendLog("COMPARE: found \(differences.count) differences")
            for (index, difference) in differences.prefix(100).enumerated() {
                appendLog("DIFFERENCE \(index + 1): \(difference)")
            }
            if differences.count > 100 {
                appendLog(
                    "DIFFERENCES: skipped in the log \(differences.count - 100) further items"
                )
            }
            status = "Found \(differences.count) differences"
        }
    }

    func authorizeSnapshotForCurrentKit() {
        guard !isOperationInProgress,
              let sourceKit = importedSnapshotSourceKitNumber,
              let currentKitNumber,
              sourceKit != currentKitNumber
        else { return }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText =
            "Use the snapshot of kit \(sourceKit) for kit \(currentKitNumber)?"
        alert.informativeText =
            "Kit \(currentKitNumber) becomes the import target. The comparison will show "
            + "every value that would change. Nothing is written "
            + "until you choose to restore separately."
        alert.addButton(withTitle: "Set kit \(currentKitNumber) jako cel")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            appendLog("Target kit selection cancelled")
            return
        }

        authorizedSnapshotTargetKitNumber = currentKitNumber
        snapshotDifferences = nil
        snapshotDifferencePaths = []
        appendLog(
            "IMPORT TARGET: snapshot of kit \(sourceKit) → target kit "
                + "\(currentKitNumber)"
        )
        status = "Kit \(currentKitNumber) authorised as the import target"
        compareImportedSnapshot()
    }

    private func isSnapshotAuthorized(snapshotKit: Int, currentKit: Int) -> Bool {
        snapshotKit == currentKit || authorizedSnapshotTargetKitNumber == currentKit
    }

    func restoreAllSnapshotDifferences() {
        guard !isOperationInProgress,
              let importedSnapshot,
              let currentKitNumber,
              !snapshotDifferencePaths.isEmpty,
              let sourceKit = importedSnapshot["kitNumber"] as? Int,
              isSnapshotAuthorized(
                snapshotKit: sourceKit,
                currentKit: currentKitNumber
              )
        else {
            appendLog("Fast write blocked: no data, no authorisation or no differences")
            return
        }

        let blocks: [FastSnapshotBlock]
        do {
            blocks = try makeFastSnapshotBlocks(
                snapshot: importedSnapshot,
                kitIndex: currentKitNumber - 1
            )
        } catch {
            appendLog("Fast write blocked: \(error.localizedDescription)")
            status = "This snapshot cannot be fast-written"
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Write the whole snapshot to kit \(currentKitNumber)?"
        alert.informativeText =
            "The app will send \(blocks.count) complete data blocks, then "
            + "read the whole kit back and compare it with the snapshot. The "
            + "contents of kit \(currentKitNumber) will be replaced and CANNOT "
            + "be undone — export kit \(currentKitNumber) first if you want to "
            + "be able to go back. Do not unplug the cable, change the kit or "
            + "power off the module until the app says it has settled."
        // Cancel jako pierwszy, bo `NSAlert` robi z pierwszego przycisku
        // domyślny, z klawiszem Enter. Odruchowe wciśnięcie Enter nadpisywało
        // cały kit — bez cofnięcia i bez śladu, co tam było wcześniej.
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Fast write and full verification")
        guard alert.runModal() == .alertSecondButtonReturn else {
            appendLog("Fast snapshot write cancelled")
            return
        }

        isBatchRestoring = true
        isFastWriting = true
        batchRestoreTotal = blocks.count
        batchRestoreProgress = "0 of \(blocks.count)"
        status = "Fast write to kit \(currentKitNumber)…"
        appendLog(
            "FAST WRITE: snapshot of kit \(sourceKit) → kit \(currentKitNumber), "
                + "\(blocks.count) blocks"
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            for (index, block) in blocks.enumerated() {
                guard self.isBatchRestoring else { return }
                self.sendDT1(address: block.address, data: block.data)

                // Bez tego sprawdzenia wyrwany w połowie kabel, wyłączony
                // moduł albo minięty termin ważności nie zatrzymywały pętli:
                // licznik dobiegał do „105 z 105", a w module zostawał kit
                // złożony z połowy nowej i połowy starej zawartości — ani
                // stary, ani nowy, i nikt się o tym nie dowiadywał.
                guard self.lastSendReachedTheWire else {
                    self.isBatchRestoring = false
                    self.isFastWriting = false
                    self.batchRestoreProgress = nil
                    self.stabilizeAfterCurrentRead = false
                    self.appendLog(
                        "FAST WRITE ABORTED at block \(index + 1) of "
                            + "\(blocks.count) (\(block.name)). Kit "
                            + "\(currentKitNumber) is now PARTLY written — "
                            + "repeat the fast write before playing it."
                    )
                    self.status =
                        "Fast write interrupted — kit \(currentKitNumber) "
                        + "is incomplete"
                    return
                }

                self.batchRestoreProgress = "\(index + 1) of \(blocks.count)"
                self.status =
                    "Fast write \(index + 1) of \(blocks.count): \(block.name)"
                try? await Task.sleep(for: .milliseconds(8))
            }

            try? await Task.sleep(for: .milliseconds(600))
            self.isBatchRestoring = false
            self.isFastWriting = false
            self.batchRestoreProgress = nil
            self.appendLog("FAST WRITE: all blocks sent; full verification…")
            self.status = "Verification read of the whole kit…"
            self.stabilizeAfterCurrentRead = true
            self.readCurrentKit()
        }
    }

    private func beginModuleStabilization() {
        guard stabilizeAfterCurrentRead else { return }
        stabilizeAfterCurrentRead = false
        stabilizationSecondsRemaining = 30
        status = "Settling in the module — do not change the kit (30 s)"
        appendLog(
            "SETTLING: do not change the kit or power off the TD-17 for 30 seconds"
        )

        Task { @MainActor [weak self] in
            guard let self else { return }
            while self.stabilizationSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard self.stabilizationSecondsRemaining > 0 else { return }
                self.stabilizationSecondsRemaining -= 1
                if self.stabilizationSecondsRemaining > 0 {
                    self.status =
                        "Settling in the module — do not change the kit "
                        + "(\(self.stabilizationSecondsRemaining) s)"
                }
            }
            self.status = "Kit written and settled in the module"
            self.appendLog(
                "SETTLED: it is now safe to change the kit or power off the TD-17"
            )
        }
    }

    func restoreAllSnapshotDifferencesSlow() {
        guard !isOperationInProgress,
              importedSnapshot != nil,
              currentKitNumber != nil,
              !snapshotDifferencePaths.isEmpty
        else {
            appendLog("Restore-all blocked: no data or an operation is running")
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore every detected difference?"
        alert.informativeText =
            "The app will write \(snapshotDifferencePaths.count) differences one at a time. "
            + "Each write is read back for verification before moving on."
        alert.addButton(withTitle: "Restore everything and verify")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            appendLog("Restore-all cancelled")
            return
        }

        var actions: [() -> Void] = []
        for path in restorableSnapshotCommonPaths {
            actions.append { [weak self] in self?.restoreSnapshotCommon(path) }
        }
        for restore in restorableSnapshotInstruments where !restore.isSub {
            actions.append { [weak self] in self?.restoreSnapshotInstrument(restore) }
        }
        for restore in restorableSnapshotLayers {
            actions.append { [weak self] in self?.restoreSnapshotLayer(restore) }
        }
        for restore in restorableSnapshotInstruments where restore.isSub {
            actions.append { [weak self] in self?.restoreSnapshotInstrument(restore) }
        }
        for restore in restorableSnapshotLevels {
            actions.append { [weak self] in self?.restoreSnapshotLevel(restore) }
        }
        for restore in restorableSnapshotVEdits {
            actions.append { [weak self] in self?.restoreSnapshotVEdit(restore) }
        }
        for restore in restorableSnapshotPans {
            actions.append { [weak self] in self?.restoreSnapshotPan(restore) }
        }
        for restore in restorableSnapshotMixSends {
            actions.append { [weak self] in self?.restoreSnapshotMixSend(restore) }
        }
        for restore in restorableSnapshotEQFields {
            actions.append { [weak self] in self?.restoreSnapshotEQField(restore) }
        }
        for restore in restorableSnapshotAmbienceFields {
            actions.append { [weak self] in self?.restoreSnapshotAmbienceField(restore) }
        }
        for restore in restorableSnapshotReverbFields {
            actions.append { [weak self] in self?.restoreSnapshotReverbField(restore) }
        }
        for restore in restorableSnapshotMFXFields {
            actions.append { [weak self] in self?.restoreSnapshotMFXField(restore) }
        }
        for restore in restorableSnapshotMasterCompFields {
            actions.append { [weak self] in self?.restoreSnapshotMasterCompField(restore) }
        }
        for restore in restorableSnapshotMIDINotes {
            actions.append { [weak self] in self?.restoreSnapshotMIDINote(restore) }
        }

        guard !actions.isEmpty else {
            appendLog("No differences supported by automatic restore")
            status = "These differences cannot be restored automatically"
            return
        }

        batchRestoreActions = actions
        batchRestoreTotal = actions.count
        isBatchRestoring = true
        appendLog("RESTORE ALL: starting \(actions.count) writes with verification")
        runNextBatchRestoreAction()
    }

    private func runNextBatchRestoreAction() {
        guard isBatchRestoring else { return }

        guard !batchRestoreActions.isEmpty else {
            isBatchRestoring = false
            batchRestoreProgress = nil
            appendLog("RESTORE ALL: all writes finished")
            compareImportedSnapshot()
            return
        }

        let completed = batchRestoreTotal - batchRestoreActions.count
        batchRestoreProgress = "\(completed + 1) of \(batchRestoreTotal)"
        status = "Restoring \(completed + 1) of \(batchRestoreTotal)…"
        let action = batchRestoreActions.removeFirst()
        action()

        guard isWriting else {
            isBatchRestoring = false
            batchRestoreProgress = nil
            batchRestoreActions = []
            appendLog("RESTORE ALL: aborted — an item never started writing")
            status = "Automatic restore aborted"
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<100 {
                try? await Task.sleep(for: .milliseconds(100))
                guard self.isBatchRestoring else { return }
                if !self.isWriting {
                    self.runNextBatchRestoreAction()
                    return
                }
            }
            self.isBatchRestoring = false
            self.batchRestoreProgress = nil
            self.batchRestoreActions = []
            self.appendLog("RESTORE ALL: aborted — the write was not verified")
            self.status = "Automatic restore timed out"
        }
    }

    private func compareJSON(
        _ snapshot: Any,
        _ current: Any,
        path: String,
        differences: inout [String],
        differencePaths: inout Set<String>
    ) {
        guard differences.count < 500 else { return }

        if let lhs = snapshot as? [String: Any],
           let rhs = current as? [String: Any] {
            for key in Set(lhs.keys).union(rhs.keys).sorted() {
                let childPath = path.isEmpty ? key : "\(path).\(key)"
                guard let left = lhs[key], let right = rhs[key] else {
                    differences.append("\(childPath): the field is missing on one side")
                    differencePaths.insert(childPath)
                    continue
                }
                compareJSON(
                    left,
                    right,
                    path: childPath,
                    differences: &differences,
                    differencePaths: &differencePaths
                )
            }
            return
        }

        if let lhs = snapshot as? [Any], let rhs = current as? [Any] {
            // Tablice opisujące strefy (np. vEditSub) są rzadkie — zawierają
            // tylko strefy aktywne, więc ta sama pozycja w snapshocie i w
            // module może dotyczyć zupełnie innego pada. Porównanie po
            // pozycji pokazywało wtedy różnice, których nie ma, i pozwalało
            // przywrócić wartość do złej strefy. Jeśli oba zestawy niosą
            // `zoneIndex`, zestawiamy je po numerze strefy.
            if let snapshotZones = lhs as? [[String: Any]],
               let currentZones = rhs as? [[String: Any]],
               !snapshotZones.isEmpty || !currentZones.isEmpty,
               snapshotZones.allSatisfy({ $0["zoneIndex"] is Int }),
               currentZones.allSatisfy({ $0["zoneIndex"] is Int }) {
                compareZoneKeyedArrays(
                    snapshotZones,
                    currentZones,
                    path: path,
                    differences: &differences,
                    differencePaths: &differencePaths
                )
                return
            }

            if lhs.count != rhs.count {
                differences.append(
                    "\(path): snapshot \(lhs.count) items, module \(rhs.count)"
                )
                differencePaths.insert(path)
            }
            for index in 0..<min(lhs.count, rhs.count) {
                compareJSON(
                    lhs[index],
                    rhs[index],
                    path: "\(path)[\(index)]",
                    differences: &differences,
                    differencePaths: &differencePaths
                )
            }
            return
        }

        if let lhs = snapshot as? NSNumber, let rhs = current as? NSNumber {
            if lhs != rhs {
                differences.append(
                    "\(friendlyPath(path)): snapshot \(lhs), module \(rhs)"
                )
                differencePaths.insert(path)
            }
            return
        }

        if let lhs = snapshot as? String, let rhs = current as? String {
            if lhs != rhs {
                differences.append(
                    "\(friendlyPath(path)): snapshot “\(lhs)”, module “\(rhs)”"
                )
                differencePaths.insert(path)
            }
            return
        }

        if snapshot is NSNull, current is NSNull { return }
        differences.append("\(friendlyPath(path)): different types or values")
        differencePaths.insert(path)
    }

    /// Zestawia dwie listy stref po `zoneIndex`.
    ///
    /// Ścieżki różnic zachowują indeks z tablicy **snapshotu**, bo tego
    /// samego indeksu używają potem `restorableSnapshot*` przy odczycie
    /// wartości do przywrócenia.
    private func compareZoneKeyedArrays(
        _ snapshotItems: [[String: Any]],
        _ currentItems: [[String: Any]],
        path: String,
        differences: inout [String],
        differencePaths: inout Set<String>
    ) {
        func zoneLabel(_ zone: Int) -> String {
            zoneNames.indices.contains(zone) ? zoneNames[zone] : "strefa \(zone)"
        }

        var currentByZone: [Int: [String: Any]] = [:]
        for item in currentItems {
            guard let zone = item["zoneIndex"] as? Int else { continue }
            currentByZone[zone] = item
        }

        var matchedZones: Set<Int> = []

        for (index, item) in snapshotItems.enumerated() {
            guard let zone = item["zoneIndex"] as? Int else { continue }
            let childPath = "\(path)[\(index)]"

            guard let counterpart = currentByZone[zone] else {
                // Tylko komunikat — bez wpisu do `differencePaths`.
                // Ścieżka kontenera nie odpowiada żadnemu przywracalnemu
                // polu, a podniosłaby licznik różnic i odblokowała
                // „przywróć wszystko" bez ani jednej wykonalnej akcji.
                differences.append(
                    "\(friendlyPath(childPath)) \(zoneLabel(zone)): "
                        + "present in the snapshot, missing in the module"
                )
                continue
            }

            matchedZones.insert(zone)
            compareJSON(
                item,
                counterpart,
                path: childPath,
                differences: &differences,
                differencePaths: &differencePaths
            )
        }

        for item in currentItems {
            guard let zone = item["zoneIndex"] as? Int,
                  !matchedZones.contains(zone)
            else { continue }
            differences.append(
                "\(friendlyPath(path)) \(zoneLabel(zone)): "
                    + "present in the module, missing in the snapshot"
            )
        }
    }

    var restorableSnapshotCommonPaths: [String] {
        [
            "common.name",
            "common.subName",
            "common.kitVolumeTenthsDB",
            "common.pedalHiHatVolumeTenthsDB",
            "common.crossStickVolumeTenthsDB",
            "common.crossStickEnabled",
            "common.hiHatBalance"
        ].filter { snapshotDifferencePaths.contains($0) }
    }

    func snapshotCommonLabel(_ path: String) -> String {
        [
            "common.name": "Kit name",
            "common.subName": "Kit description",
            "common.kitVolumeTenthsDB": "Kit volume",
            "common.pedalHiHatVolumeTenthsDB": "Pedal HH Volume",
            "common.crossStickVolumeTenthsDB": "XStick Volume",
            "common.crossStickEnabled": "XStick ON/OFF",
            "common.hiHatBalance": "HH Balance"
        ][path] ?? path
    }

    func restoreSnapshotCommon(_ path: String) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              snapshotDifferencePaths.contains(path),
              let common = importedSnapshot["common"] as? [String: Any]
        else {
            appendLog(
                "Restore blocked: no safe difference for the current kit"
            )
            status = "This parameter cannot be restored safely"
            return
        }

        let label = snapshotCommonLabel(path)
        let valueText: String
        switch path {
        case "common.name":
            guard let value = common["name"] as? String,
                  isSafeKitText(value, maximumBytes: 12)
            else { return }
            valueText = "“\(value)”"
        case "common.subName":
            guard let value = common["subName"] as? String,
                  isSafeKitText(value, maximumBytes: 16)
            else { return }
            valueText = value.isEmpty ? "pusty opis" : "“\(value)”"
        case "common.kitVolumeTenthsDB",
             "common.pedalHiHatVolumeTenthsDB",
             "common.crossStickVolumeTenthsDB":
            let key = String(path.dropFirst("common.".count))
            guard let value = common[key] as? Int,
                  (-601...60).contains(value)
            else { return }
            valueText = levelText(value)
        case "common.crossStickEnabled":
            guard let value = common["crossStickEnabled"] as? Bool else { return }
            valueText = value ? "ON" : "OFF"
        case "common.hiHatBalance":
            guard let value = common["hiHatBalance"] as? Int,
                  (-64...63).contains(value)
            else { return }
            valueText = "\(value)"
        default:
            appendLog("Restore blocked: unsupported field \(path)")
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(label)?"
        alert.informativeText =
            "Kit \(currentKitNumber) will be set to \(valueText) "
            + "from the snapshot. No other parameter is changed."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(label)")
            return
        }

        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(label) → \(valueText)"
        )
        switch path {
        case "common.name":
            kitNameDraft = common["name"] as? String ?? ""
            writeKitText(0)
        case "common.subName":
            kitSubNameDraft = common["subName"] as? String ?? ""
            writeKitText(1)
        case "common.kitVolumeTenthsDB":
            let value = common["kitVolumeTenthsDB"] as? Int ?? 0
            kitVolumeDraft = Double(value) / 10.0
            writeKitVolume()
        case "common.pedalHiHatVolumeTenthsDB":
            pedalHiHatVolumeDraft =
                common["pedalHiHatVolumeTenthsDB"] as? Int ?? 0
            writeKitCommonParameter(0)
        case "common.crossStickVolumeTenthsDB":
            crossStickVolumeDraft =
                common["crossStickVolumeTenthsDB"] as? Int ?? 0
            writeKitCommonParameter(1)
        case "common.crossStickEnabled":
            crossStickEnabledDraft =
                common["crossStickEnabled"] as? Bool ?? false
            writeKitCommonParameter(2)
        case "common.hiHatBalance":
            hiHatBalanceDraft = common["hiHatBalance"] as? Int ?? 0
            writeKitCommonParameter(3)
        default:
            break
        }
    }

    var restorableSnapshotInstruments: [TD17SnapshotInstrumentRestore] {
        var result: [TD17SnapshotInstrumentRestore] = []
        for index in zoneNames.indices {
            if snapshotDifferencePaths.contains("main[\(index)].instrument.id")
                || snapshotDifferencePaths.contains(
                    "main[\(index)].instrument.userSample"
                ) {
                result.append(
                    TD17SnapshotInstrumentRestore(
                        zoneIndex: index,
                        isSub: false,
                        zoneName: zoneNames[index]
                    )
                )
            }
            if snapshotDifferencePaths.contains("sub[\(index)].instrument.id")
                || snapshotDifferencePaths.contains(
                    "sub[\(index)].instrument.userSample"
                ) {
                result.append(
                    TD17SnapshotInstrumentRestore(
                        zoneIndex: index,
                        isSub: true,
                        zoneName: zoneNames[index]
                    )
                )
            }
        }
        return result
    }

    func restoreSnapshotInstrument(
        _ restore: TD17SnapshotInstrumentRestore
    ) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              zoneNames.indices.contains(restore.zoneIndex)
        else {
            appendLog("Restore instrumentu zablokowany: niezgodny kit")
            status = "The instrument cannot be restored safely"
            return
        }

        let section = restore.isSub ? "sub" : "main"
        guard let items = importedSnapshot[section] as? [[String: Any]],
              items.indices.contains(restore.zoneIndex),
              // Ten sam warunek spójności, co w pozostałych ścieżkach
              // przywracania: pozycja w tablicy musi opisywać tę strefę,
              // za którą się podaje.
              items[restore.zoneIndex]["zoneIndex"] as? Int
                == restore.zoneIndex,
              let instrument = items[restore.zoneIndex]["instrument"]
                as? [String: Any],
              let instrumentID = instrument["id"] as? Int,
              instrument["userSample"] as? Bool == false,
              TD17InstrumentCatalog.instruments.indices.contains(instrumentID)
        else {
            appendLog(
                "Instrument restore blocked: User Samples are not supported yet"
            )
            status = "Restoring a User Sample is blocked"
            return
        }

        let definition = TD17InstrumentCatalog.instruments[instrumentID]
        guard instrument["name"] as? String == definition.name,
              instrument["group"] as? String == definition.group
        else {
            appendLog("Instrument restore blocked: inconsistent catalogue")
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the instrument \(restore.label) "
            + "will change to \(definition.name) (#\(instrumentID)). "
            + "The level and all other settings stay untouched."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        if restore.isSub {
            subInstrumentDrafts[restore.zoneIndex] = instrumentID
        } else {
            mainInstrumentDrafts[restore.zoneIndex] = instrumentID
        }
        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) Instrument "
                + "→ \(definition.name) (#\(instrumentID))"
        )
        writeInstrument(
            zoneIndex: restore.zoneIndex,
            isSub: restore.isSub
        )
    }

    var restorableSnapshotLevels: [TD17SnapshotLevelRestore] {
        var result: [TD17SnapshotLevelRestore] = []
        for index in zoneNames.indices {
            if snapshotDifferencePaths.contains(
                "main[\(index)].instrument.levelTenthsDB"
            ) {
                result.append(
                    TD17SnapshotLevelRestore(
                        zoneIndex: index,
                        isSub: false,
                        zoneName: zoneNames[index]
                    )
                )
            }
            if snapshotDifferencePaths.contains(
                "sub[\(index)].instrument.levelTenthsDB"
            ) {
                result.append(
                    TD17SnapshotLevelRestore(
                        zoneIndex: index,
                        isSub: true,
                        zoneName: zoneNames[index]
                    )
                )
            }
        }
        return result
    }

    func restoreSnapshotLevel(_ restore: TD17SnapshotLevelRestore) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              zoneNames.indices.contains(restore.zoneIndex)
        else {
            appendLog("Restore poziomu zablokowany: niezgodny kit")
            status = "The level cannot be restored safely"
            return
        }

        let section = restore.isSub ? "sub" : "main"
        let differencePath =
            "\(section)[\(restore.zoneIndex)].instrument.levelTenthsDB"
        guard snapshotDifferencePaths.contains(differencePath),
              let items = importedSnapshot[section] as? [[String: Any]],
              items.indices.contains(restore.zoneIndex),
              items[restore.zoneIndex]["zoneIndex"] as? Int
                == restore.zoneIndex,
              let instrument = items[restore.zoneIndex]["instrument"]
                as? [String: Any],
              let value = instrument["levelTenthsDB"] as? Int,
              (-601...60).contains(value)
        else {
            appendLog("Level restore blocked: inconsistent snapshot data")
            status = "The level cannot be restored safely"
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the level \(restore.label) "
            + "will be set to \(levelText(value)). "
            + "The instrument and all other parameters stay untouched."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        let draft = Double(value) / 10.0
        if restore.isSub {
            subLevelDrafts[restore.zoneIndex] = draft
        } else {
            mainLevelDrafts[restore.zoneIndex] = draft
        }
        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + levelText(value)
        )
        writeZoneLevel(
            zoneIndex: restore.zoneIndex,
            isSub: restore.isSub
        )
    }

    var restorableSnapshotLayers: [TD17SnapshotLayerRestore] {
        var result: [TD17SnapshotLayerRestore] = []
        for index in zoneNames.indices {
            for field in ["enabled", "layerType", "fadePoint"] {
                if snapshotDifferencePaths.contains("sub[\(index)].\(field)") {
                    result.append(
                        TD17SnapshotLayerRestore(
                            zoneIndex: index,
                            field: field,
                            zoneName: zoneNames[index]
                        )
                    )
                }
            }
        }
        return result
    }

    func restoreSnapshotLayer(_ restore: TD17SnapshotLayerRestore) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              zoneNames.indices.contains(restore.zoneIndex),
              ["enabled", "layerType", "fadePoint"].contains(restore.field),
              snapshotDifferencePaths.contains(
                "sub[\(restore.zoneIndex)].\(restore.field)"
              ),
              let items = importedSnapshot["sub"] as? [[String: Any]],
              items.indices.contains(restore.zoneIndex),
              items[restore.zoneIndex]["zoneIndex"] as? Int
                == restore.zoneIndex,
              let currentEnabled = subEnabledDrafts[restore.zoneIndex],
              let currentType = subLayerTypeDrafts[restore.zoneIndex],
              let currentFade = subFadePointDrafts[restore.zoneIndex]
        else {
            appendLog("Layer restore blocked: inconsistent data or kit")
            status = "The layer settings cannot be restored safely"
            return
        }

        let item = items[restore.zoneIndex]
        var enabled = currentEnabled
        var type = currentType
        var fade = currentFade
        let valueText: String
        switch restore.field {
        case "enabled":
            guard let value = item["enabled"] as? Bool else { return }
            enabled = value
            valueText = value ? "ON" : "OFF"
        case "layerType":
            let typeNames = TD17LayerCatalog.types
            guard let value = item["layerType"] as? String,
                  let index = typeNames.firstIndex(of: value)
            else { return }
            type = index
            valueText = value
        default:
            // Zakres składowania, nie edycyjny — dokładnie jak w
            // `writeLayerSettings`. Migawka zdjęta z prawdziwego modułu ma tu
            // 0 dla warstw MIX i SWITCH, więc przy zakresie edycyjnym przycisk
            // przywracania wyglądał na zepsuty, a przy „przywróć wszystko"
            // zabijał całą serię komunikatem, że pozycja nie ruszyła.
            guard let value = item["fadePoint"] as? Int,
                  Self.fadePointStorageRange.contains(value)
            else {
                appendLog("Fade Point out of range in the snapshot — skipped")
                return
            }
            fade = value
            valueText = "\(value)"
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the chosen setting will take the "
            + "value \(valueText). The remaining layer values are "
            + "sent unchanged and verified."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        subEnabledDrafts[restore.zoneIndex] = enabled
        subLayerTypeDrafts[restore.zoneIndex] = type
        subFadePointDrafts[restore.zoneIndex] = fade
        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + valueText
        )
        writeLayerSettings(zoneIndex: restore.zoneIndex)
    }

    var restorableSnapshotPans: [TD17SnapshotPanRestore] {
        zoneNames.indices.compactMap { index in
            snapshotDifferencePaths.contains("mixer[\(index)].pan")
                ? TD17SnapshotPanRestore(
                    zoneIndex: index,
                    zoneName: zoneNames[index]
                )
                : nil
        }
    }

    func restoreSnapshotPan(_ restore: TD17SnapshotPanRestore) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              zoneNames.indices.contains(restore.zoneIndex),
              snapshotDifferencePaths.contains(
                "mixer[\(restore.zoneIndex)].pan"
              ),
              let items = importedSnapshot["mixer"] as? [[String: Any]],
              items.indices.contains(restore.zoneIndex),
              items[restore.zoneIndex]["zoneIndex"] as? Int
                == restore.zoneIndex,
              let value = items[restore.zoneIndex]["pan"] as? Int,
              (-64...63).contains(value)
        else {
            appendLog("Pan restore blocked: inconsistent data or kit")
            status = "The pan cannot be restored safely"
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the pan of zone "
            + "\(restore.zoneName) will be set to \(panText(value))."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        panDrafts[restore.zoneIndex] = value
        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + panText(value)
        )
        writePan(zoneIndex: restore.zoneIndex)
    }

    var restorableSnapshotMixSends: [TD17SnapshotMixSendRestore] {
        let keys = [
            "ambienceSendTenthsDB",
            "mfxSendTenthsDB",
            "reverbSendTenthsDB"
        ]
        var result: [TD17SnapshotMixSendRestore] = []
        for index in zoneNames.indices {
            for sendIndex in keys.indices
            where snapshotDifferencePaths.contains(
                "mixer[\(index)].\(keys[sendIndex])"
            ) {
                result.append(
                    TD17SnapshotMixSendRestore(
                        zoneIndex: index,
                        sendIndex: sendIndex,
                        zoneName: zoneNames[index]
                    )
                )
            }
        }
        return result
    }

    func restoreSnapshotMixSend(_ restore: TD17SnapshotMixSendRestore) {
        let keys = [
            "ambienceSendTenthsDB",
            "mfxSendTenthsDB",
            "reverbSendTenthsDB"
        ]
        guard canStartSingleRestore,
              keys.indices.contains(restore.sendIndex),
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              zoneNames.indices.contains(restore.zoneIndex),
              snapshotDifferencePaths.contains(
                "mixer[\(restore.zoneIndex)].\(keys[restore.sendIndex])"
              ),
              let items = importedSnapshot["mixer"] as? [[String: Any]],
              items.indices.contains(restore.zoneIndex),
              items[restore.zoneIndex]["zoneIndex"] as? Int
                == restore.zoneIndex,
              let value = items[restore.zoneIndex][keys[restore.sendIndex]]
                as? Int,
              Self.sendLevelRange.contains(value)
        else {
            appendLog("Send restore blocked: inconsistent data or kit")
            status = "The send cannot be restored safely"
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the \(restore.sendName) send of zone "
            + "\(restore.zoneName) will be set to \(levelText(value))."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        switch restore.sendIndex {
        case 0:
            ambienceSendDrafts[restore.zoneIndex] = value
        case 1:
            mfxSendDrafts[restore.zoneIndex] = value
        default:
            reverbSendDrafts[restore.zoneIndex] = value
        }
        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + levelText(value)
        )
        switch restore.sendIndex {
        case 0:
            writeAmbienceSend(zoneIndex: restore.zoneIndex)
        case 1:
            writeMFXSend(zoneIndex: restore.zoneIndex)
        default:
            writeReverbSend(zoneIndex: restore.zoneIndex)
        }
    }

    var restorableSnapshotEQFields: [TD17SnapshotEQRestore] {
        let fields = [
            "eqEnabled",
            "lowGain", "midGain", "highGain",
            "lowFrequency", "midFrequency", "midQ", "highFrequency"
        ]
        var result: [TD17SnapshotEQRestore] = []
        for index in zoneNames.indices {
            for field in fields
            where snapshotDifferencePaths.contains("mixer[\(index)].\(field)") {
                result.append(
                    TD17SnapshotEQRestore(
                        zoneIndex: index,
                        field: field,
                        zoneName: zoneNames[index]
                    )
                )
            }
        }
        return result
    }

    func restoreSnapshotEQField(_ restore: TD17SnapshotEQRestore) {
        let gainFields = ["lowGain", "midGain", "highGain"]
        let shapeFields = [
            "lowFrequency", "midFrequency", "midQ", "highFrequency"
        ]
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              zoneNames.indices.contains(restore.zoneIndex),
              snapshotDifferencePaths.contains(
                "mixer[\(restore.zoneIndex)].\(restore.field)"
              ),
              let items = importedSnapshot["mixer"] as? [[String: Any]],
              items.indices.contains(restore.zoneIndex),
              items[restore.zoneIndex]["zoneIndex"] as? Int
                == restore.zoneIndex
        else {
            appendLog("EQ restore blocked: inconsistent data or kit")
            status = "Pad EQ cannot be restored safely"
            return
        }

        let item = items[restore.zoneIndex]
        let valueText: String
        var action: (() -> Void)?
        if restore.field == "eqEnabled" {
            guard let value = item[restore.field] as? Bool else { return }
            valueText = value ? "ON" : "OFF"
            action = { [weak self] in
                guard let self else { return }
                self.eqEnabledDrafts[restore.zoneIndex] = value
                self.writeEQEnabled(zoneIndex: restore.zoneIndex)
            }
        } else if let bandIndex = gainFields.firstIndex(of: restore.field) {
            guard let value = item[restore.field] as? Int,
                  (-15...15).contains(value)
            else { return }
            valueText = signedDBText(value)
            action = { [weak self] in
                guard let self else { return }
                switch bandIndex {
                case 0: self.eqLowGainDrafts[restore.zoneIndex] = value
                case 1: self.eqMidGainDrafts[restore.zoneIndex] = value
                default: self.eqHighGainDrafts[restore.zoneIndex] = value
                }
                self.writeEQGain(
                    zoneIndex: restore.zoneIndex,
                    bandIndex: bandIndex
                )
            }
        } else if let parameterIndex = shapeFields.firstIndex(
            of: restore.field
        ) {
            guard let value = item[restore.field] as? String,
                  let valueIndex = eqShapeLists[parameterIndex]
                    .firstIndex(of: value)
            else { return }
            valueText = value
            action = { [weak self] in
                guard let self else { return }
                switch parameterIndex {
                case 0:
                    self.eqLowFrequencyDrafts[restore.zoneIndex] = valueIndex
                case 1:
                    self.eqMidFrequencyDrafts[restore.zoneIndex] = valueIndex
                case 2:
                    self.eqMidQDrafts[restore.zoneIndex] = valueIndex
                default:
                    self.eqHighFrequencyDrafts[restore.zoneIndex] = valueIndex
                }
                self.writeEQShape(
                    zoneIndex: restore.zoneIndex,
                    parameterIndex: parameterIndex
                )
            }
        } else {
            appendLog("EQ restore blocked: unsupported field")
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the chosen Pad EQ field will be "
            + "ustawione na \(valueText)."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + valueText
        )
        action?()
    }

    var restorableSnapshotAmbienceFields: [TD17SnapshotAmbienceRestore] {
        [
            "enabled", "roomType", "roomSize", "roomShape",
            "wallType", "micPosition", "levelTenthsDB"
        ].compactMap { field in
            snapshotDifferencePaths.contains("ambience.\(field)")
                ? TD17SnapshotAmbienceRestore(field: field)
                : nil
        }
    }

    func restoreSnapshotAmbienceField(
        _ restore: TD17SnapshotAmbienceRestore
    ) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              snapshotDifferencePaths.contains("ambience.\(restore.field)"),
              let values = importedSnapshot["ambience"] as? [String: Any]
        else {
            appendLog("Ambience restore blocked: inconsistent data or kit")
            status = "Ambience cannot be restored safely"
            return
        }

        let valueText: String
        var action: (() -> Void)?
        switch restore.field {
        case "enabled":
            guard let value = values[restore.field] as? Bool else { return }
            valueText = value ? "ON" : "OFF"
            action = { [weak self] in
                self?.ambienceEnabledDraft = value
                self?.writeAmbienceEnabled()
            }
        case "levelTenthsDB":
            guard let value = values[restore.field] as? Int,
                  Self.effectLevelRange.contains(value)
            else { return }
            valueText = levelText(value)
            action = { [weak self] in
                self?.ambienceLevelDraft = value
                self?.writeAmbienceLevel()
            }
        case "roomShape":
            guard let value = values[restore.field] as? Int,
                  (0...100).contains(value)
            else { return }
            valueText = "\(value)"
            action = { [weak self] in
                self?.ambienceRoomShapeDraft = value
                self?.writeAmbienceParameter(2)
            }
        default:
            let fields = ["roomType", "roomSize", "wallType", "micPosition"]
            let parameterIndices = [0, 1, 3, 4]
            let catalogs = [
                TD17AmbienceCatalog.roomTypes,
                TD17AmbienceCatalog.roomSizes,
                TD17AmbienceCatalog.wallTypes,
                TD17AmbienceCatalog.micPositions
            ]
            guard let fieldIndex = fields.firstIndex(of: restore.field),
                  let value = values[restore.field] as? String,
                  let valueIndex = catalogs[fieldIndex].firstIndex(of: value)
            else { return }
            valueText = value
            action = { [weak self] in
                guard let self else { return }
                switch fieldIndex {
                case 0: self.ambienceRoomTypeDraft = valueIndex
                case 1: self.ambienceRoomSizeDraft = valueIndex
                case 2: self.ambienceWallTypeDraft = valueIndex
                default: self.ambienceMicPositionDraft = valueIndex
                }
                self.writeAmbienceParameter(parameterIndices[fieldIndex])
            }
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the chosen Ambience field will be "
            + "ustawione na \(valueText)."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + valueText
        )
        action?()
    }

    var restorableSnapshotReverbFields: [TD17SnapshotReverbRestore] {
        [
            "enabled", "type", "preDelay", "timeTenths", "density",
            "diffusion", "lowDamp", "highDamp", "spread", "tone",
            "levelTenthsDB"
        ].compactMap { field in
            snapshotDifferencePaths.contains("reverb.\(field)")
                ? TD17SnapshotReverbRestore(field: field)
                : nil
        }
    }

    func restoreSnapshotReverbField(_ restore: TD17SnapshotReverbRestore) {
        let numericFields = [
            "preDelay", "timeTenths", "density", "diffusion",
            "lowDamp", "highDamp", "spread", "tone"
        ]
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              snapshotDifferencePaths.contains("reverb.\(restore.field)"),
              let values = importedSnapshot["reverb"] as? [String: Any]
        else {
            appendLog("Reverb restore blocked: inconsistent data or kit")
            status = "Reverb cannot be restored safely"
            return
        }

        let valueText: String
        var parameterIndex: Int
        if restore.field == "enabled" {
            guard let value = values[restore.field] as? Bool else { return }
            reverbEnabledDraft = value
            parameterIndex = 0
            valueText = value ? "ON" : "OFF"
        } else if restore.field == "type" {
            let types = TD17ReverbCatalog.types
            guard let value = values[restore.field] as? String,
                  let index = types.firstIndex(of: value)
            else { return }
            reverbTypeDraft = index
            parameterIndex = 1
            valueText = value
        } else if restore.field == "levelTenthsDB" {
            guard let value = values[restore.field] as? Int,
                  Self.effectLevelRange.contains(value)
            else { return }
            reverbLevelDraft = value
            parameterIndex = 10
            valueText = levelText(value)
        } else {
            guard let numericIndex = numericFields.firstIndex(
                of: restore.field
            ),
            let value = values[restore.field] as? Int,
            (0...127).contains(value)
            else { return }
            reverbParameterDrafts[numericIndex] = value
            parameterIndex = numericIndex + 2
            valueText = reverbValueText(parameterIndex, value)
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the chosen Reverb field will be "
            + "ustawione na \(valueText)."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + valueText
        )
        writeReverb(parameterIndex)
    }

    var restorableSnapshotMFXFields: [TD17SnapshotMFXRestore] {
        var result: [TD17SnapshotMFXRestore] = []
        if snapshotDifferencePaths.contains("mfx.enabled") {
            result.append(TD17SnapshotMFXRestore(parameterIndex: 0))
        }
        if snapshotDifferencePaths.contains("mfx.type") {
            result.append(TD17SnapshotMFXRestore(parameterIndex: 1))
        }
        if snapshotDifferencePaths.contains("mfx.levelTenthsDB") {
            result.append(TD17SnapshotMFXRestore(parameterIndex: 2))
        }
        for index in 0..<32
        where snapshotDifferencePaths.contains("mfx.parameters[\(index)]") {
            result.append(TD17SnapshotMFXRestore(parameterIndex: index + 3))
        }
        return result
    }

    func restoreSnapshotMFXField(_ restore: TD17SnapshotMFXRestore) {
        guard canStartSingleRestore,
              (0...34).contains(restore.parameterIndex),
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              let values = importedSnapshot["mfx"] as? [String: Any]
        else {
            appendLog("MFX restore blocked: inconsistent data or kit")
            status = "MFX cannot be restored safely"
            return
        }

        let differencePath: String
        let valueText: String
        switch restore.parameterIndex {
        case 0:
            differencePath = "mfx.enabled"
            guard snapshotDifferencePaths.contains(differencePath),
                  let value = values["enabled"] as? Bool
            else { return }
            mfxEnabledDraft = value
            valueText = value ? "ON" : "OFF"
        case 1:
            differencePath = "mfx.type"
            guard snapshotDifferencePaths.contains(differencePath),
                  let value = values["type"] as? String,
                  let index = TD17MFXCatalog.types.firstIndex(of: value)
            else { return }
            mfxTypeDraft = index
            valueText = value
        case 2:
            differencePath = "mfx.levelTenthsDB"
            guard snapshotDifferencePaths.contains(differencePath),
                  let value = values["levelTenthsDB"] as? Int,
                  Self.effectLevelRange.contains(value)
            else { return }
            mfxLevelDraft = value
            valueText = levelText(value)
        default:
            let rawIndex = restore.parameterIndex - 3
            differencePath = "mfx.parameters[\(rawIndex)]"
            guard snapshotDifferencePaths.contains(differencePath),
                  let parameters = values["parameters"] as? [Int],
                  parameters.indices.contains(rawIndex),
                  (-32768...32767).contains(parameters[rawIndex])
            else { return }
            let value = parameters[rawIndex]
            mfxParameterDrafts[rawIndex] = value
            valueText = "\(value)"
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the chosen MFX field will be "
            + "ustawione na \(valueText)."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + valueText
        )
        writeMFX(restore.parameterIndex)
    }

    private var masterCompSnapshotFields: [String] {
        [
            "splitFrequency", "lowGain", "highGain",
            "lowThreshold", "highThreshold",
            "lowRatio", "highRatio", "lowKnee", "highKnee",
            "lowAttack", "highAttack", "lowRelease", "highRelease",
            "balance"
        ]
    }

    var restorableSnapshotMasterCompFields: [TD17SnapshotMasterCompRestore] {
        var result: [TD17SnapshotMasterCompRestore] = []
        if snapshotDifferencePaths.contains("masterComp.enabled") {
            result.append(TD17SnapshotMasterCompRestore(parameterIndex: 0))
        }
        if snapshotDifferencePaths.contains("masterComp.type") {
            result.append(TD17SnapshotMasterCompRestore(parameterIndex: 1))
        }
        for index in masterCompSnapshotFields.indices
        where snapshotDifferencePaths.contains(
            "masterComp.\(masterCompSnapshotFields[index])"
        ) {
            result.append(
                TD17SnapshotMasterCompRestore(parameterIndex: index + 2)
            )
        }
        return result
    }

    func restoreSnapshotMasterCompField(
        _ restore: TD17SnapshotMasterCompRestore
    ) {
        guard canStartSingleRestore,
              (0...15).contains(restore.parameterIndex),
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              let values = importedSnapshot["masterComp"] as? [String: Any]
        else {
            appendLog("Master Comp restore blocked: inconsistent data or kit")
            status = "Master Comp cannot be restored safely"
            return
        }

        let differencePath: String
        let valueText: String
        switch restore.parameterIndex {
        case 0:
            differencePath = "masterComp.enabled"
            guard snapshotDifferencePaths.contains(differencePath),
                  let value = values["enabled"] as? Bool
            else { return }
            masterCompEnabledDraft = value
            valueText = value ? "ON" : "OFF"
        case 1:
            differencePath = "masterComp.type"
            guard snapshotDifferencePaths.contains(differencePath),
                  let value = values["type"] as? String,
                  let index = TD17MasterCompCatalog.types.firstIndex(of: value)
            else { return }
            masterCompTypeDraft = index
            valueText = value
        default:
            let rawIndex = restore.parameterIndex - 2
            guard masterCompSnapshotFields.indices.contains(rawIndex) else {
                return
            }
            let field = masterCompSnapshotFields[rawIndex]
            differencePath = "masterComp.\(field)"
            guard snapshotDifferencePaths.contains(differencePath),
                  let value = values[field] as? Int
            else { return }
            let valid: Bool
            if rawIndex == 0 {
                valid = (0...65535).contains(value)
            } else if (1...4).contains(rawIndex) {
                valid = (-128...127).contains(value)
            } else {
                valid = (0...127).contains(value)
            }
            guard valid else { return }
            masterCompParameterDrafts[rawIndex] = value
            valueText = masterCompValueText(restore.parameterIndex, value)
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the chosen Master Comp field "
            + "will be set to \(valueText)."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + valueText
        )
        writeMasterComp(restore.parameterIndex)
    }

    var restorableSnapshotMIDINotes: [TD17SnapshotMIDINoteRestore] {
        guard let importedSnapshot,
              let items = importedSnapshot["midiNotes"] as? [[String: Any]]
        else { return [] }
        return items.compactMap { item in
            guard let index = item["index"] as? Int,
                  midiNotes.indices.contains(index),
                  snapshotDifferencePaths.contains(
                    "midiNotes[\(index)].note"
                  )
            else { return nil }
            return TD17SnapshotMIDINoteRestore(
                index: index,
                name: midiNotes[index].name
            )
        }
    }

    func restoreSnapshotMIDINote(_ restore: TD17SnapshotMIDINoteRestore) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              midiNotes.indices.contains(restore.index),
              snapshotDifferencePaths.contains(
                "midiNotes[\(restore.index)].note"
              ),
              let items = importedSnapshot["midiNotes"] as? [[String: Any]],
              items.indices.contains(restore.index),
              items[restore.index]["index"] as? Int == restore.index,
              items[restore.index]["zone"] as? String
                == midiNotes[restore.index].name,
              let note = items[restore.index]["note"] as? Int,
              (0...128).contains(note)
        else {
            appendLog("MIDI restore blocked: inconsistent data or kit")
            status = "The MIDI note cannot be restored safely"
            return
        }

        let noteText = TD17MIDINoteCatalog.text(note)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only the assignment \(restore.name) "
            + "will be set to \(noteText)."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn {
            appendLog("Restore cancelled: \(restore.label)")
            return
        }

        midiNoteDrafts[restore.index] = note
        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → "
                + noteText
        )
        writeMIDINote(index: restore.index)
    }

    var restorableSnapshotVEdits: [TD17SnapshotVEditRestore] {
        guard let importedSnapshot else { return [] }
        var result: [TD17SnapshotVEditRestore] = []
        for (isSub, key) in [(false, "vEditMain"), (true, "vEditSub")] {
            guard let items = importedSnapshot[key] as? [[String: Any]] else {
                continue
            }
            for (arrayIndex, item) in items.enumerated() {
                guard let zoneIndex = item["zoneIndex"] as? Int,
                      zoneNames.indices.contains(zoneIndex)
                else { continue }
                for (field, jsonKey) in [
                    (1, "primary"), (2, "secondary"), (3, "tertiary")
                ] {
                    let path = "\(key)[\(arrayIndex)].\(jsonKey)"
                    if snapshotDifferencePaths.contains(path) {
                        result.append(
                            TD17SnapshotVEditRestore(
                                zoneIndex: zoneIndex,
                                snapshotArrayIndex: arrayIndex,
                                isSub: isSub,
                                field: field,
                                zoneName: zoneNames[zoneIndex]
                            )
                        )
                    }
                }
            }
        }
        return result
    }

    func restoreSnapshotVEdit(_ restore: TD17SnapshotVEditRestore) {
        guard canStartSingleRestore,
              let importedSnapshot,
              let snapshotKit = importedSnapshot["kitNumber"] as? Int,
              let currentKitNumber,
              isSnapshotAuthorized(snapshotKit: snapshotKit, currentKit: currentKitNumber),
              (1...3).contains(restore.field)
        else {
            appendLog("Restore V-Edit zablokowany: niezgodny kit")
            return
        }

        let section = restore.isSub ? "vEditSub" : "vEditMain"
        let jsonKey = ["", "primary", "secondary", "tertiary"][restore.field]
        guard let items = importedSnapshot[section] as? [[String: Any]],
              items.indices.contains(restore.snapshotArrayIndex),
              items[restore.snapshotArrayIndex]["zoneIndex"] as? Int
                == restore.zoneIndex,
              let value = items[restore.snapshotArrayIndex][jsonKey] as? Int
        else {
            appendLog("V-Edit restore blocked: inconsistent snapshot data")
            return
        }

        let edit = restore.isSub
            ? subVEdits.first(where: { $0.zoneIndex == restore.zoneIndex })
            : vEdits.first(where: { $0.zoneIndex == restore.zoneIndex })
        guard let edit else {
            appendLog("V-Edit restore blocked: no active zone")
            return
        }
        let allowedRange: ClosedRange<Int>
        if restore.field == 1 {
            allowedRange = edit.supportsTuning
                ? -100...100
                : (edit.isCymbal ? 0...78 : -4800...4800)
        } else {
            allowedRange = vEditRange(
                group: edit.instrumentGroup,
                parameter: restore.field
            )
        }
        guard allowedRange.contains(value) else {
            appendLog("V-Edit restore blocked: value out of range")
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Restore \(restore.label)?"
        alert.informativeText =
            "Kit \(currentKitNumber): only one V-Edit field will be written "
            + "with the value \(value)."
        alert.addButton(withTitle: "Restore and verify")
        alert.addButton(withTitle: "Cancel")
        if !isBatchRestoring, alert.runModal() != .alertFirstButtonReturn { return }

        if restore.field == 1 {
            if restore.isSub {
                subTuningDrafts[restore.zoneIndex] = value
            } else {
                mainTuningDrafts[restore.zoneIndex] = value
            }
        } else if restore.field == 2 {
            if restore.isSub {
                subVEditSecondDrafts[restore.zoneIndex] = value
            } else {
                mainVEditSecondDrafts[restore.zoneIndex] = value
            }
        } else if restore.isSub {
            subVEditThirdDrafts[restore.zoneIndex] = value
        } else {
            mainVEditThirdDrafts[restore.zoneIndex] = value
        }

        appendLog(
            "RESTORE: Kit \(currentKitNumber), only \(restore.label) → \(value)"
        )
        if restore.field == 1 {
            writeVEditTuning(
                zoneIndex: restore.zoneIndex,
                isSub: restore.isSub
            )
        } else {
            writeVEditParameter(
                zoneIndex: restore.zoneIndex,
                parameter: restore.field,
                isSub: restore.isSub
            )
        }
    }

    private func friendlyPath(_ path: String) -> String {
        path
            .replacingOccurrences(of: "common.", with: "Settings • ")
            .replacingOccurrences(of: "main[", with: "MAIN[")
            .replacingOccurrences(of: "sub[", with: "SUB[")
            .replacingOccurrences(of: "mixer[", with: "Mikser[")
            .replacingOccurrences(of: "vEditMain[", with: "V-Edit MAIN[")
            .replacingOccurrences(of: "vEditSub[", with: "V-Edit SUB[")
            .replacingOccurrences(of: "midiNotes[", with: "MIDI[")
    }

    private enum SnapshotError: LocalizedError {
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case let .invalid(message): message
            }
        }
    }

    private func validateSnapshot(
        _ root: [String: Any]
    ) throws -> (summary: String, details: [String]) {
        let allowedRootKeys: Set<String> = [
            "format", "formatVersion", "exportedAt", "kitNumber", "common",
            "main", "sub", "vEditMain", "vEditSub", "mixer",
            "ambience", "reverb", "mfx", "masterComp", "midiNotes"
        ]
        guard Set(root.keys) == allowedRootKeys else {
            throw SnapshotError.invalid(
                "The file has missing or forbidden sections"
            )
        }
        guard root["format"] as? String == "PulsoKit TD-17 Snapshot" else {
            throw SnapshotError.invalid("Unknown file format")
        }
        guard root["formatVersion"] as? Int == 1 else {
            throw SnapshotError.invalid("Unsupported snapshot version")
        }
        guard let kitNumber = root["kitNumber"] as? Int,
              (1...profile.kitCount).contains(kitNumber),
              let common = root["common"] as? [String: Any],
              let name = common["name"] as? String
        else {
            throw SnapshotError.invalid("No valid kit data")
        }
        let allowedCommonKeys: Set<String> = [
            "name", "subName", "kitVolumeTenthsDB",
            "pedalHiHatVolumeTenthsDB", "crossStickVolumeTenthsDB",
            "crossStickEnabled", "hiHatBalance"
        ]
        guard Set(common.keys) == allowedCommonKeys,
              isSafeKitText(name, maximumBytes: 12),
              let subName = common["subName"] as? String,
              isSafeKitText(subName, maximumBytes: 16),
              validInteger(common["kitVolumeTenthsDB"], in: -601...60),
              validInteger(common["pedalHiHatVolumeTenthsDB"], in: -601...60),
              validInteger(common["crossStickVolumeTenthsDB"], in: -601...60),
              common["crossStickEnabled"] is Bool,
              validInteger(common["hiHatBalance"], in: -64...63)
        else {
            throw SnapshotError.invalid("Invalid Kit Common settings")
        }
        guard let exportedAt = root["exportedAt"] as? String,
              ISO8601DateFormatter().date(from: exportedAt) != nil
        else {
            throw SnapshotError.invalid("Invalid export date")
        }

        let requirements = [
            ("main", 20), ("sub", 20), ("vEditMain", 20),
            ("mixer", 20), ("midiNotes", 24)
        ]
        for (key, expectedCount) in requirements {
            guard let items = root[key] as? [[String: Any]],
                  items.count == expectedCount
            else {
                throw SnapshotError.invalid(
                    "Section \(key) does not contain \(expectedCount) entries"
                )
            }
        }

        try validateIndices(root, key: "main", indexKey: "zoneIndex", count: 20)
        try validateIndices(root, key: "sub", indexKey: "zoneIndex", count: 20)
        try validateIndices(root, key: "mixer", indexKey: "zoneIndex", count: 20)
        try validateIndices(root, key: "midiNotes", indexKey: "index", count: 24)
        // Bez tego dwadzieścia wpisów V-Edit mogło wskazywać na tę samą
        // strefę: podgląd meldował „20 stref MAIN", a szybki zapis wysyłał
        // dwadzieścia bloków pod jeden adres, zostawiając pozostałe
        // dziewiętnaście pól nietkniętych i nikomu o tym nie mówiąc.
        try validateIndices(root, key: "vEditMain", indexKey: "zoneIndex", count: 20)
        // `vEditSub` ma zmienną liczbę wpisów — tyle, ile stref ma włączoną
        // warstwę SUB — więc nie da się wymagać dwudziestu. Wystarczy, że
        // numery stref są sensowne i że żaden się nie powtarza.
        try validateUniqueIndices(root, key: "vEditSub", indexKey: "zoneIndex", limit: 20)
        try validateZoneNames(root, key: "main")
        try validateZoneNames(root, key: "sub")
        try validateZoneNames(root, key: "mixer")
        try validateSnapshotInstruments(root, key: "main")
        try validateSnapshotInstruments(root, key: "sub")

        guard root["ambience"] is [String: Any],
              root["reverb"] is [String: Any],
              root["mfx"] is [String: Any],
              root["masterComp"] is [String: Any]
        else {
            throw SnapshotError.invalid("Effect or compressor data is missing")
        }

        let activeSub = (root["sub"] as? [[String: Any]])?
            .filter { $0["enabled"] as? Bool == true }.count ?? 0
        let subVEdit = (root["vEditSub"] as? [[String: Any]])?.count ?? 0
        guard activeSub == subVEdit else {
            throw SnapshotError.invalid(
                "The number of active SUB layers does not match SUB V-Edit"
            )
        }

        return (
            "Kit \(kitNumber): \(name)",
            [
                subName.isEmpty ? "Description: —" : "Description: \(subName)",
                "20 MAIN zones • 20 SUB zones (\(activeSub) active)",
                "20 mixer blocks • 24 MIDI notes",
                // „Obecne", nie „kompletne". Na tym etapie sprawdzone jest
                // tylko to, że te cztery sekcje w ogóle są — ich zawartość
                // waliduje się dopiero przy zapisie. Napis o kompletności był
                // obietnicą, której podgląd nie miał pokrycia czym spełnić,
                // a stoi tuż nad przyciskiem nadpisującym cały kit.
                "Ambience, Reverb, MFX and Master Comp: present",
                "Preview mode — nothing was sent to the TD-17"
            ]
        )
    }

    private func validateZoneNames(
        _ root: [String: Any],
        key: String
    ) throws {
        guard let items = root[key] as? [[String: Any]] else {
            throw SnapshotError.invalid("Missing section \(key)")
        }
        for item in items {
            guard let index = item["zoneIndex"] as? Int,
                  zoneNames.indices.contains(index),
                  item["zone"] as? String == zoneNames[index]
            else {
                throw SnapshotError.invalid(
                    "Section \(key) contains an invalid zone name"
                )
            }
        }
    }

    private func validateSnapshotInstruments(
        _ root: [String: Any],
        key: String
    ) throws {
        guard let items = root[key] as? [[String: Any]] else {
            throw SnapshotError.invalid("Missing section \(key)")
        }
        for item in items {
            guard let instrument = item["instrument"] as? [String: Any],
                  Set(instrument.keys) == Set([
                      "id", "name", "group", "levelTenthsDB", "userSample"
                  ]),
                  let instrumentID = instrument["id"] as? Int,
                  let name = instrument["name"] as? String,
                  let group = instrument["group"] as? String,
                  let userSample = instrument["userSample"] as? Bool,
                  validInteger(instrument["levelTenthsDB"], in: -601...60)
            else {
                throw SnapshotError.invalid(
                    "Section \(key) contains an invalid instrument"
                )
            }

            if userSample {
                guard (0...99).contains(instrumentID),
                      name == String(
                          format: "User Sample U%03d",
                          instrumentID + 1
                      ),
                      group == "USER SAMPLE"
                else {
                    throw SnapshotError.invalid(
                        "Invalid User Sample data in section \(key)"
                    )
                }
            } else {
                guard TD17InstrumentCatalog.instruments.indices
                    .contains(instrumentID)
                else {
                    throw SnapshotError.invalid(
                        "Instrument spoza katalogu TD-17"
                    )
                }
                let definition = TD17InstrumentCatalog.instruments[instrumentID]
                guard name == definition.name, group == definition.group else {
                    throw SnapshotError.invalid(
                        "The instrument name does not match its ID"
                    )
                }
            }
        }
    }

    private func isSafeKitText(
        _ value: String,
        maximumBytes: Int
    ) -> Bool {
        value.utf8.count <= maximumBytes
            && value.unicodeScalars.allSatisfy {
                $0.isASCII
                    && !CharacterSet.controlCharacters.contains($0)
            }
    }

    private func validInteger(
        _ value: Any?,
        in range: ClosedRange<Int>
    ) -> Bool {
        guard let value = value as? Int else { return false }
        return range.contains(value)
    }

    private func validateJSONTree(_ value: Any, depth: Int) throws {
        guard depth <= 8 else {
            throw SnapshotError.invalid("The JSON structure is too deep")
        }
        if let dictionary = value as? [String: Any] {
            guard dictionary.count <= 64 else {
                throw SnapshotError.invalid("The JSON object has too many fields")
            }
            for (key, child) in dictionary {
                guard key.count <= 64,
                      key.unicodeScalars.allSatisfy({
                          !CharacterSet.controlCharacters.contains($0)
                      })
                else {
                    throw SnapshotError.invalid("Forbidden JSON field name")
                }
                try validateJSONTree(child, depth: depth + 1)
            }
        } else if let array = value as? [Any] {
            guard array.count <= 128 else {
                throw SnapshotError.invalid("The JSON array is too large")
            }
            for child in array {
                try validateJSONTree(child, depth: depth + 1)
            }
        } else if let string = value as? String {
            guard string.utf8.count <= 256,
                  string.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  })
            else {
                throw SnapshotError.invalid(
                    "The text has forbidden characters or is too long"
                )
            }
        } else if let number = value as? NSNumber {
            let double = number.doubleValue
            guard double.isFinite, abs(double) <= 1_000_000 else {
                throw SnapshotError.invalid("Liczba JSON przekracza bezpieczny zakres")
            }
        } else if !(value is NSNull) {
            throw SnapshotError.invalid("Unsupported JSON data type")
        }
    }

    private func validateIndices(
        _ root: [String: Any],
        key: String,
        indexKey: String,
        count: Int
    ) throws {
        guard let items = root[key] as? [[String: Any]] else {
            throw SnapshotError.invalid("Missing section \(key)")
        }
        let indices = items.compactMap { $0[indexKey] as? Int }.sorted()
        guard indices == Array(0..<count) else {
            throw SnapshotError.invalid(
                "Section \(key) has missing or duplicated indices"
            )
        }
    }

    /// Sekcja o zmiennej długości: numery muszą mieścić się w zakresie
    /// i nie mogą się powtarzać.
    ///
    /// Powtórzony numer strefy znaczy, że dwa bloki jadą pod ten sam adres,
    /// a strefa, której brakuje, zostaje w module nietknięta — mimo że
    /// podsumowanie przed zapisem policzyło ją jako przygotowaną.
    private func validateUniqueIndices(
        _ root: [String: Any],
        key: String,
        indexKey: String,
        limit: Int
    ) throws {
        guard let items = root[key] as? [[String: Any]] else {
            throw SnapshotError.invalid("Missing section \(key)")
        }
        let indices = items.compactMap { $0[indexKey] as? Int }
        guard indices.count == items.count,
              indices.allSatisfy({ (0..<limit).contains($0) }),
              Set(indices).count == indices.count
        else {
            throw SnapshotError.invalid(
                "Section \(key) has invalid or duplicated indices"
            )
        }
    }

    private func snapshotDictionary(
        kitNumber: Int,
        common: TD17KitCommonInfo
    ) -> [String: Any] {
        func instrument(_ value: TD17InstrumentInfo) -> [String: Any] {
            [
                "id": value.instrumentID,
                "name": value.displayName,
                "group": value.groupName,
                "levelTenthsDB": value.levelTenthsDB,
                "userSample": value.isUserSample
            ]
        }

        let ambienceJSON: Any = ambience.map {
            [
                "enabled": $0.enabled, "roomType": $0.roomType,
                "roomSize": $0.roomSize, "roomShape": $0.roomShape,
                "wallType": $0.wallType, "micPosition": $0.micPosition,
                "levelTenthsDB": $0.level
            ] as [String: Any]
        } ?? NSNull()
        let reverbJSON: Any = reverb.map {
            [
                "enabled": $0.enabled, "type": $0.type,
                "preDelay": $0.preDelay, "timeTenths": $0.time,
                "density": $0.density, "diffusion": $0.diffusion,
                "lowDamp": $0.lowDamp, "highDamp": $0.highDamp,
                "spread": $0.spread, "tone": $0.tone,
                "levelTenthsDB": $0.level
            ] as [String: Any]
        } ?? NSNull()
        let mfxJSON: Any = mfx.map {
            [
                "enabled": $0.enabled, "type": $0.type,
                "levelTenthsDB": $0.level, "parameters": $0.parameters
            ] as [String: Any]
        } ?? NSNull()
        let masterCompJSON: Any = masterComp.map {
            [
                "enabled": $0.enabled, "type": $0.type,
                "splitFrequency": $0.splitFrequency,
                "lowGain": $0.lowGain, "highGain": $0.highGain,
                "lowThreshold": $0.lowThreshold,
                "highThreshold": $0.highThreshold,
                "lowRatio": $0.lowRatio, "highRatio": $0.highRatio,
                "lowKnee": $0.lowKnee, "highKnee": $0.highKnee,
                "lowAttack": $0.lowAttack, "highAttack": $0.highAttack,
                "lowRelease": $0.lowRelease, "highRelease": $0.highRelease,
                "balance": $0.balance
            ] as [String: Any]
        } ?? NSNull()

        return [
            "format": "PulsoKit TD-17 Snapshot",
            "formatVersion": 1,
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "kitNumber": kitNumber,
            "common": [
                "name": common.name, "subName": common.subName,
                "kitVolumeTenthsDB": common.kitVolume,
                "pedalHiHatVolumeTenthsDB": common.pedalHiHatVolume,
                "crossStickVolumeTenthsDB": common.crossStickVolume,
                "crossStickEnabled": common.crossStickEnabled,
                "hiHatBalance": common.hiHatBalance
            ],
            "main": zones.map {
                [
                    "zoneIndex": $0.index, "zone": $0.name,
                    "instrument": instrument($0.instrument)
                ] as [String: Any]
            },
            "sub": layers.map {
                [
                    "zoneIndex": $0.zoneIndex, "zone": $0.zoneName,
                    "enabled": $0.enabled, "layerType": $0.layerType,
                    "fadePoint": $0.fadePoint,
                    "instrument": instrument($0.instrument)
                ] as [String: Any]
            },
            "vEditMain": vEdits.map {
                [
                    "zoneIndex": $0.zoneIndex, "zone": $0.zoneName,
                    "group": $0.instrumentGroup,
                    "primary": $0.primaryValue,
                    "secondary": $0.secondaryValue,
                    "tertiary": $0.tertiaryValue
                ] as [String: Any]
            },
            "vEditSub": subVEdits.map {
                [
                    "zoneIndex": $0.zoneIndex, "zone": $0.zoneName,
                    "group": $0.instrumentGroup,
                    "primary": $0.primaryValue,
                    "secondary": $0.secondaryValue,
                    "tertiary": $0.tertiaryValue
                ] as [String: Any]
            },
            "mixer": mixInfos.map {
                [
                    "zoneIndex": $0.zoneIndex, "zone": $0.zoneName,
                    "pan": $0.pan, "eqEnabled": $0.eqEnabled,
                    "lowFrequency": $0.lowFrequency, "lowGain": $0.lowGain,
                    "midFrequency": $0.midFrequency, "midQ": $0.midQ,
                    "midGain": $0.midGain,
                    "highFrequency": $0.highFrequency, "highGain": $0.highGain,
                    "ambienceSendTenthsDB": $0.ambienceSend,
                    "mfxSendTenthsDB": $0.mfxSend,
                    "reverbSendTenthsDB": $0.reverbSend
                ] as [String: Any]
            },
            "ambience": ambienceJSON,
            "reverb": reverbJSON,
            "mfx": mfxJSON,
            "masterComp": masterCompJSON,
            "midiNotes": midiNotes.map {
                ["index": $0.index, "zone": $0.name, "note": $0.note]
            }
        ]
    }

    private func createMIDIClient() {
        let clientResult = MIDIClientCreateWithBlock(
            "PulsoKit" as CFString,
            &client
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleDeviceRefresh()
            }
        }

        guard clientResult == noErr else {
            status = "Could not start CoreMIDI"
            appendLog("CoreMIDI client error: \(clientResult)")
            return
        }

        // Każdy callback CoreMIDI tworzył wcześniej osobne `Task`.
        // Swift nie gwarantuje kolejności wykonania niezależnych zadań,
        // a odbiór SysEx składa ramkę bajt po bajcie — zamiana dwóch
        // porcji miejscami cicho psuła dane. Teraz wszystko idzie przez
        // jeden strumień, konsumowany po kolei.
        //
        // Bufor jest ograniczony. Domyślna polityka `.unbounded` znaczy, że
        // kolejka rośnie tak długo, jak długo nadawca wyprzedza odbiorcę —
        // a odbiorcą jest główny wątek, dzielony z całym interfejsem.
        // Wystarczyłoby jedno gadatliwe (albo złośliwe) źródło MIDI, żeby
        // zapchać pamięć i doprowadzić do zabicia programu przez system.
        // Przy takim zalewie składana ramka i tak jest stracona, a `receive`
        // łapie synchronizację na następnym `0xF0`.
        let (incoming, continuation) = AsyncStream.makeStream(
            of: [UInt8].self,
            bufferingPolicy: .bufferingNewest(512)
        )
        incomingContinuation = continuation

        let inputResult = MIDIInputPortCreateWithBlock(
            client,
            "PulsoKit Input" as CFString,
            &inputPort
        ) { packetList, _ in
            continuation.yield(Self.bytes(from: packetList))
        }

        incomingTask = Task { @MainActor [weak self] in
            for await bytes in incoming {
                guard let self else { return }
                self.receive(bytes)
            }
        }

        let outputResult = MIDIOutputPortCreate(
            client,
            "PulsoKit Output" as CFString,
            &outputPort
        )

        if inputResult != noErr {
            appendLog("CoreMIDI input error: \(inputResult)")
        }
        if outputResult != noErr {
            appendLog("CoreMIDI output error: \(outputResult)")
        }
    }

    private func receive(_ bytes: [UInt8]) {
        for byte in bytes {
            // System Real-Time (0xF8–0xFF) wolno wysłać w dowolnym momencie,
            // również w środku ramki SysEx. TD-17 wysyła Active Sensing (0xFE),
            // więc te bajty muszą zostać pominięte, zanim trafią do bufora —
            // inaczej psują sumę kontrolną i cały odczyt stoi do watchdoga.
            if byte >= 0xF8 { continue }

            if byte == 0xF0 {
                if !sysExBuffer.isEmpty {
                    appendLog(
                        "RX: dropped an unfinished SysEx frame "
                            + "(\(sysExBuffer.count) B)"
                    )
                }
                sysExBuffer = [byte]
                pendingProgramChangeStatus = nil
                continue
            }

            guard !sysExBuffer.isEmpty else {
                handleChannelByte(byte)
                continue
            }

            if byte == 0xF7 {
                sysExBuffer.append(byte)
                let message = sysExBuffer
                sysExBuffer.removeAll(keepingCapacity: true)
                appendLog("RX: \(hex(message))")
                decodeIdentityReply(message)
                decodeDT1(message)
                continue
            }

            if byte >= 0x80 {
                // Każdy inny bajt statusu kończy ramkę SysEx przedwcześnie.
                appendLog("RX: przerwana ramka SysEx (status \(hex([byte])))")
                sysExBuffer.removeAll(keepingCapacity: true)
                handleChannelByte(byte)
                continue
            }

            sysExBuffer.append(byte)

            if sysExBuffer.count > maximumSysExLength {
                appendLog(
                    "RX: SysEx frame exceeded \(maximumSysExLength) B — "
                        + "dropped"
                )
                sysExBuffer.removeAll(keepingCapacity: true)
            }
        }
    }

    private func handleChannelByte(_ byte: UInt8) {
        if byte & 0xF0 == 0xC0 {
            pendingProgramChangeStatus = byte
        } else if byte < 0x80, pendingProgramChangeStatus != nil {
            handleProgramChange(program: Int(byte))
        } else if byte >= 0x80 {
            pendingProgramChangeStatus = nil
        }
    }

    private func handleProgramChange(program: Int) {
        guard automaticallyReadChangedKit else { return }
        // Przy nieznanej mapie każdy obrót pokrętłem uruchamiał dwa odczyty,
        // z których każdy kończył się linią „nie mam mapy". Numer kitu
        // zapamiętujemy — przyda się sondzie — ale odczytu nie zaczynamy.
        guard profile.hasVerifiedMap else {
            let number = program + 1
            if (1...profile.kitCount).contains(number) { currentKitNumber = number }
            return
        }
        // Program Change przestawia numer bieżącego kitu, a z tego numeru
        // liczy się adres każdego kolejnego zapisu. Słuchamy go więc dopiero
        // wtedy, gdy mamy powód sądzić, że po drugiej stronie jest TD-17 —
        // a nie dowolny port, który akurat coś wysłał.
        guard rolandIdentityDetected || selectedPortsLookLikeTD17 else {
            appendLog("Program Change ignored — the module is not confirmed")
            return
        }
        let kitNumber = program + 1
        guard (1...profile.kitCount).contains(kitNumber) else { return }

        automaticKitReadTask?.cancel()

        if isReadingKit, isQuickRead {
            readGeneration += 1
            isReadingKit = false
            isQuickRead = false
            readPhase = .idle
            appendLog("AUTO: previous quick read cancelled")
        }

        guard !isOperationInProgress else {
            // Numeru kitu **nie** ruszamy: zapisy biorą go w chwili wysyłki,
            // więc podmiana w środku serii wpisałaby zmiany do innego kitu.
            // Zamiast tego zapamiętujemy, że trzeba się zsynchronizować,
            // i robimy to po zakończeniu bieżącej operacji.
            needsKitReconcile = true
            appendLog(
                "AUTO: detected kit \(kitNumber), but an operation is running — "
                    + "read will follow once it finishes"
            )
            scheduleDeferredFullRead(for: nil)
            return
        }

        currentKitNumber = kitNumber
        // Nazwa i wszystkie bloki szczegółowe opisują jeszcze poprzedni kit.
        // Zostawione, kłamałyby razem z nowym numerem — a gdyby odczyt się
        // nie udał, `kitCommon` blokowałoby jego ponowienie.
        currentKitName = nil
        kitCommon = nil
        midiNotes = []
        status = "Detected kit \(kitNumber) — preparing to read…"
        appendLog("AUTO: kit changed to \(kitNumber)")

        automaticKitReadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard let self, !Task.isCancelled else { return }
            guard !self.isOperationInProgress else {
                self.appendLog(
                    "AUTO: read of kit \(kitNumber) skipped — another operation is running"
                )
                return
            }
            self.appendLog("AUTO: reading kit \(kitNumber)")
            self.nextReadShouldBeQuick = true
            self.readCurrentKit()
        }

        scheduleDeferredFullRead(for: kitNumber)
    }

    /// Dociąga resztę danych, gdy wybór kitu na module się ustabilizuje.
    ///
    /// Szybki odczyt (nazwa, instrumenty, poziomy) leci od razu, bo ma być
    /// widać, co jest wybrane. Pełny trwa ok. 3 s i kasuje niewysłane zmiany,
    /// więc puszczanie go przy każdym kliknięciu pokrętła nie miałoby sensu —
    /// czeka, aż przez `deferredFullReadDelaySeconds` nic się nie zmieni.
    /// `kitNumber == nil` znaczy „dogadaj się z modułem, gdy tylko będzie
    /// można" — używane wtedy, gdy zmiana kitu przyszła w środku innej
    /// operacji i numeru celowo nie ruszaliśmy.
    private func scheduleDeferredFullRead(for kitNumber: Int?) {
        let delay = deferredFullReadDelaySeconds
        deferredFullReadTask?.cancel()
        deferredFullReadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled else { return }

            // Kit mógł się w międzyczasie znowu zmienić — wtedy pilnuje go
            // już nowsze zadanie.
            if let kitNumber, self.currentKitNumber != kitNumber { return }
            guard self.automaticallyReadChangedKit else { return }
            guard !self.isOperationInProgress else {
                // Bez ponowienia dane zostałyby niekompletne na zawsze:
                // `kitCommon` jest puste, więc nic już by tego nie dociągnęło.
                // Czekanie jest ograniczone, bo każda operacja ma swój
                // watchdog.
                self.appendLog("AUTO: full read postponed — another operation is running")
                self.scheduleDeferredFullRead(for: kitNumber)
                return
            }
            // Komplet danych już jest — szybki odczyt go nie kasuje, ale
            // i nie uzupełnia, więc sprawdzamy po blokach szczegółowych.
            // `midiNotes` idzie jako ostatnie, więc puste oznacza odczyt
            // urwany w połowie.
            guard self.needsKitReconcile
                    || self.kitCommon == nil
                    || self.midiNotes.isEmpty
            else { return }

            self.needsKitReconcile = false
            self.appendLog("AUTO: kit selection settled — full read")
            self.readCurrentKit()
        }
    }

    private func decodeIdentityReply(_ bytes: [UInt8]) {
        guard
            bytes.count >= 11,
            bytes[0] == 0xF0,
            bytes[1] == 0x7E,
            bytes[3] == 0x06,
            bytes[4] == 0x02,
            bytes.last == 0xF7
        else {
            return
        }

        let manufacturer = bytes[5] == 0x41 ? "Roland" : hex([bytes[5]])
        // Bajty rodziny i modelu lecą do logu, bo nie mamy jeszcze
        // potwierdzonych kodów TD-17 — pierwszy uruchomiony moduł nam je poda.
        let identity = hex(Array(bytes[6...9]))
        appendLog(
            "Identity Reply — manufacturer: \(manufacturer), "
                + "Device ID: \(bytes[2]), family/model: \(identity)"
        )
        status = bytes[5] == 0x41 ? "Roland replied" : "Identity Reply received"

        // Nazwa portu nic nie mówi, gdy moduł siedzi za zwykłym interfejsem
        // MIDI po DIN-ach. Odpowiedź Rolanda mówi wprost, że po drugiej
        // stronie jest jego sprzęt — i to wystarczy, żeby spróbować odczytu.
        if bytes[5] == 0x41 { rolandIdentityDetected = true }
    }

    private func decodeDT1(_ bytes: [UInt8]) {
        guard
            bytes.count >= 15,
            bytes[0] == 0xF0,
            bytes[1] == 0x41,
            Array(bytes[3...7]) == profile.modelID + [0x12],
            bytes.last == 0xF7
        else {
            return
        }

        let address = Array(bytes[8...11])
        let data = Array(bytes[12..<(bytes.count - 2)])
        let receivedChecksum = bytes[bytes.count - 2]

        guard rolandChecksum(address + data) == receivedChecksum else {
            appendLog("DT1: invalid checksum")
            return
        }

        // Bajt 2 to numer urządzenia. Program wysyła zawsze 0x10, ale w module
        // da się go zmienić — zamiast więc wymagać konkretnej wartości,
        // zapamiętujemy pierwszą, jaką zobaczyliśmy, i od tej pory trzymamy
        // się jej. Dzięki temu drugi Roland na tym samym porcie albo echo
        // z cudzego modułu przez MIDI Soft Thru nie jest już brany za nasz.
        //
        // **Zapamiętujemy dopiero po sprawdzeniu sumy kontrolnej.** Wcześniej
        // zapamiętanie stało wyżej i wystarczyła jedna ramka przekłamana po
        // drodze, żeby program na stałe zapisał sobie cudzy numer i od tej
        // chwili po cichu odrzucał wszystko z prawdziwego modułu — a jedynym
        // wyjściem było wypięcie kabla.
        if let known = moduleDeviceID {
            guard bytes[2] == known else {
                appendLog(
                    "DT1 ignored — device \(hex([bytes[2]])) is not the module "
                        + "we are talking to (\(hex([known])))"
                )
                return
            }
        } else {
            moduleDeviceID = bytes[2]
        }

        if readPhase == .triggerCommon,
           address == [0x02, 0x00, 0x00, 0x20],
           data.count >= 13 {
            triggerCommon = TD17TriggerCommonInfo(
                crossStickAdjust: Int(data[2]),
                crosstalk: data[3...12].map(Int.init),
                rawHead: Array(data[0...1])
            )
            appendLog(
                "TRIGGERS: common — Xstick Adj \(Int(data[2])), "
                    + "crosstalk \(data[3...12].map { String($0) }.joined(separator: " "))"
            )
            readPhase = .triggerInput(1)
            requestTriggerInput(1)
            return
        }

        if case let .triggerInput(input) = readPhase,
           address == addBase128(
               [0x02, 0x00, 0x00, 0x00],
               offset: encodeBase128(input * 0x80)
           ),
           data.count >= 10 {
            // Czułość i retrig cancel moduł trzyma od zera — sprawdzone
            // przez zmianę czułości werbla z 6 na 8, po której bajt poszedł
            // z 5 na 7.
            let info = TD17TriggerInfo(
                input: input,
                padTypeCode: Int(data[0]),
                sensitivity: Int(data[1]) + 1,
                rimGainTenths: Int(data[2]),
                threshold: Int(data[3]),
                retrigCancel: Int(data[4]) + 1,
                extNoiseCancel: Int(data[5]),
                headRimAdjust: Int(data[6]),
                scanTimeTenths: Int(data[7]),
                maskTimeMs: Int(data[8]),
                curve: Int(data[9]),
                crosstalkCancel: triggerCommon.flatMap {
                    $0.crosstalk.indices.contains(input - 1)
                        ? $0.crosstalk[input - 1]
                        : nil
                }
            )
            triggers.append(info)
            appendLog(
                "TRIGGERS \(info.name): \(info.padTypeName), sens \(info.sensitivity), "
                    + "thr \(info.threshold), curve \(info.curveName)"
            )

            // Wejścia liczone od 1, więc granicą jest sama liczba wejść:
            // przy dziesięciu czytamy 1…10 i kończymy na dziesiątym.
            if input < profile.triggerInputCount {
                readPhase = .triggerInput(input + 1)
                requestTriggerInput(input + 1)
            } else {
                readPhase = .idle
                isReadingTriggers = false
                status = "Trigger settings read"
                appendLog("TRIGGERS: all \(profile.triggerInputCount) inputs read")
            }
            return
        }

        // Zrzut SETUP zjada wszystko, co przyjdzie — nie znamy jeszcze
        // znaczenia tych bloków, więc lecą do logu w surowej postaci.
        if setupDumpActive {
            setupDumpReplied = true
            appendLog("SETUP \(hex(address)): \(hex(data))")
            return
        }

        if case let .kitSelectVerify(expected) = readPhase,
           address == [0x00, 0x00, 0x00, 0x00],
           let kitIndex = data.first {
            let actual = Int(kitIndex)
            // Ta sama granica co przy zwykłym odczycie numeru kitu: wartość
            // spoza 0…99 przepisana do `currentKitNumber` rozjeżdża adresy
            // wszystkich kolejnych zapisów.
            guard (0..<profile.kitCount).contains(actual) else {
                lastWriteConfirmed = false
                appendLog("The module reported an invalid kit number: \(actual)")
                status = "The module reported an invalid kit number"
                readPhase = .idle
                isWriting = false
                return
            }
            if actual == expected {
                lastWriteConfirmed = true
                appendLog("CONFIRMED switch to kit \(actual + 1)")
                status = "Kit \(actual + 1) selected"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH on kit switch: expected "
                        + "\(expected + 1), module reports \(actual + 1)"
                )
                status = "The module did not accept the kit change"
            }
            currentKitNumber = actual + 1
            // Nazwa i cała reszta opisują jeszcze poprzedni kit — lepiej pusto
            // niż numer nowego kitu nad danymi starego. Wyczyszczenie
            // `kitCommon` jest też warunkiem, po którym odroczone zadanie
            // pozna, że komplet danych trzeba dociągnąć od nowa.
            currentKitName = nil
            kitCommon = nil
            midiNotes = []
            readPhase = .complete
            isWriting = false

            // Odczyt dopiero po opuszczeniu `isWriting`, bo `readCurrentKit`
            // odmawia startu w trakcie operacji.
            //
            // Szybki, a nie pełny: przy przewijaniu kitów strzałkami pełny
            // odczyt (ok. 3 s) blokowałby kolejne kliknięcie. Resztę dociąga
            // odroczone zadanie, gdy wybór się ustali — tak samo jak przy
            // zmianie kitu pokrętłem na module.
            let kitNumber = actual + 1
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !self.isOperationInProgress else {
                    self.appendLog("AUTO: read after kit change postponed")
                    self.scheduleDeferredFullRead(for: kitNumber)
                    return
                }
                self.appendLog("AUTO: read after an in-app kit change")
                self.nextReadShouldBeQuick = true
                self.readCurrentKit()
                self.scheduleDeferredFullRead(for: kitNumber)
            }
            return
        }

        if readPhase == .currentKit,
           address == [0x00, 0x00, 0x00, 0x00],
           let kitIndex = data.first {
            // TD-17 ma 100 kitów. Wszystko poza tym zakresem znaczy, że po
            // drugiej stronie kabla nie jest to, czego się spodziewamy —
            // a z tego numeru liczy się potem adres **każdego** zapisu.
            guard (0..<profile.kitCount).contains(Int(kitIndex)) else {
                appendLog(
                    "The module reported an invalid kit number: \(Int(kitIndex))"
                )
                status = "The module reported an invalid kit number"
                readPhase = .idle
                isReadingKit = false
                return
            }
            currentKitNumber = Int(kitIndex) + 1
            appendLog("Current kit number: \(Int(kitIndex) + 1)")
            readPhase = .kitName
            requestKitName(kitIndex: Int(kitIndex))
            return
        }

        if case let .kitListName(index) = readPhase,
           address == kitAddress(kitIndex: index) {
            let name = String(bytes: data, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            kitNames[index + 1] = name?.isEmpty == false ? name! : "(unnamed)"
            kitListProgress = index + 1

            let next = index + 1
            if next < 100 {
                readPhase = .kitListName(next)
                requestKitName(kitIndex: next)
            } else {
                readPhase = .idle
                isScanningKitList = false
                status = "Kit list ready"
                appendLog("Read the names of 100 kits")
            }
            return
        }

        if readPhase == .kitName,
           let currentKitNumber,
           address == kitAddress(kitIndex: currentKitNumber - 1) {
            let name = String(bytes: data, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            currentKitName = name?.isEmpty == false ? name : "(unnamed)"
            // Lista kitów uczy się przy okazji — bez tego pokazywałaby starą
            // nazwę do końca sesji.
            kitNames[currentKitNumber] = currentKitName
            appendLog("Kit name: \(currentKitName ?? "(nieznana)")")
            readPhase = .zone(0)
            requestZone(index: 0, kitIndex: currentKitNumber - 1)
            return
        }

        if let currentKitNumber,
           case let .zone(index) = readPhase,
           zoneNames.indices.contains(index),
           address == zoneAddress(index: index, kitIndex: currentKitNumber - 1),
           let info = decodeInstrument(data) {
            zones.append(
                TD17ZoneInfo(index: index, name: zoneNames[index], instrument: info)
            )
            mainLevelDrafts[index] = Double(info.levelTenthsDB) / 10.0
            mainInstrumentDrafts[index] = info.instrumentID


            appendLog("\(zoneNames[index]): \(info.description)")

            let nextIndex = index + 1
            if zoneNames.indices.contains(nextIndex) {
                readPhase = .zone(nextIndex)
                requestZone(index: nextIndex, kitIndex: currentKitNumber - 1)
            } else if isQuickRead {
                readPhase = .complete
                isReadingKit = false
                isQuickRead = false
                snapshotDifferences = nil
                snapshotDifferencePaths = []
                status = "Quickly read the name, instruments and levels"
                appendLog(
                    "AUTO: quick read finished — details available "
                        + "after a full read"
                )
            } else {
                readPhase = .layerCommon(0)
                requestLayerCommon(zoneIndex: 0, kitIndex: currentKitNumber - 1)
            }
            return
        }

        if let currentKitNumber,
           case let .instrumentVerify(zoneIndex, expectedID, isSub) = readPhase {
            let expectedAddress = isSub
                ? layerInstrumentAddress(
                    zoneIndex: zoneIndex,
                    kitIndex: currentKitNumber - 1
                )
                : zoneAddress(index: zoneIndex, kitIndex: currentKitNumber - 1)

            if address == expectedAddress, let instrument = decodeInstrument(data) {
                let layerName = isSub ? "SUB" : "MAIN"
                if isSub {
                    subInstrumentDrafts[zoneIndex] = instrument.instrumentID
                    if let arrayIndex = layers.firstIndex(where: {
                        $0.zoneIndex == zoneIndex
                    }) {
                        let old = layers[arrayIndex]
                        layers[arrayIndex] = TD17LayerInfo(
                            zoneIndex: old.zoneIndex,
                            zoneName: old.zoneName,
                            enabled: old.enabled,
                            layerType: old.layerType,
                            fadePoint: old.fadePoint,
                            instrument: instrument
                        )
                    }
                } else {
                    mainInstrumentDrafts[zoneIndex] = instrument.instrumentID
                    if let arrayIndex = zones.firstIndex(where: {
                        $0.index == zoneIndex
                    }) {
                        zones[arrayIndex] = TD17ZoneInfo(
                            index: zoneIndex,
                            name: zoneNames[zoneIndex],
                            instrument: instrument
                        )
                    }
                }

                if instrument.instrumentID == expectedID {
                    lastWriteConfirmed = true
                    appendLog(
                        "CONFIRMED \(layerName) \(zoneNames[zoneIndex]) Instrument: "
                            + "\(instrument.displayName) (#\(instrument.instrumentID))"
                    )
                    status = "\(layerName) \(zoneNames[zoneIndex]) instrument written"
                } else {
                    lastWriteConfirmed = false
                    appendLog(
                        "MISMATCH \(layerName) \(zoneNames[zoneIndex]) Instrument: "
                            + "expected #\(expectedID), read #\(instrument.instrumentID)"
                    )
                    status = "The module returned a different instrument"
                }
                readPhase = .complete
                isWriting = false
                return
            }
        }

        if let currentKitNumber,
           case let .zoneLevelVerify(zoneIndex, expected, isSub) = readPhase {
            let expectedAddress = isSub
                ? layerInstrumentAddress(
                    zoneIndex: zoneIndex,
                    kitIndex: currentKitNumber - 1
                )
                : zoneAddress(index: zoneIndex, kitIndex: currentKitNumber - 1)

            if address == expectedAddress, let instrument = decodeInstrument(data) {
                let layerName = isSub ? "SUB" : "MAIN"
                if isSub {
                    subLevelDrafts[zoneIndex] = Double(instrument.levelTenthsDB) / 10.0
                    if let arrayIndex = layers.firstIndex(where: {
                        $0.zoneIndex == zoneIndex
                    }) {
                        let old = layers[arrayIndex]
                        layers[arrayIndex] = TD17LayerInfo(
                            zoneIndex: old.zoneIndex,
                            zoneName: old.zoneName,
                            enabled: old.enabled,
                            layerType: old.layerType,
                            fadePoint: old.fadePoint,
                            instrument: instrument
                        )
                    }
                } else {
                    mainLevelDrafts[zoneIndex] = Double(instrument.levelTenthsDB) / 10.0
                    if let arrayIndex = zones.firstIndex(where: {
                        $0.index == zoneIndex
                    }) {
                        zones[arrayIndex] = TD17ZoneInfo(
                            index: zoneIndex,
                            name: zoneNames[zoneIndex],
                            instrument: instrument
                        )
                    }
                }

                if instrument.levelTenthsDB == expected {
                    lastWriteConfirmed = true
                    appendLog(
                        "CONFIRMED \(layerName) \(zoneNames[zoneIndex]) Level: "
                            + levelText(expected)
                    )
                    status = "\(layerName) \(zoneNames[zoneIndex]) written"
                } else {
                    lastWriteConfirmed = false
                    appendLog(
                        "MISMATCH \(layerName) \(zoneNames[zoneIndex]) Level: "
                            + "expected \(levelText(expected)), "
                            + "read \(levelText(instrument.levelTenthsDB))"
                    )
                    status = "The module returned a different level"
                }
                readPhase = .complete
                isWriting = false
                return
            }
        }

        if let currentKitNumber,
           case let .masterCompVerify(parameterIndex, expected) = readPhase,
           address == masterCompAddress(kitIndex: currentKitNumber - 1),
           let info = decodeMasterComp(data) {
            masterComp = info
            updateMasterCompDrafts(info)
            let values = [
                info.enabled ? 1 : 0,
                masterCompTypeDraft,
                info.splitFrequency,
                info.lowGain,
                info.highGain,
                info.lowThreshold,
                info.highThreshold,
                info.lowRatio,
                info.highRatio,
                info.lowKnee,
                info.highKnee,
                info.lowAttack,
                info.highAttack,
                info.lowRelease,
                info.highRelease,
                info.balance
            ]
            let actual = values[parameterIndex]
            let name = parameterIndex == 0
                ? "ON/OFF"
                : (parameterIndex == 1
                    ? "Type"
                    : TD17MasterCompCatalog.parameterNames[parameterIndex - 2])
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED Master Comp \(name): "
                        + masterCompValueText(parameterIndex, actual)
                )
                status = "Master Comp \(name) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH Master Comp \(name): expected "
                        + "\(masterCompValueText(parameterIndex, expected)), "
                        + "read \(masterCompValueText(parameterIndex, actual))"
                )
                status = "The module returned a different Master Comp parameter"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .mfxVerify(parameterIndex, expected) = readPhase,
           address == mfxAddress(kitIndex: currentKitNumber - 1),
           let info = decodeMFX(data) {
            mfx = info
            updateMFXDrafts(info)
            let actual: Int
            let name: String
            if parameterIndex == 0 {
                actual = info.enabled ? 1 : 0
                name = "ON/OFF"
            } else if parameterIndex == 1 {
                actual = mfxTypeDraft
                name = "Type"
            } else if parameterIndex == 2 {
                actual = info.level
                name = "Level"
            } else {
                let rawIndex = parameterIndex - 3
                actual = info.parameters[rawIndex]
                name = String(format: "P%02d", rawIndex + 1)
            }

            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED MFX \(name): "
                        + mfxValueText(parameterIndex, actual)
                )
                status = "MFX \(name) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH MFX \(name): expected "
                        + "\(mfxValueText(parameterIndex, expected)), read "
                        + "\(mfxValueText(parameterIndex, actual))"
                )
                status = "The module returned a different MFX parameter"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .reverbVerify(parameterIndex, expected) = readPhase,
           address == reverbAddress(kitIndex: currentKitNumber - 1),
           let info = decodeReverb(data) {
            reverb = info
            updateReverbDrafts(info)
            let values = [
                info.enabled ? 1 : 0,
                reverbTypeDraft,
                info.preDelay,
                info.time,
                info.density,
                info.diffusion,
                info.lowDamp,
                info.highDamp,
                info.spread,
                info.tone,
                info.level
            ]
            let names = ["ON/OFF", "Type"]
                + TD17ReverbCatalog.parameterNames
                + ["Level"]
            let actual = values[parameterIndex]
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED Reverb \(names[parameterIndex]): "
                        + reverbValueText(parameterIndex, actual)
                )
                status = "Reverb \(names[parameterIndex]) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH Reverb \(names[parameterIndex]): expected "
                        + "\(reverbValueText(parameterIndex, expected)), read "
                        + "\(reverbValueText(parameterIndex, actual))"
                )
                status = "The module returned a different Reverb parameter"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .ambienceParameterVerify(
               parameterIndex,
               expected
           ) = readPhase,
           address == ambienceAddress(kitIndex: currentKitNumber - 1),
           let info = decodeAmbience(data) {
            ambience = info
            updateAmbienceDrafts(info)
            let actualValues = [
                ambienceRoomTypeDraft,
                ambienceRoomSizeDraft,
                ambienceRoomShapeDraft,
                ambienceWallTypeDraft,
                ambienceMicPositionDraft
            ]
            let names = [
                "Room Type", "Room Size", "Room Shape", "Wall Type", "Mic Position"
            ]
            let actual = actualValues[parameterIndex]
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED Ambience \(names[parameterIndex]): "
                        + ambienceParameterText(parameterIndex, actual)
                )
                status = "Ambience \(names[parameterIndex]) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH Ambience \(names[parameterIndex])"
                )
                status = "The module returned a different Ambience parameter"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .ambienceEnabledVerify(expected) = readPhase,
           address == ambienceAddress(kitIndex: currentKitNumber - 1),
           let info = decodeAmbience(data) {
            ambience = info
            updateAmbienceDrafts(info)
            if info.enabled == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED Ambience: \(info.enabled ? "ON" : "OFF")"
                )
                status = "Ambience ON/OFF written"
            } else {
                lastWriteConfirmed = false
                appendLog("MISMATCH Ambience ON/OFF")
                status = "The module returned a different Ambience state"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .ambienceLevelVerify(expected) = readPhase,
           address == ambienceAddress(kitIndex: currentKitNumber - 1),
           let info = decodeAmbience(data) {
            ambience = info
            updateAmbienceDrafts(info)
            if info.level == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED Ambience Level: \(levelText(info.level))"
                )
                status = "Ambience Level written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH Ambience Level: expected "
                        + "\(levelText(expected)), read \(levelText(info.level))"
                )
                status = "The module returned a different Ambience level"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .eqShapeVerify(
               zoneIndex,
               parameterIndex,
               expected
           ) = readPhase,
           address == layerCommonAddress(
               zoneIndex: zoneIndex,
               kitIndex: currentKitNumber - 1
           ),
           let common = decodeLayerCommon(data, zoneIndex: zoneIndex) {
            updateMixDrafts(common.mixInfo)
            if let index = mixInfos.firstIndex(where: {
                $0.zoneIndex == zoneIndex
            }) {
                mixInfos[index] = common.mixInfo
            }

            let actualValues = [
                TD17EQCatalog.lowFrequencies.firstIndex(
                    of: common.mixInfo.lowFrequency
                ) ?? -1,
                TD17EQCatalog.midFrequencies.firstIndex(
                    of: common.mixInfo.midFrequency
                ) ?? -1,
                TD17EQCatalog.qValues.firstIndex(
                    of: common.mixInfo.midQ
                ) ?? -1,
                TD17EQCatalog.highFrequencies.firstIndex(
                    of: common.mixInfo.highFrequency
                ) ?? -1
            ]
            let names = ["LOW Freq", "MID Freq", "MID Q", "HIGH Freq"]
            let actual = actualValues[parameterIndex]
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED \(zoneNames[zoneIndex]) Pad EQ "
                        + "\(names[parameterIndex]): "
                        + "\(eqShapeLists[parameterIndex][actual])"
                )
                status = "Pad EQ \(names[parameterIndex]) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH \(zoneNames[zoneIndex]) Pad EQ "
                        + "\(names[parameterIndex])"
                )
                status = "The module returned a different Pad EQ parameter"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .eqGainVerify(
               zoneIndex,
               bandIndex,
               expected
           ) = readPhase,
           address == layerCommonAddress(
               zoneIndex: zoneIndex,
               kitIndex: currentKitNumber - 1
           ),
           let common = decodeLayerCommon(data, zoneIndex: zoneIndex) {
            updateMixDrafts(common.mixInfo)
            if let index = mixInfos.firstIndex(where: {
                $0.zoneIndex == zoneIndex
            }) {
                mixInfos[index] = common.mixInfo
            }

            let values = [
                common.mixInfo.lowGain,
                common.mixInfo.midGain,
                common.mixInfo.highGain
            ]
            let names = ["LOW", "MID", "HIGH"]
            let actual = values[bandIndex]
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED \(zoneNames[zoneIndex]) Pad EQ "
                        + "\(names[bandIndex]) Gain: \(signedDBText(actual))"
                )
                status = "Pad EQ \(names[bandIndex]) Gain written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH \(zoneNames[zoneIndex]) Pad EQ "
                        + "\(names[bandIndex]) Gain: expected "
                        + "\(signedDBText(expected)), read "
                        + "\(signedDBText(actual))"
                )
                status = "The module returned a different Pad EQ gain"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .eqEnabledVerify(
               zoneIndex,
               expected
           ) = readPhase,
           address == layerCommonAddress(
               zoneIndex: zoneIndex,
               kitIndex: currentKitNumber - 1
           ),
           let common = decodeLayerCommon(data, zoneIndex: zoneIndex) {
            updateMixDrafts(common.mixInfo)
            if let index = mixInfos.firstIndex(where: {
                $0.zoneIndex == zoneIndex
            }) {
                mixInfos[index] = common.mixInfo
            }

            if common.mixInfo.eqEnabled == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED \(zoneNames[zoneIndex]) Pad EQ: "
                        + "\(expected ? "ON" : "OFF")"
                )
                status = "Pad EQ \(zoneNames[zoneIndex]) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH \(zoneNames[zoneIndex]) Pad EQ: expected "
                        + "\(expected ? "ON" : "OFF"), read "
                        + "\(common.mixInfo.eqEnabled ? "ON" : "OFF")"
                )
                status = "The module returned a different Pad EQ state"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .mixSendVerify(
               zoneIndex,
               sendIndex,
               expected
           ) = readPhase,
           address == layerCommonAddress(
               zoneIndex: zoneIndex,
               kitIndex: currentKitNumber - 1
           ),
           let common = decodeLayerCommon(data, zoneIndex: zoneIndex) {
            updateMixDrafts(common.mixInfo)
            if let index = mixInfos.firstIndex(where: {
                $0.zoneIndex == zoneIndex
            }) {
                mixInfos[index] = common.mixInfo
            }

            let values = [
                common.mixInfo.ambienceSend,
                common.mixInfo.mfxSend,
                common.mixInfo.reverbSend
            ]
            let names = ["Ambience", "MFX", "Reverb"]
            let actual = values[sendIndex]
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED \(zoneNames[zoneIndex]) "
                        + "\(names[sendIndex]) Send: \(levelText(actual))"
                )
                status = "\(names[sendIndex]) Send written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH \(zoneNames[zoneIndex]) "
                        + "\(names[sendIndex]) Send: expected "
                        + "\(levelText(expected)), read \(levelText(actual))"
                )
                status = "The module returned a different send value"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .panVerify(zoneIndex, expectedPan) = readPhase,
           address == layerCommonAddress(
               zoneIndex: zoneIndex,
               kitIndex: currentKitNumber - 1
           ),
           let common = decodeLayerCommon(data, zoneIndex: zoneIndex) {
            updateMixDrafts(common.mixInfo)
            if let index = mixInfos.firstIndex(where: {
                $0.zoneIndex == zoneIndex
            }) {
                mixInfos[index] = common.mixInfo
            }

            if common.mixInfo.pan == expectedPan {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED \(zoneNames[zoneIndex]) Pan: "
                        + panText(expectedPan)
                )
                status = "Pan \(zoneNames[zoneIndex]) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH \(zoneNames[zoneIndex]) Pan: expected "
                        + "\(panText(expectedPan)), read "
                        + "\(panText(common.mixInfo.pan))"
                )
                status = "The module returned a different pan"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .layerSettingsVerify(
               zoneIndex,
               expectedEnabled,
               expectedType,
               expectedFade
           ) = readPhase,
           address == layerCommonAddress(
               zoneIndex: zoneIndex,
               kitIndex: currentKitNumber - 1
           ),
           let common = decodeLayerCommon(data, zoneIndex: zoneIndex) {
            let typeNames = TD17LayerCatalog.types
            let actualType = typeNames.firstIndex(of: common.type) ?? -1
            subEnabledDrafts[zoneIndex] = common.enabled
            subLayerTypeDrafts[zoneIndex] = actualType
            subFadePointDrafts[zoneIndex] = common.fadePoint

            if let arrayIndex = layers.firstIndex(where: {
                $0.zoneIndex == zoneIndex
            }) {
                let old = layers[arrayIndex]
                layers[arrayIndex] = TD17LayerInfo(
                    zoneIndex: old.zoneIndex,
                    zoneName: old.zoneName,
                    enabled: common.enabled,
                    layerType: common.type,
                    fadePoint: common.fadePoint,
                    instrument: old.instrument
                )
            }

            if common.enabled == expectedEnabled,
               actualType == expectedType,
               common.fadePoint == expectedFade {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED SUB \(zoneNames[zoneIndex]) Layer: "
                        + "\(common.enabled ? "ON" : "OFF"), "
                        + "\(common.type), Fade \(common.fadePoint)"
                )
                status = "Layering SUB \(zoneNames[zoneIndex]) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH SUB \(zoneNames[zoneIndex]) Layer: "
                        + "read \(common.enabled ? "ON" : "OFF"), "
                        + "\(common.type), Fade \(common.fadePoint)"
                )
                status = "The module returned different layer settings"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .layerCommon(zoneIndex) = readPhase,
           address == layerCommonAddress(
                zoneIndex: zoneIndex,
                kitIndex: currentKitNumber - 1
           ),
           let common = decodeLayerCommon(data) {
            pendingLayerCommon = common
            subEnabledDrafts[zoneIndex] = common.enabled
            subLayerTypeDrafts[zoneIndex] =
                TD17LayerCatalog.types.firstIndex(of: common.type) ?? 0
            subFadePointDrafts[zoneIndex] = common.fadePoint
            updateMixDrafts(common.mixInfo)
            mixInfos.append(common.mixInfo)
            appendLog("MIX \(common.mixInfo.description)")
            readPhase = .layerInstrument(zoneIndex)
            requestLayerInstrument(
                zoneIndex: zoneIndex,
                kitIndex: currentKitNumber - 1
            )
            return
        }

        if let currentKitNumber,
           case let .layerInstrument(zoneIndex) = readPhase,
           address == layerInstrumentAddress(
                zoneIndex: zoneIndex,
                kitIndex: currentKitNumber - 1
           ),
           let instrument = decodeInstrument(data),
           let common = pendingLayerCommon {
            let info = TD17LayerInfo(
                zoneIndex: zoneIndex,
                zoneName: zoneNames[zoneIndex],
                enabled: common.enabled,
                layerType: common.type,
                fadePoint: common.fadePoint,
                instrument: instrument
            )
            layers.append(info)
            subLevelDrafts[zoneIndex] = Double(instrument.levelTenthsDB) / 10.0
            subInstrumentDrafts[zoneIndex] = instrument.instrumentID
            appendLog("SUB \(info.description)")
            pendingLayerCommon = nil

            let nextIndex = zoneIndex + 1
            if zoneNames.indices.contains(nextIndex) {
                readPhase = .layerCommon(nextIndex)
                requestLayerCommon(
                    zoneIndex: nextIndex,
                    kitIndex: currentKitNumber - 1
                )
            } else {
                readPhase = .vEdit(0)
                requestVEdit(zoneIndex: 0, kitIndex: currentKitNumber - 1)
            }
            return
        }

        if let currentKitNumber,
           case let .vEditParameterVerify(
               zoneIndex,
               parameter,
               expected,
               isSub
           ) = readPhase {
            let expectedAddress = isSub
                ? subVEditAddress(
                    zoneIndex: zoneIndex,
                    kitIndex: currentKitNumber - 1
                )
                : vEditAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
            let instrument = isSub
                ? layers.first(where: { $0.zoneIndex == zoneIndex })?.instrument
                : zones.first(where: { $0.index == zoneIndex })?.instrument

            if address == expectedAddress,
               let instrument,
               let edit = decodeVEdit(
                   data,
                   zoneIndex: zoneIndex,
                   instrument: instrument,
                   zonePrefix: isSub ? "SUB " : ""
               ) {
                let actual = parameter == 2
                    ? edit.secondaryValue
                    : edit.tertiaryValue
                if isSub {
                    subVEditSecondDrafts[zoneIndex] = edit.secondaryValue
                    subVEditThirdDrafts[zoneIndex] = edit.tertiaryValue
                    if let index = subVEdits.firstIndex(where: {
                        $0.zoneIndex == zoneIndex
                    }) {
                        subVEdits[index] = edit
                    }
                } else {
                    mainVEditSecondDrafts[zoneIndex] = edit.secondaryValue
                    mainVEditThirdDrafts[zoneIndex] = edit.tertiaryValue
                    if let index = vEdits.firstIndex(where: {
                        $0.zoneIndex == zoneIndex
                    }) {
                        vEdits[index] = edit
                    }
                }

                let layerName = isSub ? "SUB" : "MAIN"
                if actual == expected {
                    lastWriteConfirmed = true
                    appendLog(
                        "CONFIRMED V-EDIT \(layerName) "
                            + "\(zoneNames[zoneIndex]) Param \(parameter): \(actual)"
                    )
                    status = "V-Edit parameter written"
                } else {
                    lastWriteConfirmed = false
                    appendLog(
                        "MISMATCH V-EDIT \(layerName) "
                            + "\(zoneNames[zoneIndex]) Param \(parameter): "
                            + "expected \(expected), read \(actual)"
                    )
                    status = "The module returned a different V-Edit value"
                }
                readPhase = .complete
                isWriting = false
                return
            }
        }

        if let currentKitNumber,
           case let .vEditTuningVerify(zoneIndex, expected, isSub) = readPhase {
            let expectedAddress = isSub
                ? subVEditAddress(
                    zoneIndex: zoneIndex,
                    kitIndex: currentKitNumber - 1
                )
                : vEditAddress(zoneIndex: zoneIndex, kitIndex: currentKitNumber - 1)
            let instrument = isSub
                ? layers.first(where: { $0.zoneIndex == zoneIndex })?.instrument
                : zones.first(where: { $0.index == zoneIndex })?.instrument

            if address == expectedAddress,
               let instrument,
               let edit = decodeVEdit(
                   data,
                   zoneIndex: zoneIndex,
                   instrument: instrument,
                   zonePrefix: isSub ? "SUB " : ""
               ) {
                if isSub {
                    subTuningDrafts[zoneIndex] = edit.primaryValue
                    if let index = subVEdits.firstIndex(where: {
                        $0.zoneIndex == zoneIndex
                    }) {
                        subVEdits[index] = edit
                    }
                } else {
                    mainTuningDrafts[zoneIndex] = edit.primaryValue
                    if let index = vEdits.firstIndex(where: {
                        $0.zoneIndex == zoneIndex
                    }) {
                        vEdits[index] = edit
                    }
                }

                let layerName = isSub ? "SUB" : "MAIN"
                let parameterName = edit.supportsTuning
                    ? "Tuning"
                    : (edit.isCymbal ? "Size" : "Pitch")
                if edit.primaryValue == expected {
                    lastWriteConfirmed = true
                    appendLog(
                        "CONFIRMED V-EDIT \(layerName) "
                            + "\(zoneNames[zoneIndex]) \(parameterName): "
                            + "\(signedText(expected))"
                    )
                    status = "\(parameterName) \(layerName) \(zoneNames[zoneIndex]) written"
                } else {
                    lastWriteConfirmed = false
                    appendLog(
                        "MISMATCH V-EDIT \(layerName) "
                            + "\(zoneNames[zoneIndex]) \(parameterName): "
                            + "expected \(signedText(expected)), "
                            + "read \(signedText(edit.primaryValue))"
                    )
                    status = "The module returned a different tuning"
                }
                readPhase = .complete
                isWriting = false
                return
            }
        }

        if let currentKitNumber,
           case let .vEdit(zoneIndex) = readPhase,
           zones.indices.contains(zoneIndex),
           address == vEditAddress(
                zoneIndex: zoneIndex,
                kitIndex: currentKitNumber - 1
           ),
           let edit = decodeVEdit(
                data,
                zoneIndex: zoneIndex,
                instrument: zones[zoneIndex].instrument
            ) {
            vEdits.append(edit)
            mainTuningDrafts[zoneIndex] = edit.primaryValue
            mainVEditSecondDrafts[zoneIndex] = edit.secondaryValue
            mainVEditThirdDrafts[zoneIndex] = edit.tertiaryValue
            appendLog("V-EDIT \(edit.description)")

            let nextIndex = zoneIndex + 1
            if zones.indices.contains(nextIndex) {
                readPhase = .vEdit(nextIndex)
                requestVEdit(
                    zoneIndex: nextIndex,
                    kitIndex: currentKitNumber - 1
                )
            } else {
                if let firstActive = activeLayerIndices.first {
                    readPhase = .subVEdit(firstActive)
                    requestSubVEdit(
                        zoneIndex: firstActive,
                        kitIndex: currentKitNumber - 1
                    )
                } else {
                    readPhase = .ambience
                    requestAmbience(kitIndex: currentKitNumber - 1)
                }
            }
            return
        }

        if let currentKitNumber,
           case let .subVEdit(zoneIndex) = readPhase,
           let layer = layers.first(where: {
               $0.zoneIndex == zoneIndex && $0.enabled
           }),
           address == subVEditAddress(
                zoneIndex: zoneIndex,
                kitIndex: currentKitNumber - 1
           ),
           let edit = decodeVEdit(
                data,
                zoneIndex: zoneIndex,
                instrument: layer.instrument,
                zonePrefix: "SUB "
            ) {
            subVEdits.append(edit)
            subTuningDrafts[zoneIndex] = edit.primaryValue
            subVEditSecondDrafts[zoneIndex] = edit.secondaryValue
            subVEditThirdDrafts[zoneIndex] = edit.tertiaryValue
            appendLog("V-EDIT \(edit.description)")

            if let nextIndex = activeLayerIndices.first(where: { $0 > zoneIndex }) {
                readPhase = .subVEdit(nextIndex)
                requestSubVEdit(
                    zoneIndex: nextIndex,
                    kitIndex: currentKitNumber - 1
                )
            } else {
                readPhase = .ambience
                requestAmbience(kitIndex: currentKitNumber - 1)
            }
            return
        }

        if let currentKitNumber,
           readPhase == .ambience,
           address == ambienceAddress(kitIndex: currentKitNumber - 1),
           let info = decodeAmbience(data) {
            ambience = info
            updateAmbienceDrafts(info)
            appendLog("AMBIENCE: \(info.description)")
            readPhase = .reverb
            requestReverb(kitIndex: currentKitNumber - 1)
            return
        }

        if let currentKitNumber,
           readPhase == .reverb,
           address == reverbAddress(kitIndex: currentKitNumber - 1),
           let info = decodeReverb(data) {
            reverb = info
            updateReverbDrafts(info)
            appendLog("REVERB: \(info.description)")
            readPhase = .mfx
            requestMFX(kitIndex: currentKitNumber - 1)
            return
        }

        if let currentKitNumber,
           readPhase == .mfx,
           address == mfxAddress(kitIndex: currentKitNumber - 1),
           let info = decodeMFX(data) {
            mfx = info
            updateMFXDrafts(info)
            appendLog("MFX: \(info.description)")
            readPhase = .masterComp
            requestMasterComp(kitIndex: currentKitNumber - 1)
            return
        }

        if let currentKitNumber,
           readPhase == .masterComp,
           address == masterCompAddress(kitIndex: currentKitNumber - 1),
           let info = decodeMasterComp(data) {
            masterComp = info
            updateMasterCompDrafts(info)
            appendLog("MASTER COMP: \(info.description)")
            readPhase = .kitCommon
            requestKitCommon(kitIndex: currentKitNumber - 1)
            return
        }

        if let currentKitNumber,
           readPhase == .kitCommon,
           address == kitAddress(kitIndex: currentKitNumber - 1),
           let info = decodeKitCommon(data) {
            kitCommon = info
            kitVolumeDraft = Double(info.kitVolume) / 10.0
            updateKitCommonDrafts(info)
            appendLog("KIT COMMON: \(info.description)")
            readPhase = .kitMIDI
            requestKitMIDI(kitIndex: currentKitNumber - 1)
            return
        }

        if let currentKitNumber,
           case let .kitTextVerify(fieldIndex, expected) = readPhase,
           address == kitAddress(kitIndex: currentKitNumber - 1),
           let info = decodeKitCommon(data) {
            kitCommon = info
            kitVolumeDraft = Double(info.kitVolume) / 10.0
            updateKitCommonDrafts(info)
            let names = ["Kit name", "Kit description"]
            let actual = fieldIndex == 0 ? info.name : info.subName
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED \(names[fieldIndex]): \"\(actual)\""
                )
                status = "\(names[fieldIndex]) written"
                if fieldIndex == 0 {
                    currentKitName = actual
                    kitNames[currentKitNumber] = actual
                }
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH \(names[fieldIndex]): expected "
                        + "\"\(expected)\", read \"\(actual)\""
                )
                status = "The module returned a different name"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .kitCommonParameterVerify(
               parameterIndex,
               expected
           ) = readPhase,
           address == kitAddress(kitIndex: currentKitNumber - 1),
           let info = decodeKitCommon(data) {
            kitCommon = info
            kitVolumeDraft = Double(info.kitVolume) / 10.0
            updateKitCommonDrafts(info)
            let values = [
                info.pedalHiHatVolume,
                info.crossStickVolume,
                info.crossStickEnabled ? 1 : 0,
                info.hiHatBalance
            ]
            let names = [
                "Pedal HH Volume", "XStick Volume", "XStick ON/OFF", "HH Balance"
            ]
            let actual = values[parameterIndex]
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED Kit Common \(names[parameterIndex]): "
                        + kitCommonValueText(parameterIndex, actual)
                )
                status = "\(names[parameterIndex]) written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH Kit Common \(names[parameterIndex])"
                )
                status = "The module returned a different Kit Common parameter"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .kitVolumeVerify(expected) = readPhase,
           address == kitAddress(kitIndex: currentKitNumber - 1),
           let info = decodeKitCommon(data) {
            kitCommon = info
            kitVolumeDraft = Double(info.kitVolume) / 10.0
            if info.kitVolume == expected {
                lastWriteConfirmed = true
                appendLog("CONFIRMED Kit volume: \(levelText(info.kitVolume))")
                status = "Kit volume written and confirmed"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH Kit volume: expected \(levelText(expected)), "
                        + "read \(levelText(info.kitVolume))"
                )
                status = "The module returned a different Kit volume"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           case let .midiNoteVerify(index, expected) = readPhase,
           address == kitMIDIAddress(kitIndex: currentKitNumber - 1),
           let notes = decodeKitMIDI(data),
           notes.indices.contains(index) {
            midiNotes = notes
            midiNoteDrafts = Dictionary(
                uniqueKeysWithValues: notes.map { ($0.index, $0.note) }
            )
            let actual = notes[index].note
            if actual == expected {
                lastWriteConfirmed = true
                appendLog(
                    "CONFIRMED MIDI \(notes[index].name): "
                        + "\(TD17MIDINoteCatalog.text(actual))"
                )
                status = "MIDI assignment written"
            } else {
                lastWriteConfirmed = false
                appendLog(
                    "MISMATCH MIDI \(notes[index].name): "
                        + "expected \(expected), read \(actual)"
                )
                status = "The module returned a different MIDI note"
            }
            readPhase = .complete
            isWriting = false
            return
        }

        if let currentKitNumber,
           readPhase == .kitMIDI,
           address == kitMIDIAddress(kitIndex: currentKitNumber - 1),
           let notes = decodeKitMIDI(data) {
            midiNotes = notes
            midiNoteDrafts = Dictionary(
                uniqueKeysWithValues: notes.map { ($0.index, $0.note) }
            )
            for note in notes {
                appendLog("MIDI NOTE \(note.name): \(note.noteText)")
            }
            readPhase = .complete
            isReadingKit = false
            status = "Complete kit data read"
            if importedSnapshot != nil {
                compareImportedSnapshot()
            }
            beginModuleStabilization()
        }
    }

    private func requestAmbience(kitIndex: Int) {
        sendRQ1(
            address: ambienceAddress(kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x0A]
        )
    }

    private func requestReverb(kitIndex: Int) {
        sendRQ1(
            address: reverbAddress(kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x0E]
        )
    }

    private func requestMFX(kitIndex: Int) {
        sendRQ1(
            address: mfxAddress(kitIndex: kitIndex),
            size: [0x00, 0x00, 0x01, 0x06]
        )
    }

    private func requestMasterComp(kitIndex: Int) {
        sendRQ1(
            address: masterCompAddress(kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x17]
        )
    }

    private func requestKitCommon(kitIndex: Int) {
        sendRQ1(
            address: kitAddress(kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x2B]
        )
    }

    private func requestKitMIDI(kitIndex: Int) {
        sendRQ1(
            address: kitMIDIAddress(kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x60]
        )
    }

    private func kitMIDIAddress(kitIndex: Int) -> [UInt8] {
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, 0x01, 0x00]
        )
    }

    private func makeFastSnapshotBlocks(
        snapshot: [String: Any],
        kitIndex: Int
    ) throws -> [FastSnapshotBlock] {
        func object(_ value: Any?, _ name: String) throws -> [String: Any] {
            guard let result = value as? [String: Any] else {
                throw SnapshotError.invalid("Missing section \(name)")
            }
            return result
        }
        func objects(_ value: Any?, _ name: String) throws -> [[String: Any]] {
            guard let result = value as? [[String: Any]] else {
                throw SnapshotError.invalid("Missing array \(name)")
            }
            return result
        }
        func integer(_ object: [String: Any], _ key: String) throws -> Int {
            guard let value = object[key] as? Int else {
                throw SnapshotError.invalid("Missing number \(key)")
            }
            return value
        }
        func boolean(_ object: [String: Any], _ key: String) throws -> Bool {
            guard let value = object[key] as? Bool else {
                throw SnapshotError.invalid("Missing value \(key)")
            }
            return value
        }
        func text(_ object: [String: Any], _ key: String) throws -> String {
            guard let value = object[key] as? String else {
                throw SnapshotError.invalid("Missing text \(key)")
            }
            return value
        }
        func paddedASCII(_ value: String, count: Int) throws -> [UInt8] {
            guard value.canBeConverted(to: .ascii),
                  value.utf8.count <= count
            else {
                throw SnapshotError.invalid("Invalid ASCII text")
            }
            return Array(value.padding(toLength: count, withPad: " ", startingAt: 0).utf8)
        }
        func instrumentData(_ container: [String: Any]) throws -> [UInt8] {
            let instrument = try object(container["instrument"], "instrument")
            let isUserSample = try boolean(instrument, "userSample")
            guard !isUserSample else {
                throw SnapshotError.invalid(
                    "Fast-writing User Samples needs a separate sample mapping"
                )
            }
            let id = try integer(instrument, "id")
            let level = try integer(instrument, "levelTenthsDB")
            guard TD17InstrumentCatalog.instruments.indices.contains(id),
                  Self.levelRange.contains(level)
            else {
                throw SnapshotError.invalid("Instrument or level out of range")
            }
            return encodeUnsigned16Nibbles(id)
                + encodeSigned16Nibbles(level)
                + [0]
        }
        func catalogIndex(
            _ value: String,
            in catalog: [String],
            name: String
        ) throws -> Int {
            guard let index = catalog.firstIndex(of: value) else {
                throw SnapshotError.invalid("Unknown value \(name): \(value)")
            }
            return index
        }

        var blocks: [FastSnapshotBlock] = []
        let common = try object(snapshot["common"], "common")
        let commonData: [UInt8] =
            (try paddedASCII(text(common, "name"), count: 12))
            + (try paddedASCII(text(common, "subName"), count: 16))
            + (try checkedSigned16(
                integer(common, "kitVolumeTenthsDB"),
                "Kit volume",
                range: Self.levelRange
            ))
            + (try checkedSigned16(
                integer(common, "pedalHiHatVolumeTenthsDB"),
                "Pedal HH Volume",
                range: Self.levelRange
            ))
            + (try checkedSigned16(
                integer(common, "crossStickVolumeTenthsDB"),
                "XStick Volume",
                range: Self.levelRange
            ))
            + [try boolean(common, "crossStickEnabled") ? 1 : 0]
            + (try checkedSignedByte(
                integer(common, "hiHatBalance"),
                "HH Balance",
                range: Self.hiHatBalanceRange
            ))
        guard commonData.count == 0x2B else {
            throw SnapshotError.invalid("Invalid Kit Common block")
        }
        blocks.append(
            FastSnapshotBlock(
                name: "Kit Common",
                address: kitAddress(kitIndex: kitIndex),
                data: commonData
            )
        )

        let main = try objects(snapshot["main"], "main")
        let sub = try objects(snapshot["sub"], "sub")
        let mixer = try objects(snapshot["mixer"], "mixer")
        guard main.count == 20, sub.count == 20, mixer.count == 20 else {
            throw SnapshotError.invalid("Incomplete pad data")
        }

        for index in 0..<20 {
            blocks.append(
                FastSnapshotBlock(
                    name: "MAIN \(zoneNames[index])",
                    address: zoneAddress(index: index, kitIndex: kitIndex),
                    data: try instrumentData(main[index])
                )
            )
        }

        let layerTypes = TD17LayerCatalog.types
        for index in 0..<20 {
            let layer = sub[index]
            let mix = mixer[index]
            let pan = try integer(mix, "pan")
            let layerType = try catalogIndex(
                text(layer, "layerType"),
                in: layerTypes,
                name: "Layer Type"
            )
            let lowFrequency = try catalogIndex(
                text(mix, "lowFrequency"),
                in: TD17EQCatalog.lowFrequencies,
                name: "Low Frequency"
            )
            let midFrequency = try catalogIndex(
                text(mix, "midFrequency"),
                in: TD17EQCatalog.midFrequencies,
                name: "Mid Frequency"
            )
            let midQ = try catalogIndex(
                text(mix, "midQ"),
                in: TD17EQCatalog.qValues,
                name: "Mid Q"
            )
            let highFrequency = try catalogIndex(
                text(mix, "highFrequency"),
                in: TD17EQCatalog.highFrequencies,
                name: "High Frequency"
            )
            let data: [UInt8] =
                (try checkedSignedByte(pan, "Pan", range: Self.panRange))
                + [
                    try boolean(layer, "enabled") ? 1 : 0,
                    try checkedByte(layerType, "Layer Type"),
                    try checkedByte(
                        integer(layer, "fadePoint"),
                        "Fade Point",
                        range: Self.fadePointStorageRange
                    ),
                    try boolean(mix, "eqEnabled") ? 1 : 0,
                    try checkedByte(lowFrequency, "Low Frequency")
                ]
                + (try checkedSignedByte(
                    integer(mix, "lowGain"),
                    "EQ Low Gain",
                    range: Self.eqGainRange
                ))
                + [
                    try checkedByte(midFrequency, "Mid Frequency"),
                    try checkedByte(midQ, "Mid Q")
                ]
                + (try checkedSignedByte(
                    integer(mix, "midGain"),
                    "EQ Mid Gain",
                    range: Self.eqGainRange
                ))
                + [try checkedByte(highFrequency, "High Frequency")]
                + (try checkedSignedByte(
                    integer(mix, "highGain"),
                    "EQ High Gain",
                    range: Self.eqGainRange
                ))
                + (try checkedSigned16(
                    integer(mix, "ambienceSendTenthsDB"),
                    "Ambience Send",
                    range: Self.sendLevelRange
                ))
                + (try checkedSigned16(
                    integer(mix, "mfxSendTenthsDB"),
                    "MFX Send",
                    range: Self.sendLevelRange
                ))
                + (try checkedSigned16(
                    integer(mix, "reverbSendTenthsDB"),
                    "Reverb Send",
                    range: Self.sendLevelRange
                ))
            guard data.count == 0x1C else {
                throw SnapshotError.invalid("Invalid mixer block \(index)")
            }
            blocks.append(
                FastSnapshotBlock(
                    name: "Mixer \(zoneNames[index])",
                    address: layerCommonAddress(
                        zoneIndex: index,
                        kitIndex: kitIndex
                    ),
                    data: data
                )
            )
            blocks.append(
                FastSnapshotBlock(
                    name: "SUB \(zoneNames[index])",
                    address: layerInstrumentAddress(
                        zoneIndex: index,
                        kitIndex: kitIndex
                    ),
                    data: try instrumentData(layer)
                )
            )
        }

        // Blok KitUnitVEdit ma 0x21 bajtów, z czego rozpoznane są tylko
        // bajty 1–12 (primary / secondary / tertiary). Bajt 0 oraz bajty
        // 13–32 przechowują dane, których ten program nie potrafi zdekodować
        // ani zapisać w snapshocie.
        //
        // Poprzednia wersja wysyłała pełne 33 bajty, wypełniając nieznany
        // obszar zerami — czyli bezpowrotnie kasowała te ustawienia w module
        // przy każdym szybkim zapisie, a weryfikacja tego nie wykrywała, bo
        // porównuje wyłącznie trzy znane parametry.
        //
        // Zapisujemy więc wyłącznie znany fragment: adres przesunięty o 1
        // i 12 bajtów danych. To ten sam adres i format, którego używa
        // pojedynczy zapis `writeVEditTuning` / `writeVEditParameter`.
        func appendVEditBlocks(
            _ values: [[String: Any]],
            isSub: Bool
        ) throws {
            for value in values {
                let index = try integer(value, "zoneIndex")
                guard zoneNames.indices.contains(index) else {
                    throw SnapshotError.invalid("Invalid V-Edit zone")
                }
                let label = "V-Edit \(isSub ? "SUB" : "MAIN") \(zoneNames[index])"
                // Zakresy jak przy zapisie pojedynczego pola. Bez nich szybki
                // zapis przyjmował wartości, które ścieżka pojedynczego zapisu
                // odrzuca — a plik migawki to zwykły, czytelny JSON, który
                // program sam zachęca zapisać i przesłać dalej. Jedna
                // poprawka w edytorze tekstu wystarczała, żeby do pamięci
                // modułu poszła liczba spoza specyfikacji.
                //
                // −4800…4800 i 0…100 to sumy wszystkich gałęzi `vEditRange`
                // i zakresów strojenia, więc żadna prawdziwa wartość
                // z modułu nie zostanie odrzucona.
                let data: [UInt8] =
                    (try checkedSigned16(
                        integer(value, "primary"),
                        "\(label) — parametr 1",
                        range: -4800...4800
                    ))
                    + (try checkedUnsigned16(
                        integer(value, "secondary"),
                        "\(label) — parametr 2",
                        range: 0...100
                    ))
                    + (try checkedUnsigned16(
                        integer(value, "tertiary"),
                        "\(label) — parametr 3",
                        range: 0...100
                    ))
                let baseAddress = isSub
                    ? subVEditAddress(zoneIndex: index, kitIndex: kitIndex)
                    : vEditAddress(zoneIndex: index, kitIndex: kitIndex)
                blocks.append(
                    FastSnapshotBlock(
                        name: label,
                        address: addBase128(
                            baseAddress,
                            offset: [0x00, 0x00, 0x01]
                        ),
                        data: data
                    )
                )
            }
        }
        try appendVEditBlocks(
            objects(snapshot["vEditMain"], "vEditMain"),
            isSub: false
        )
        try appendVEditBlocks(
            objects(snapshot["vEditSub"], "vEditSub"),
            isSub: true
        )

        let ambience = try object(snapshot["ambience"], "ambience")
        let ambienceData: [UInt8] = [
            try boolean(ambience, "enabled") ? 1 : 0,
            try checkedByte(
                catalogIndex(
                    text(ambience, "roomType"),
                    in: TD17AmbienceCatalog.roomTypes,
                    name: "Room Type"
                ),
                "Room Type"
            ),
            try checkedByte(
                catalogIndex(
                    text(ambience, "roomSize"),
                    in: TD17AmbienceCatalog.roomSizes,
                    name: "Room Size"
                ),
                "Room Size"
            ),
            try checkedByte(
                integer(ambience, "roomShape"),
                "Room Shape",
                range: Self.roomShapeRange
            ),
            try checkedByte(
                catalogIndex(
                    text(ambience, "wallType"),
                    in: TD17AmbienceCatalog.wallTypes,
                    name: "Wall Type"
                ),
                "Wall Type"
            ),
            try checkedByte(
                catalogIndex(
                    text(ambience, "micPosition"),
                    in: TD17AmbienceCatalog.micPositions,
                    name: "Mic Position"
                ),
                "Mic Position"
            )
        ] + (try checkedSigned16(
            integer(ambience, "levelTenthsDB"),
            "Ambience Level",
            range: Self.effectLevelRange
        ))
        blocks.append(
            FastSnapshotBlock(
                name: "Ambience",
                address: ambienceAddress(kitIndex: kitIndex),
                data: ambienceData
            )
        )

        let reverb = try object(snapshot["reverb"], "reverb")
        let reverbTypes = TD17ReverbCatalog.types
        let reverbData: [UInt8] = [
            try boolean(reverb, "enabled") ? 1 : 0,
            try checkedByte(
                catalogIndex(
                    text(reverb, "type"),
                    in: reverbTypes,
                    name: "Reverb Type"
                ),
                "Reverb Type"
            ),
            try checkedByte(integer(reverb, "preDelay"), "Reverb Pre Delay"),
            try checkedByte(integer(reverb, "timeTenths"), "Reverb Time"),
            try checkedByte(integer(reverb, "density"), "Reverb Density"),
            try checkedByte(integer(reverb, "diffusion"), "Reverb Diffusion"),
            try checkedByte(integer(reverb, "lowDamp"), "Reverb LF Damp"),
            try checkedByte(integer(reverb, "highDamp"), "Reverb HF Damp"),
            try checkedByte(integer(reverb, "spread"), "Reverb Spread"),
            try checkedByte(integer(reverb, "tone"), "Reverb Tone")
        ] + (try checkedSigned16(
            integer(reverb, "levelTenthsDB"),
            "Reverb Level",
            range: Self.effectLevelRange
        ))
        blocks.append(
            FastSnapshotBlock(
                name: "Reverb",
                address: reverbAddress(kitIndex: kitIndex),
                data: reverbData
            )
        )

        let mfx = try object(snapshot["mfx"], "mfx")
        guard let mfxParameters = mfx["parameters"] as? [Int],
              mfxParameters.count == 32
        else {
            throw SnapshotError.invalid("Incomplete MFX parameters")
        }
        var mfxData: [UInt8] = [
            try checkedByte(
                catalogIndex(
                    text(mfx, "type"),
                    in: TD17MFXCatalog.types,
                    name: "MFX Type"
                ),
                "MFX Type"
            ),
            try boolean(mfx, "enabled") ? 1 : 0
        ] + (try checkedSigned16(
            integer(mfx, "levelTenthsDB"),
            "MFX Level",
            range: Self.effectLevelRange
        ))
        for (index, parameter) in mfxParameters.enumerated() {
            mfxData += try checkedSigned16(
                parameter,
                String(format: "MFX P%02d", index + 1)
            )
        }
        guard mfxData.count == 0x86 else {
            throw SnapshotError.invalid("Invalid MFX block")
        }
        blocks.append(
            FastSnapshotBlock(
                name: "MFX",
                address: mfxAddress(kitIndex: kitIndex),
                data: mfxData
            )
        )

        let comp = try object(snapshot["masterComp"], "masterComp")
        let compData: [UInt8] = [
            try boolean(comp, "enabled") ? 1 : 0,
            try checkedByte(
                catalogIndex(
                    text(comp, "type"),
                    in: TD17MasterCompCatalog.types,
                    name: "Master Comp Type"
                ),
                "Master Comp Type"
            )
        ]
        + (try checkedUnsigned16(
            integer(comp, "splitFrequency"),
            "Comp Split Frequency"
        ))
        + (try checkedSignedByte(integer(comp, "lowGain"), "Comp Low Gain"))
        + (try checkedSignedByte(integer(comp, "highGain"), "Comp High Gain"))
        + (try checkedSignedByte(
            integer(comp, "lowThreshold"),
            "Comp Low Threshold"
        ))
        + (try checkedSignedByte(
            integer(comp, "highThreshold"),
            "Comp High Threshold"
        ))
        + [
            try checkedByte(integer(comp, "lowRatio"), "Comp Low Ratio"),
            try checkedByte(integer(comp, "highRatio"), "Comp High Ratio"),
            try checkedByte(integer(comp, "lowKnee"), "Comp Low Knee"),
            try checkedByte(integer(comp, "highKnee"), "Comp High Knee"),
            try checkedByte(integer(comp, "lowAttack"), "Comp Low Attack"),
            try checkedByte(integer(comp, "highAttack"), "Comp High Attack"),
            try checkedByte(integer(comp, "lowRelease"), "Comp Low Release"),
            try checkedByte(integer(comp, "highRelease"), "Comp High Release"),
            try checkedByte(integer(comp, "balance"), "Comp Balance")
        ]
        guard compData.count == 0x17 else {
            throw SnapshotError.invalid("Invalid Master Comp block")
        }
        blocks.append(
            FastSnapshotBlock(
                name: "Master Comp",
                address: masterCompAddress(kitIndex: kitIndex),
                data: compData
            )
        )

        let midi = try objects(snapshot["midiNotes"], "midiNotes")
        guard midi.count == 24 else {
            throw SnapshotError.invalid("Incomplete MIDI assignments")
        }
        var midiData: [UInt8] = []
        for (index, item) in midi.enumerated() {
            midiData += try checkedUnsigned16(
                integer(item, "note"),
                "Nuta MIDI \(index + 1)",
                range: Self.midiNoteRange
            )
        }
        blocks.append(
            FastSnapshotBlock(
                name: "MIDI Notes",
                address: kitMIDIAddress(kitIndex: kitIndex),
                data: midiData
            )
        )
        return blocks
    }

    private func kitVolumeAddress(kitIndex: Int) -> [UInt8] {
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, 0x00, 0x1C]
        )
    }

    private func ambienceAddress(kitIndex: Int) -> [UInt8] {
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, 0x03, 0x00]
        )
    }

    private func reverbAddress(kitIndex: Int) -> [UInt8] {
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, 0x04, 0x00]
        )
    }

    private func mfxAddress(kitIndex: Int) -> [UInt8] {
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, 0x10, 0x00]
        )
    }

    private func masterCompAddress(kitIndex: Int) -> [UInt8] {
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, 0x05, 0x00]
        )
    }

    private func decodeAmbience(_ data: [UInt8]) -> TD17AmbienceInfo? {
        let roomTypes = [
            "BEACH", "LIVING ROOM", "BATH ROOM", "STUDIO", "GARAGE",
            "LOCKER ROOM", "THEATER", "CAVE", "GYMNASIUM", "DOME STADIUM",
            "BOOTH A", "BOOTH B", "STUDIO A", "STUDIO B", "BASEMENT",
            "JAZZ CLUB", "ROCK CLUB", "BALLROOM", "GATE", "CONCERT HALL",
            "SPORTS ARENA", "EXPO HALL", "BOTTLE", "CITY", "SPIRAL"
        ]
        let roomSizes = ["TINY", "SMALL", "MEDIUM", "LARGE", "HUGE"]
        let wallTypes = ["CURTAIN", "CLOTH", "WOOD", "PLASTER", "CONCRETE", "GLASS"]
        let micPositions = [
            "NEXT DOOR", "LOW FLOOR", "LOW", "MID LOW", "MID",
            "MID HIGH", "HIGH", "CEILING A", "CEILING B"
        ]

        guard data.count == 0x0A,
              roomTypes.indices.contains(Int(data[1])),
              roomSizes.indices.contains(Int(data[2])),
              wallTypes.indices.contains(Int(data[4])),
              micPositions.indices.contains(Int(data[5]))
        else {
            appendLog("Unexpected data in KitAmbience")
            return nil
        }

        return TD17AmbienceInfo(
            enabled: data[0] == 1,
            roomType: roomTypes[Int(data[1])],
            roomSize: roomSizes[Int(data[2])],
            roomShape: Int(data[3]),
            wallType: wallTypes[Int(data[4])],
            micPosition: micPositions[Int(data[5])],
            level: signedNibbleValue(Array(data[6...9]))
        )
    }

    private func decodeReverb(_ data: [UInt8]) -> TD17ReverbInfo? {
        let types = TD17ReverbCatalog.types
        guard data.count == 0x0E, types.indices.contains(Int(data[1])) else {
            appendLog("Unexpected data in KitReverb")
            return nil
        }

        return TD17ReverbInfo(
            enabled: data[0] == 1,
            type: types[Int(data[1])],
            preDelay: Int(data[2]),
            time: Int(data[3]),
            density: Int(data[4]),
            diffusion: Int(data[5]),
            lowDamp: Int(data[6]),
            highDamp: Int(data[7]),
            spread: Int(data[8]),
            tone: Int(data[9]),
            level: signedNibbleValue(Array(data[10...13]))
        )
    }

    private func decodeMFX(_ data: [UInt8]) -> TD17MFXInfo? {
        guard data.count == 0x86,
              TD17MFXCatalog.types.indices.contains(Int(data[0]))
        else {
            appendLog("Unexpected data in KitMFX: \(data.count) bytes")
            return nil
        }

        var parameters: [Int] = []
        for offset in stride(from: 6, through: 130, by: 4) {
            parameters.append(signedNibbleValue(Array(data[offset..<(offset + 4)])))
        }

        return TD17MFXInfo(
            enabled: data[1] == 1,
            type: TD17MFXCatalog.types[Int(data[0])],
            level: signedNibbleValue(Array(data[2...5])),
            parameters: parameters
        )
    }

    private func decodeMasterComp(_ data: [UInt8]) -> TD17MasterCompInfo? {
        guard data.count == 0x17,
              TD17MasterCompCatalog.types.indices.contains(Int(data[1]))
        else {
            appendLog("Unexpected data in KitMasterComp")
            return nil
        }

        return TD17MasterCompInfo(
            enabled: data[0] == 1,
            type: TD17MasterCompCatalog.types[Int(data[1])],
            splitFrequency: Int(decodeNibbles(Array(data[2...5]))),
            lowGain: signedByteFromNibbles(Array(data[6...7])),
            highGain: signedByteFromNibbles(Array(data[8...9])),
            lowThreshold: signedByteFromNibbles(Array(data[10...11])),
            highThreshold: signedByteFromNibbles(Array(data[12...13])),
            lowRatio: Int(data[14]),
            highRatio: Int(data[15]),
            lowKnee: Int(data[16]),
            highKnee: Int(data[17]),
            lowAttack: Int(data[18]),
            highAttack: Int(data[19]),
            lowRelease: Int(data[20]),
            highRelease: Int(data[21]),
            balance: Int(data[22])
        )
    }

    private func decodeKitCommon(_ data: [UInt8]) -> TD17KitCommonInfo? {
        guard data.count == 0x2B else {
            appendLog("Unexpected data in KitCommon: \(data.count) bytes")
            return nil
        }

        func ascii(_ bytes: ArraySlice<UInt8>) -> String {
            String(bytes: bytes, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        return TD17KitCommonInfo(
            name: ascii(data[0...11]),
            subName: ascii(data[12...27]),
            kitVolume: signedNibbleValue(Array(data[28...31])),
            pedalHiHatVolume: signedNibbleValue(Array(data[32...35])),
            crossStickVolume: signedNibbleValue(Array(data[36...39])),
            crossStickEnabled: data[40] == 1,
            hiHatBalance: signedByteFromNibbles(Array(data[41...42]))
        )
    }

    private func decodeKitMIDI(_ data: [UInt8]) -> [TD17MIDINoteInfo]? {
        let names = TD17MIDINoteCatalog.names
        guard data.count == 0x60 else {
            appendLog("Unexpected data in KitMIDI: \(data.count) bytes")
            return nil
        }

        return names.indices.map { index in
            let offset = index * 4
            return TD17MIDINoteInfo(
                index: index,
                name: names[index],
                note: decodeNibbles(Array(data[offset..<(offset + 4)]))
            )
        }
    }

    private func requestKitName(kitIndex: Int) {
        sendRQ1(
            address: kitAddress(kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x0C]
        )
    }

    private func requestZone(index: Int, kitIndex: Int) {
        sendRQ1(
            address: zoneAddress(index: index, kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x09]
        )
    }

    private func zoneAddress(index: Int, kitIndex: Int) -> [UInt8] {
        // KitUnitInst Main 1...20 occupy offsets 00 40 00...00 53 00.
        let unit = 0x40 + index
        return addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, UInt8(unit), 0x00]
        )
    }

    private func requestLayerCommon(zoneIndex: Int, kitIndex: Int) {
        sendRQ1(
            address: layerCommonAddress(
                zoneIndex: zoneIndex,
                kitIndex: kitIndex
            ),
            size: [0x00, 0x00, 0x00, 0x1C]
        )
    }

    private func requestLayerInstrument(zoneIndex: Int, kitIndex: Int) {
        sendRQ1(
            address: layerInstrumentAddress(
                zoneIndex: zoneIndex,
                kitIndex: kitIndex
            ),
            size: [0x00, 0x00, 0x00, 0x09]
        )
    }

    private func layerCommonAddress(
        zoneIndex: Int,
        kitIndex: Int
    ) -> [UInt8] {
        // KitUnitCommon 1...20 occupy 00 20 00...00 33 00.
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, UInt8(0x20 + zoneIndex), 0x00]
        )
    }

    private func layerInstrumentAddress(
        zoneIndex: Int,
        kitIndex: Int
    ) -> [UInt8] {
        // KitUnitInst Sub 1...20 occupy 00 60 00...00 73 00.
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x00, UInt8(0x60 + zoneIndex), 0x00]
        )
    }

    private func decodeLayerCommon(
        _ data: [UInt8],
        zoneIndex: Int? = nil
    ) -> LayerCommon? {
        guard data.count == 0x1C else {
            appendLog("Unexpected size of KitUnitCommon: \(data.count)")
            return nil
        }

        let layerTypes = TD17LayerCatalog.types
        let typeIndex = Int(data[3])
        guard layerTypes.indices.contains(typeIndex) else {
            appendLog("Nieznany Layer Type: \(typeIndex)")
            return nil
        }

        guard let resolvedZoneIndex = zoneIndex ?? readPhaseZoneIndex else {
            appendLog("Could not determine the KitUnitCommon zone")
            return nil
        }

        let lowFrequencies = [
            "20Hz", "25Hz", "31.5Hz", "40Hz", "50Hz", "63Hz",
            "80Hz", "100Hz", "125Hz", "160Hz", "200Hz", "250Hz",
            "315Hz", "400Hz", "500Hz", "630Hz", "800Hz", "1kHz"
        ]
        let midFrequencies = lowFrequencies + [
            "1.25kHz", "1.6kHz", "2kHz", "2.5kHz", "3.15kHz", "4kHz",
            "5kHz", "6.3kHz", "8kHz", "10kHz", "12.5kHz", "16kHz"
        ]
        let highFrequencies = [
            "1kHz", "1.25kHz", "1.6kHz", "2kHz", "2.5kHz", "3.15kHz",
            "4kHz", "5kHz", "6.3kHz", "8kHz", "10kHz", "12.5kHz", "16kHz"
        ]
        let qValues = ["0.5", "1.0", "2.0", "4.0", "8.0"]

        let lowFrequencyIndex = Int(data[6])
        let midFrequencyIndex = Int(data[9])
        let qIndex = Int(data[10])
        let highFrequencyIndex = Int(data[13])

        guard
            lowFrequencies.indices.contains(lowFrequencyIndex),
            midFrequencies.indices.contains(midFrequencyIndex),
            qValues.indices.contains(qIndex),
            highFrequencies.indices.contains(highFrequencyIndex)
        else {
            appendLog("Unknown Pad EQ frequency/Q index")
            return nil
        }

        let mixInfo = TD17MixInfo(
            zoneIndex: resolvedZoneIndex,
            zoneName: zoneNames[resolvedZoneIndex],
            pan: signedByteFromNibbles(Array(data[0...1])),
            eqEnabled: data[5] == 1,
            lowFrequency: lowFrequencies[lowFrequencyIndex],
            lowGain: signedByteFromNibbles(Array(data[7...8])),
            midFrequency: midFrequencies[midFrequencyIndex],
            midQ: qValues[qIndex],
            midGain: signedByteFromNibbles(Array(data[11...12])),
            highFrequency: highFrequencies[highFrequencyIndex],
            highGain: signedByteFromNibbles(Array(data[14...15])),
            ambienceSend: signedNibbleValue(Array(data[16...19])),
            mfxSend: signedNibbleValue(Array(data[20...23])),
            reverbSend: signedNibbleValue(Array(data[24...27]))
        )

        return LayerCommon(
            enabled: data[2] == 1,
            type: layerTypes[typeIndex],
            fadePoint: Int(data[4]),
            mixInfo: mixInfo
        )
    }

    private var readPhaseZoneIndex: Int? {
        if case let .layerCommon(index) = readPhase { return index }
        return nil
    }

    private func signedByteFromNibbles(_ bytes: [UInt8]) -> Int {
        Int(Int8(bitPattern: UInt8(decodeNibbles(bytes))))
    }

    private func updateMixDrafts(_ info: TD17MixInfo) {
        panDrafts[info.zoneIndex] = info.pan
        eqEnabledDrafts[info.zoneIndex] = info.eqEnabled
        eqLowGainDrafts[info.zoneIndex] = info.lowGain
        eqMidGainDrafts[info.zoneIndex] = info.midGain
        eqHighGainDrafts[info.zoneIndex] = info.highGain
        eqLowFrequencyDrafts[info.zoneIndex] =
            TD17EQCatalog.lowFrequencies.firstIndex(of: info.lowFrequency) ?? 0
        eqMidFrequencyDrafts[info.zoneIndex] =
            TD17EQCatalog.midFrequencies.firstIndex(of: info.midFrequency) ?? 0
        eqMidQDrafts[info.zoneIndex] =
            TD17EQCatalog.qValues.firstIndex(of: info.midQ) ?? 0
        eqHighFrequencyDrafts[info.zoneIndex] =
            TD17EQCatalog.highFrequencies.firstIndex(of: info.highFrequency) ?? 0
        ambienceSendDrafts[info.zoneIndex] = info.ambienceSend
        mfxSendDrafts[info.zoneIndex] = info.mfxSend
        reverbSendDrafts[info.zoneIndex] = info.reverbSend
    }

    private func updateAmbienceDrafts(_ info: TD17AmbienceInfo) {
        ambienceEnabledDraft = info.enabled
        ambienceLevelDraft = info.level
        ambienceRoomTypeDraft =
            TD17AmbienceCatalog.roomTypes.firstIndex(of: info.roomType) ?? 0
        ambienceRoomSizeDraft =
            TD17AmbienceCatalog.roomSizes.firstIndex(of: info.roomSize) ?? 0
        ambienceRoomShapeDraft = info.roomShape
        ambienceWallTypeDraft =
            TD17AmbienceCatalog.wallTypes.firstIndex(of: info.wallType) ?? 0
        ambienceMicPositionDraft =
            TD17AmbienceCatalog.micPositions.firstIndex(of: info.micPosition) ?? 0
    }

    private func updateReverbDrafts(_ info: TD17ReverbInfo) {
        let types = TD17ReverbCatalog.types
        reverbEnabledDraft = info.enabled
        reverbTypeDraft = types.firstIndex(of: info.type) ?? 0
        reverbParameterDrafts = [
            0: info.preDelay,
            1: info.time,
            2: info.density,
            3: info.diffusion,
            4: info.lowDamp,
            5: info.highDamp,
            6: info.spread,
            7: info.tone
        ]
        reverbLevelDraft = info.level
    }

    private func updateMFXDrafts(_ info: TD17MFXInfo) {
        mfxEnabledDraft = info.enabled
        mfxTypeDraft = TD17MFXCatalog.types.firstIndex(of: info.type) ?? 0
        mfxLevelDraft = info.level
        mfxParameterDrafts = Dictionary(
            uniqueKeysWithValues: info.parameters.enumerated().map {
                ($0.offset, $0.element)
            }
        )
    }

    private func updateMasterCompDrafts(_ info: TD17MasterCompInfo) {
        masterCompEnabledDraft = info.enabled
        masterCompTypeDraft =
            TD17MasterCompCatalog.types.firstIndex(of: info.type) ?? 0
        masterCompParameterDrafts = [
            0: info.splitFrequency,
            1: info.lowGain,
            2: info.highGain,
            3: info.lowThreshold,
            4: info.highThreshold,
            5: info.lowRatio,
            6: info.highRatio,
            7: info.lowKnee,
            8: info.highKnee,
            9: info.lowAttack,
            10: info.highAttack,
            11: info.lowRelease,
            12: info.highRelease,
            13: info.balance
        ]
    }

    private func updateKitCommonDrafts(_ info: TD17KitCommonInfo) {
        kitNameDraft = info.name
        kitSubNameDraft = info.subName
        pedalHiHatVolumeDraft = info.pedalHiHatVolume
        crossStickVolumeDraft = info.crossStickVolume
        crossStickEnabledDraft = info.crossStickEnabled
        hiHatBalanceDraft = info.hiHatBalance
    }

    private func requestVEdit(zoneIndex: Int, kitIndex: Int) {
        sendRQ1(
            address: vEditAddress(zoneIndex: zoneIndex, kitIndex: kitIndex),
            size: [0x00, 0x00, 0x00, 0x21]
        )
    }

    private func vEditAddress(zoneIndex: Int, kitIndex: Int) -> [UInt8] {
        // KitUnitVEdit Main 1...20 occupy 01 00 00...01 13 00.
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x01, UInt8(zoneIndex), 0x00]
        )
    }

    private func decodeVEdit(
        _ data: [UInt8],
        zoneIndex: Int,
        instrument: TD17InstrumentInfo,
        zonePrefix: String = ""
    ) -> TD17VEditInfo? {
        guard data.count == 0x21 else {
            appendLog("Unexpected size of KitUnitVEdit: \(data.count)")
            return nil
        }

        let first = signedNibbleValue(Array(data[1...4]))
        let second = decodeNibbles(Array(data[5...8]))
        let third = decodeNibbles(Array(data[9...12]))
        let group = instrument.groupName
        var values: [String]

        switch group {
        case "KICK":
            values = [
                "Tuning \(signedText(first))",
                "Muffling \(kickMuffling(second))",
                "Snare Buzz \(offOrNumber(third))"
            ]
        case "SNARE":
            values = [
                "Tuning \(signedText(first))",
                "Muffling \(snareMuffling(second))",
                "Strainer \(strainerName(third))"
            ]
        case "CROSS STICK":
            values = [
                "Tuning \(signedText(first))",
                "Muffling \(snareMuffling(second))"
            ]
        case "TOM":
            values = [
                "Tuning \(signedText(first))",
                "Muffling \(tomMuffling(second))",
                "Snare Buzz \(offOrNumber(third))"
            ]
        case "HI-HAT":
            values = [
                "Size \(sizeText(first))",
                "Fixed \(fixedName(second))"
            ]
        case "RIDE", "CRASH", "SPLASH/CHINA":
            values = [
                "Size \(sizeText(first))",
                "Muffling \(second == 0 ? "OFF" : "TAPE\(second)")"
            ]
        default:
            values = [
                "Pitch \(first) cent",
                "Decay \(second)"
            ]
        }

        return TD17VEditInfo(
            zoneIndex: zoneIndex,
            zoneName: zonePrefix + zoneNames[zoneIndex],
            instrumentGroup: group,
            primaryValue: first,
            secondaryValue: second,
            tertiaryValue: third,
            values: values
        )
    }

    private func vEditRange(
        group: String,
        parameter: Int
    ) -> ClosedRange<Int> {
        if parameter == 2 {
            switch group {
            case "HI-HAT": return 0...4
            case "RIDE", "CRASH", "SPLASH/CHINA": return 0...19
            case "KICK", "SNARE", "CROSS STICK", "TOM": return 0...9
            default: return 1...100
            }
        }
        switch group {
        case "KICK", "SNARE", "TOM": return 0...8
        default: return 0...0
        }
    }

    private var activeLayerIndices: [Int] {
        layers.filter(\.enabled).map(\.zoneIndex).sorted()
    }

    private func requestSubVEdit(zoneIndex: Int, kitIndex: Int) {
        sendRQ1(
            address: subVEditAddress(
                zoneIndex: zoneIndex,
                kitIndex: kitIndex
            ),
            size: [0x00, 0x00, 0x00, 0x21]
        )
    }

    private func subVEditAddress(zoneIndex: Int, kitIndex: Int) -> [UInt8] {
        // KitUnitVEdit Sub 1...20 occupy 01 20 00...01 33 00.
        addBase128(
            kitAddress(kitIndex: kitIndex),
            offset: [0x01, UInt8(0x20 + zoneIndex), 0x00]
        )
    }

    private func signedNibbleValue(_ bytes: [UInt8]) -> Int {
        Int(Int16(bitPattern: UInt16(decodeNibbles(bytes))))
    }

    private func signedText(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func sizeText(_ rawValue: Int) -> String {
        String(format: "%.1f\"", 1.0 + Double(rawValue) / 2.0)
    }

    private func offOrNumber(_ value: Int) -> String {
        value == 0 ? "OFF" : "\(value)"
    }

    private func kickMuffling(_ value: Int) -> String {
        let names = [
            "OFF", "TAPE1", "TAPE2", "TAPE3", "TAPE4",
            "BLANKET1", "BLANKET2", "BLANKET3", "WEIGHT1", "WEIGHT2"
        ]
        return names.indices.contains(value) ? names[value] : "UNKNOWN(\(value))"
    }

    private func snareMuffling(_ value: Int) -> String {
        let names = [
            "OFF", "TAPE1", "TAPE2", "TAPE3", "TAPE4",
            "TAPE5", "TAPE6", "TAPE7", "DONUT1", "DONUT2"
        ]
        return names.indices.contains(value) ? names[value] : "UNKNOWN(\(value))"
    }

    private func tomMuffling(_ value: Int) -> String {
        let names = [
            "OFF", "TAPE1", "TAPE2", "TAPE3", "TAPE4",
            "TAPE5", "FELT1", "FELT2", "FELT3", "FELT4"
        ]
        return names.indices.contains(value) ? names[value] : "UNKNOWN(\(value))"
    }

    private func strainerName(_ value: Int) -> String {
        let names = [
            "LOOSE1", "LOOSE2", "LOOSE3",
            "MEDIUM1", "MEDIUM2", "MEDIUM3",
            "TIGHT1", "TIGHT2", "TIGHT3"
        ]
        return names.indices.contains(value) ? names[value] : "UNKNOWN(\(value))"
    }

    private func fixedName(_ value: Int) -> String {
        value == 0 ? "NORMAL" : "FIXED\(value)"
    }

    private func decodeInstrument(_ data: [UInt8]) -> TD17InstrumentInfo? {
        guard data.count == 9 else {
            appendLog("Unexpected size of danych instrumentu: \(data.count)")
            return nil
        }

        let instrument = decodeNibbles(Array(data[0...3]))
        let rawLevel = UInt16(decodeNibbles(Array(data[4...7])))
        let signedLevel = Int(Int16(bitPattern: rawLevel))

        return TD17InstrumentInfo(
            instrumentID: instrument,
            levelTenthsDB: signedLevel,
            isUserSample: data[8] == 1
        )
    }

    private func decodeNibbles(_ bytes: [UInt8]) -> Int {
        bytes.reduce(0) { ($0 << 4) | Int($1 & 0x0F) }
    }

    private func encodeSigned16Nibbles(_ value: Int) -> [UInt8] {
        let raw = UInt16(bitPattern: Int16(value))
        return [
            UInt8((raw >> 12) & 0x0F),
            UInt8((raw >> 8) & 0x0F),
            UInt8((raw >> 4) & 0x0F),
            UInt8(raw & 0x0F)
        ]
    }

    private func encodeUnsigned16Nibbles(_ value: Int) -> [UInt8] {
        let raw = UInt16(value)
        return [
            UInt8((raw >> 12) & 0x0F),
            UInt8((raw >> 8) & 0x0F),
            UInt8((raw >> 4) & 0x0F),
            UInt8(raw & 0x0F)
        ]
    }

    // MARK: - Kodowanie z kontrolą zakresu
    //
    // `UInt8(_:)`, `UInt16(_:)` i `Int16(_:)` to inicjalizatory pułapkujące —
    // wartość spoza zakresu nie zwraca błędu, tylko zabija proces. Wartości
    // wczytane ze snapshotu JSON pochodzą z pliku, który użytkownik mógł
    // ręcznie zmodyfikować, więc każde takie przejście musi być sprawdzone.

    private func checkedRange(
        _ value: Int,
        _ range: ClosedRange<Int>,
        _ name: String
    ) throws -> Int {
        guard range.contains(value) else {
            throw SnapshotError.invalid(
                "\(name): value \(value) out of range "
                    + "\(range.lowerBound)…\(range.upperBound)"
            )
        }
        return value
    }

    private func checkedByte(
        _ value: Int,
        _ name: String,
        range: ClosedRange<Int> = 0...127
    ) throws -> UInt8 {
        UInt8(try checkedRange(value, range, name))
    }

    private func checkedSigned16(
        _ value: Int,
        _ name: String,
        range: ClosedRange<Int> = -32768...32767
    ) throws -> [UInt8] {
        encodeSigned16Nibbles(try checkedRange(value, range, name))
    }

    private func checkedUnsigned16(
        _ value: Int,
        _ name: String,
        range: ClosedRange<Int> = 0...65535
    ) throws -> [UInt8] {
        encodeUnsigned16Nibbles(try checkedRange(value, range, name))
    }

    private func checkedSignedByte(
        _ value: Int,
        _ name: String,
        range: ClosedRange<Int> = -128...127
    ) throws -> [UInt8] {
        encodeSignedByteNibbles(try checkedRange(value, range, name))
    }

    private func encodeSignedByteNibbles(_ value: Int) -> [UInt8] {
        let raw = UInt8(bitPattern: Int8(value))
        return [
            UInt8((raw >> 4) & 0x0F),
            UInt8(raw & 0x0F)
        ]
    }

    private func panText(_ value: Int) -> String {
        if value == 0 { return "CENTER" }
        return value < 0 ? "L\(-value)" : "R\(value)"
    }

    private func signedDBText(_ value: Int) -> String {
        value > 0 ? "+\(value) dB" : "\(value) dB"
    }

    private var eqShapeLists: [[String]] {
        [
            TD17EQCatalog.lowFrequencies,
            TD17EQCatalog.midFrequencies,
            TD17EQCatalog.qValues,
            TD17EQCatalog.highFrequencies
        ]
    }

    private func ambienceParameterText(_ parameterIndex: Int, _ value: Int) -> String {
        if parameterIndex == 0,
           TD17AmbienceCatalog.roomTypes.indices.contains(value) {
            return TD17AmbienceCatalog.roomTypes[value]
        }
        if parameterIndex == 1,
           TD17AmbienceCatalog.roomSizes.indices.contains(value) {
            return TD17AmbienceCatalog.roomSizes[value]
        }
        if parameterIndex == 2 { return "\(value)" }
        if parameterIndex == 3,
           TD17AmbienceCatalog.wallTypes.indices.contains(value) {
            return TD17AmbienceCatalog.wallTypes[value]
        }
        if parameterIndex == 4,
           TD17AmbienceCatalog.micPositions.indices.contains(value) {
            return TD17AmbienceCatalog.micPositions[value]
        }
        return "\(value)"
    }

    private func reverbValueText(_ parameterIndex: Int, _ value: Int) -> String {
        if parameterIndex == 0 { return value == 1 ? "ON" : "OFF" }
        if parameterIndex == 1 {
            let types = TD17ReverbCatalog.types
            return types.indices.contains(value) ? types[value] : "\(value)"
        }
        if parameterIndex == 2 { return "\(value) ms" }
        if parameterIndex == 3 {
            return String(format: "%.1f s", Double(value) / 10.0)
        }
        if parameterIndex == 10 { return levelText(value) }
        return "\(value)"
    }

    private func mfxValueText(_ parameterIndex: Int, _ value: Int) -> String {
        if parameterIndex == 0 { return value == 1 ? "ON" : "OFF" }
        if parameterIndex == 1 {
            return TD17MFXCatalog.types.indices.contains(value)
                ? TD17MFXCatalog.types[value]
                : "\(value)"
        }
        if parameterIndex == 2 { return levelText(value) }
        return "\(value)"
    }

    private func masterCompValueText(_ parameterIndex: Int, _ value: Int) -> String {
        if parameterIndex == 0 { return value == 1 ? "ON" : "OFF" }
        if parameterIndex == 1 {
            return TD17MasterCompCatalog.types.indices.contains(value)
                ? TD17MasterCompCatalog.types[value]
                : "\(value)"
        }
        return "\(value)"
    }

    private func kitCommonValueText(_ parameterIndex: Int, _ value: Int) -> String {
        if parameterIndex < 2 { return levelText(value) }
        if parameterIndex == 2 { return value == 1 ? "ON" : "OFF" }
        return "\(value)"
    }

    private func addBase128(_ address: [UInt8], offset: [UInt8]) -> [UInt8] {
        var value = address.reduce(0) { ($0 << 7) | Int($1 & 0x7F) }
        value += offset.reduce(0) { ($0 << 7) | Int($1 & 0x7F) }
        return encodeBase128(value)
    }

    private func kitAddress(kitIndex: Int) -> [UInt8] {
        // Kit 1 starts at 03 00 00 00; consecutive kits are 00 02 00 00 apart.
        //
        // Zacisk jest ostatnią linią obrony i celowo siedzi tutaj, w jednym
        // miejscu, przez które przechodzi **każdy** adres zapisu do kitu.
        // Numer kitu przychodzi z modułu, a moduł na tym łączu to cokolwiek,
        // co odpowie z właściwą sumą kontrolną. Numer 128 dawał adres
        // 04 7E 00 00 — daleko za końcem obszaru kitów, czyli zapis w miejsce,
        // o którym nie wiemy nic.
        let safeIndex = min(profile.kitCount - 1, max(0, kitIndex))
        return encodeBase128(
            profile.kitAreaBase + safeIndex * profile.kitStride
        )
    }

    private func encodeBase128(_ input: Int) -> [UInt8] {
        var value = input
        var address = [UInt8](repeating: 0, count: 4)
        for index in stride(from: 3, through: 0, by: -1) {
            address[index] = UInt8(value & 0x7F)
            value >>= 7
        }
        return address
    }

    private func rolandChecksum(_ bytes: [UInt8]) -> UInt8 {
        UInt8((128 - (bytes.reduce(0) { $0 + Int($1) } % 128)) % 128)
    }

    private func endpointInfo(for endpoint: MIDIEndpointRef) -> MIDIEndpointInfo? {
        guard endpoint != 0 else { return nil }

        var uniqueID: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)

        return MIDIEndpointInfo(
            id: uniqueID,
            name: endpointName(endpoint),
            reference: endpoint
        )
    }

    private func endpointName(_ endpoint: MIDIEndpointRef) -> String {
        var value: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(
            endpoint,
            kMIDIPropertyDisplayName,
            &value
        ) == noErr, let value {
            return value.takeRetainedValue() as String
        }
        return "MIDI device"
    }

    private func retainedSelection(
        _ id: MIDIEndpointID?,
        in endpoints: [MIDIEndpointInfo]
    ) -> MIDIEndpointID? {
        guard let id, endpoints.contains(where: { $0.id == id }) else {
            return nil
        }
        return id
    }

    /// Punkt końcowy wyglądający na moduł: najpierw ten, na który wskazuje
    /// bieżący profil, a gdy takiego nie ma — dowolny znany.
    private func td17Endpoint(
        in endpoints: [MIDIEndpointInfo]
    ) -> MIDIEndpointInfo? {
        endpoints.first {
            $0.name.localizedCaseInsensitiveContains(profile.portKeyword)
        }
        ?? endpoints.first { ModuleProfile.matching(portName: $0.name) != nil }
    }

    /// Dopisuje linię do bufora i planuje zbiorcze odświeżenie widoku.
    ///
    /// Pełny odczyt kitu generuje ponad 200 linii w kilka sekund. Bez
    /// buforowania każda z nich wymuszałaby osobne przeliczenie widoku.
    private func appendLog(_ message: String) {
        // Limit **tutaj**, a nie dopiero przy zrzucie do widoku.
        //
        // `flushLog` najpierw przepisuje wszystko do `logLines`, a przycina
        // dopiero potem — szczyt zużycia pamięci był więc pełny. A jedna
        // linia logu potrafi powstać z jednego bajtu na wejściu: strumień
        // samych `0xF0` generował komunikat „porzucona ramka" na każdy bajt.
        // Do najbliższego zrzutu (150 ms) rosło to bez żadnej granicy.
        if pendingLogLines.count >= maximumLogLines {
            pendingLogLines.removeFirst(
                pendingLogLines.count - maximumLogLines + 1
            )
        }
        pendingLogLines.append(message)
        guard logFlushTask == nil else { return }

        logFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled else { return }
            self.flushLog()
        }
    }

    private func flushLog() {
        logFlushTask = nil
        guard !pendingLogLines.isEmpty else { return }

        for text in pendingLogLines {
            logLines.append(TD17LogLine(id: nextLogLineID, text: text))
            nextLogLineID += 1
        }
        pendingLogLines.removeAll(keepingCapacity: true)

        guard logLines.count > maximumLogLines else { return }

        // +1 na linię informującą o obcięciu, żeby po obcięciu tablica
        // miała dokładnie `maximumLogLines` elementów, a nie o jeden więcej
        // — inaczej każdy kolejny zrzut obcinałby ją ponownie.
        let excess = logLines.count - maximumLogLines + 1
        logLines.removeFirst(excess)
        logLines.insert(
            TD17LogLine(
                id: nextLogLineID,
                text: "… skipped \(excess) older lines "
                    + "(limit \(maximumLogLines))"
            ),
            at: 0
        )
        nextLogLineID += 1
    }

    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Składa bajty ze wszystkich pakietów listy.
    ///
    /// Poprzednia wersja kopiowała pierwszy `MIDIPacket` na stos i wołała
    /// `MIDIPacketNext(&packet)` na tej kopii — adres kolejnego pakietu był
    /// więc liczony względem zmiennej lokalnej, a nie oryginalnej listy.
    /// Działało to wyłącznie dla `numPackets == 1`; przy dwóch i więcej
    /// pakietach (a tak jest, gdy moduł wysyła równolegle nuty albo zegar)
    /// druga iteracja czytała niezainicjalizowaną pamięć stosu.
    ///
    /// `unsafeSequence()` przechodzi po oryginalnej liście, więc adresy
    /// kolejnych pakietów są liczone poprawnie.
    ///
    /// Ograniczenie: `MIDIPacket.data` jest zadeklarowane jako krotka 256
    /// bajtów, więc tyle maksymalnie odczytujemy z jednego pakietu. Najdłuższa
    /// ramka, jaką wysyła TD-17, to MFX (ok. 145 bajtów), a dłuższe transfery
    /// CoreMIDI i tak dzieli na kolejne pakiety tej samej listy.
    nonisolated private static func bytes(
        from packetList: UnsafePointer<MIDIPacketList>
    ) -> [UInt8] {
        var result: [UInt8] = []

        for packet in packetList.unsafeSequence() {
            let length = Int(packet.pointee.length)
            guard length > 0 else { continue }

            // Czytamy dokładnie `length` bajtów spod adresu pola `data`,
            // zamiast kopiować całą 256-bajtową krotkę.
            //
            // `packet.pointee.data` to **wczytanie wartości** wszystkich 256
            // bajtów. Pakiety w liście leżą ciasno jeden za drugim, więc
            // pakiet o trzech bajtach zajmuje kilkanaście — a odczyt i tak
            // sięgał 256. Dla ostatniego pakietu wychodziło to poza bufor,
            // który dał nam CoreMIDI. Do tego `data` jest polem o zmiennej
            // długości: pakiet dłuższy niż 256 bajtów gubił resztę po cichu,
            // rozbijając ramkę w środku.
            if let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data) {
                let base = UnsafeRawPointer(packet).advanced(by: dataOffset)
                result.append(
                    contentsOf: UnsafeRawBufferPointer(start: base, count: length)
                )
            } else {
                // Gałąź awaryjna — zachowanie sprzed poprawki. Nie powinna
                // się nigdy wykonać, ale lepsza niż wymuszone rozpakowanie.
                withUnsafeBytes(of: packet.pointee.data) { rawBuffer in
                    result.append(
                        contentsOf: rawBuffer.prefix(min(length, rawBuffer.count))
                    )
                }
            }
        }

        return result
    }
}
