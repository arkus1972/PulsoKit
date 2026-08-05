import Foundation

/// Znaczenie trzech parametrów V-Edit zależy od rodziny instrumentu.
///
/// TD-17 wystawia pod tymi samymi adresami zupełnie różne rzeczy: dla werbla
/// jest to strojenie, tłumienie i sprężyna, dla talerza rozmiar i taśma, dla
/// hi-hatu tryb pracy. Bez tłumaczenia interfejs pokazywałby trzy bezimienne
/// liczby.
///
/// Wcześniej ta wiedza siedziała rozsypana po prywatnych funkcjach ekranu
/// V-Edit. Tutaj jest jednym miejscem, z którego korzysta inspektor strefy.
struct TD17VEditStyle {
    /// Nazwa rodziny z bloku V-Edit: KICK, SNARE, TOM, HI-HAT, RIDE, CRASH,
    /// SPLASH/CHINA, CROSS STICK.
    let group: String

    var supportsTuning: Bool {
        ["KICK", "SNARE", "CROSS STICK", "TOM"].contains(group)
    }

    var isCymbal: Bool {
        ["HI-HAT", "RIDE", "CRASH", "SPLASH/CHINA"].contains(group)
    }

    // MARK: Parametr 1

    var primaryLabel: String {
        if supportsTuning { return "Tuning" }
        if isCymbal { return "Size" }
        return "Pitch"
    }

    var primaryRange: ClosedRange<Int> {
        supportsTuning ? -100...100 : (isCymbal ? 0...78 : -4800...4800)
    }

    func primaryText(_ value: Int) -> String {
        if supportsTuning { return "\(value > 0 ? "+" : "")\(value)" }
        if isCymbal { return String(format: "%.1f\"", 1.0 + Double(value) / 2.0) }
        return "\(value) cent"
    }

    // MARK: Parametr 2

    var secondaryLabel: String {
        if group == "HI-HAT" { return "Fixed" }
        if supportsTuning || isCymbal { return "Muffling" }
        return "Decay"
    }

    var secondaryRange: ClosedRange<Int> {
        switch group {
        case "HI-HAT": 0...4
        case "RIDE", "CRASH", "SPLASH/CHINA": 0...19
        case "KICK", "SNARE", "CROSS STICK", "TOM": 0...9
        default: 1...100
        }
    }

    /// Nazwy pozycji parametru 2. Pusta tablica oznacza zwykłą liczbę.
    var secondaryNames: [String] {
        switch group {
        case "KICK":
            [
                "OFF", "TAPE1", "TAPE2", "TAPE3", "TAPE4",
                "BLANKET1", "BLANKET2", "BLANKET3", "WEIGHT1", "WEIGHT2"
            ]
        case "SNARE", "CROSS STICK":
            [
                "OFF", "TAPE1", "TAPE2", "TAPE3", "TAPE4",
                "TAPE5", "TAPE6", "TAPE7", "DONUT1", "DONUT2"
            ]
        case "TOM":
            [
                "OFF", "TAPE1", "TAPE2", "TAPE3", "TAPE4",
                "TAPE5", "FELT1", "FELT2", "FELT3", "FELT4"
            ]
        case "HI-HAT":
            ["NORMAL", "FIXED1", "FIXED2", "FIXED3", "FIXED4"]
        case "RIDE", "CRASH", "SPLASH/CHINA":
            (0...19).map { $0 == 0 ? "OFF" : "TAPE\($0)" }
        default:
            []
        }
    }

    func secondaryText(_ value: Int) -> String {
        let names = secondaryNames
        return names.indices.contains(value) ? names[value] : "\(value)"
    }

    // MARK: Parametr 3

    var hasTertiary: Bool {
        ["KICK", "SNARE", "TOM"].contains(group)
    }

    var tertiaryLabel: String {
        group == "SNARE" ? "Strainer" : "Snare buzz"
    }

    var tertiaryRange: ClosedRange<Int> { 0...8 }

    var tertiaryNames: [String] {
        group == "SNARE"
            ? [
                "LOOSE1", "LOOSE2", "LOOSE3",
                "MEDIUM1", "MEDIUM2", "MEDIUM3",
                "TIGHT1", "TIGHT2", "TIGHT3"
            ]
            : []
    }

    func tertiaryText(_ value: Int) -> String {
        let names = tertiaryNames
        if names.indices.contains(value) { return names[value] }
        return value == 0 ? "OFF" : "\(value)"
    }
}

/// Które nuty MIDI należą do której strefy.
///
/// Bloki nut i bloki stref nie mają wspólnej numeracji: nut jest 24, stref 20.
/// Werbel ma dodatkowo cross stick, hi-hat rozpada się na otwarty i zamknięty
/// bow/edge oraz pedał. Bez tej tablicy przypisania nut nie dałoby się pokazać
/// przy padzie, którego dotyczą.
enum TD17NoteMap {
    static func noteIndices(forZone zoneIndex: Int) -> [Int] {
        switch zoneIndex {
        case 0: [0]
        case 1: [1]
        // Cross stick gra się w obręcz, więc siedzi przy obręczy werbla.
        case 2: [2, 3]
        case 3: [4]
        case 4: [5]
        case 5: [6]
        case 6: [7]
        case 7: [8]
        case 8: [9]
        case 9: [10, 12, 14]
        case 10: [11, 13]
        case 11: [15]
        case 12: [16]
        case 13: [17]
        case 14: [18]
        case 15: [19]
        case 16: [20]
        case 17: [21]
        case 18: [22]
        case 19: [23]
        default: []
        }
    }
}
