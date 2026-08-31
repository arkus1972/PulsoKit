import Foundation

/// Wszystko, czym jeden moduł Rolanda różni się od drugiego.
///
/// Do wersji 1.0 te wartości leżały wpisane na sztywno w `MIDIManager`.
/// Rozmowa z modułem — RQ1, DT1, suma kontrolna, adresy w bazie 128,
/// weryfikacja każdego zapisu — jest identyczna dla całej rodziny V-Drums;
/// różni się **mapa**, nie maszyneria. Ten typ jest tą mapą.
///
/// Dzięki temu dołożenie kolejnego modułu to dopisanie danych, a nie
/// przepisywanie logiki.
struct ModuleProfile: Equatable, Identifiable {

    enum Kind: String, Equatable {
        case td17 = "TD-17"
        case td27 = "TD-27"
    }

    let kind: Kind

    /// Fragment nazwy portu MIDI, po którym rozpoznajemy moduł, zanim
    /// jeszcze o cokolwiek go zapytamy.
    let portKeyword: String

    /// Cztery bajty identyfikatora modelu w ramce SysEx Rolanda.
    let modelID: [UInt8]

    /// Adres pierwszego kitu, już rozpakowany do liczby.
    let kitAreaBase: Int

    /// Odstęp między kolejnymi kitami.
    let kitStride: Int

    /// Ile kitów ma moduł.
    let kitCount: Int

    /// Nazwy stref w kolejności bloków w pamięci kitu.
    let zoneNames: [String]

    /// Ile fizycznych wejść triggerowych.
    let triggerInputCount: Int

    /// **Czy mapa adresów tego modułu została potwierdzona na żywym sprzęcie.**
    ///
    /// To jeden przełącznik, od którego zależy wszystko poza rozpoznaniem
    /// modułu i zrzutem surowych bajtów. Przy `false`:
    ///
    /// * `sendDT1` nie wypuszcza ani jednej ramki — zapis pod źle odgadnięty
    ///   adres trafia w nieznane miejsce cudzego instrumentu,
    /// * odczyt strukturalny jest wyłączony — czytanie kitu adresami wziętymi
    ///   z innego modułu daje śmieci, a śmieci pokazane jako wartości
    ///   parametrów są gorsze niż uczciwe „nie wiem".
    ///
    /// Zostaje sonda: `probeKitArea`, która zrzuca surowe bajty do logu.
    /// Dokładnie tą drogą powstała mapa triggerów TD-17.
    let hasVerifiedMap: Bool

    /// Wolno pisać wyłącznie tam, gdzie mapa jest potwierdzona.
    var allowsWriting: Bool { hasVerifiedMap }

    var id: String { kind.rawValue }
    var displayName: String { kind.rawValue }

    // MARK: - Znane moduły

    /// TD-17 — jedyny sprawdzony na sprzęcie.
    static let td17 = ModuleProfile(
        kind: .td17,
        portKeyword: "TD-17",
        modelID: [0x00, 0x00, 0x00, 0x4B],
        // 03 00 00 00, odstęp 00 02 00 00.
        kitAreaBase: 3 * 128 * 128 * 128,
        kitStride: 2 * 128 * 128,
        kitCount: 100,
        zoneNames: TD17ZoneCatalog.names,
        triggerInputCount: 10,
        hasVerifiedMap: true
    )

    /// TD-27 — na razie **tylko do odczytu**.
    ///
    /// Struktura jest bliźniacza wobec TD-17: te same RQ1/DT1, ta sama
    /// arytmetyka adresów, ten sam odstęp między kitami i tyle samo kitów.
    /// Różnice: inny identyfikator modelu, obszar kitów przesunięty na `04`
    /// (pod `03` TD-27 trzyma SetList, czego TD-17 nie ma) oraz dwanaście
    /// wejść i dwadzieścia cztery strefy zamiast dziesięciu i dwudziestu.
    ///
    /// Układ parametrów **wewnątrz** kitu nie jest jeszcze odwzorowany —
    /// od tego jest zrzut surowych bajtów (`probeKitArea`), dokładnie tą samą
    /// drogą, którą rozpoznaliśmy mapę triggerów TD-17.
    static let td27 = ModuleProfile(
        kind: .td27,
        portKeyword: "TD-27",
        modelID: [0x00, 0x00, 0x00, 0x63],
        // 04 00 00 00, odstęp taki sam jak w TD-17.
        kitAreaBase: 4 * 128 * 128 * 128,
        kitStride: 2 * 128 * 128,
        kitCount: 100,
        zoneNames: TD27ZoneCatalog.names,
        triggerInputCount: 12,
        hasVerifiedMap: false
    )

    static let all: [ModuleProfile] = [.td17, .td27]

    /// Dopasowanie po identyfikatorze modelu z odpowiedzi Identity Reply.
    static func matching(modelID: [UInt8]) -> ModuleProfile? {
        all.first { $0.modelID == modelID }
    }

    /// Dopasowanie po nazwie portu MIDI.
    static func matching(portName: String) -> ModuleProfile? {
        all.first { portName.localizedCaseInsensitiveContains($0.portKeyword) }
    }

    /// Dopasowanie po **wybranych** portach, z pierwszeństwem dla wyjścia.
    ///
    /// Liczy się port, na który naprawdę idą bajty, a nie pierwszy pasujący
    /// gdziekolwiek w systemie. Przy dwóch modułach na magistrali ta różnica
    /// decyduje o tym, czy program pisze tam, gdzie myśli.
    ///
    /// `nil` znaczy „nazwy nic nie mówią" — tak jest, gdy moduł siedzi za
    /// zwykłym interfejsem MIDI. Wtedy profil zostaje ten, który był.
    static func matching(
        outputName: String?,
        inputName: String?
    ) -> ModuleProfile? {
        if let outputName, let match = matching(portName: outputName) {
            return match
        }
        if let inputName, let match = matching(portName: inputName) {
            return match
        }
        return nil
    }
}

/// Strefy TD-27 w kolejności bloków w pamięci kitu.
///
/// Wobec TD-17 dochodzą trzy wejścia AUX zamiast jednego oraz obręcz przy
/// hi-hacie liczona osobno. **Kolejność wymaga potwierdzenia zrzutem
/// z modułu** — dopóki tego nie ma, te nazwy służą wyłącznie do opisania
/// tego, co widać na ekranie, i nic od nich nie zależy w adresowaniu.
enum TD27ZoneCatalog {
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
        "AUX1 HEAD", "AUX1 RIM",
        "AUX2 HEAD", "AUX2 RIM",
        "AUX3 HEAD", "AUX3 RIM"
    ]
}
