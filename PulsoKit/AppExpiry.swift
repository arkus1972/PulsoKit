import Foundation

/// Termin ważności wersji testowej.
///
/// Uczciwie: to zabezpieczenie przed **przypadkiem**, a nie przed kimś, kto
/// chce je obejść. Cofnięcie zegara systemowego jest wyłapywane (pamiętamy
/// najpóźniejszą widzianą datę), ale ktoś zdeterminowany i tak sobie poradzi.
/// Chodzi o to, żeby wersja rozdana znajomym sama się zamknęła, a nie o DRM.
@MainActor
enum AppExpiry {
    /// Ostatni dzień działania — koniec 29 września 2026 czasu lokalnego.
    static let lastDay = DateComponents(year: 2026, month: 9, day: 29)

    /// Klucz, pod którym pamiętamy najpóźniejszą widzianą datę.
    private static let seenKey = "pulsokit.lastSeenDate"

    /// Moment, w którym program przestaje działać.
    static var deadline: Date {
        var components = lastDay
        components.hour = 23
        components.minute = 59
        components.second = 59
        return Calendar.current.date(from: components) ?? .distantPast
    }

    /// Data, którą traktujemy jako „dziś".
    ///
    /// Bierzemy późniejszą z dwóch: zegara systemowego i najpóźniejszej daty,
    /// jaką program już widział. Dzięki temu cofnięcie zegara nie odblokowuje
    /// wygasłej wersji.
    /// Czysty odczyt — bez zapisu. Wywoływane z `body`, więc nie może mieć
    /// skutków ubocznych: zapis do `UserDefaults` przy każdym przeliczeniu
    /// widoku to setki zapisów na minutę.
    static var effectiveDate: Date {
        let seen = UserDefaults.standard.object(forKey: seenKey) as? Date
        return max(Date(), seen ?? .distantPast)
    }

    /// Zapamiętuje dzisiejszą datę. Wołane z zegara raz na minutę, a nie
    /// z rysowania widoku.
    static func stampToday() {
        let defaults = UserDefaults.standard
        let seen = defaults.object(forKey: seenKey) as? Date ?? .distantPast
        let now = Date()
        if now > seen {
            defaults.set(now, forKey: seenKey)
        }
    }

    static var hasExpired: Bool {
        effectiveDate > deadline
    }

    /// Ile dni zostało. Ujemne, gdy wersja już wygasła.
    static var daysLeft: Int {
        Calendar.current.dateComponents(
            [.day],
            from: effectiveDate,
            to: deadline
        ).day ?? 0
    }

    /// Czy warto już ostrzegać. Dwa tygodnie wystarczą, żeby zdążyć się
    /// odezwać po nowszą wersję.
    static var shouldWarn: Bool {
        !hasExpired && daysLeft <= 14
    }

    static var formattedDeadline: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_GB")
        return formatter.string(from: deadline)
    }
}
