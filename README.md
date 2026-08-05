# PulsoKit

Edytor zestawów perkusyjnych do modułu **Roland TD-17**, na macOS.

Czyta i zapisuje ustawienia kitu przez MIDI SysEx, otwiera i zapisuje pliki
`.TD0`, pokazuje ustawienia triggerów i pozwala odsłuchać zmiany, zanim
trafią na stałe do modułu.

Wymagania: macOS 14 lub nowszy, TD-17 podłączony kablem USB i **włączony przed**
uruchomieniem programu.

## Skąd wziąć gotowy program

Nie trzeba mieć Xcode — kompilacja idzie na GitHubie.

**Dla wszystkich:** zakładka **Releases**, plik `PulsoKit.zip`. Stały adres,
zawsze najnowsze wydanie, działa bez konta na GitHubie:

```
https://github.com/UŻYTKOWNIK/REPO/releases/latest/download/PulsoKit.zip
```

**Dla siebie, między wydaniami:** każdy push zostawia zbudowaną aplikację
w zakładce **Actions** → najnowszy przebieg → sekcja **Artifacts** →
`PulsoKit-v0.xx-…`. Uwaga: artefakty pobierze tylko ktoś zalogowany na
GitHubie, więc do rozdawania nadają się wyłącznie Wydania.

Potem rozpakuj i przenieś **PulsoKit** do katalogu Programy.

### Jak zrobić wydanie

```sh
git tag v0.99 && git push origin v0.99
```

Reszta dzieje się sama: kompilacja, podpis, spakowanie i wystawienie Wydania
z plikiem do pobrania.

Aplikacja jest podpisana ad-hoc, ale nie notaryzowana u Apple — przy pierwszym
otwarciu trzeba raz kliknąć **prawym przyciskiem → Otwórz**. Cała procedura
i co powiedzieć odbiorcy: [`BUILD-I-ROZDANIE.md`](BUILD-I-ROZDANIE.md).

Binarka jest uniwersalna — chodzi i na Apple Silicon, i na Intelu.

## Gdy kompilacja się nie uda

Nie trzeba grzebać w logach. Wejdź w nieudany przebieg w **Actions** —
na samej górze strony jest podsumowanie z listą błędów, gotowe do skopiowania.
Pełny log kompilacji wisi obok jako artefakt `build-log-…`.

## Budowanie u siebie

```sh
xcodebuild -project PulsoKit.xcodeproj -scheme PulsoKit -configuration Release build
```

Albo po prostu otwórz `PulsoKit.xcodeproj` w Xcode. Schemat **PulsoKit** jest
współdzielony, więc jest od razu widoczny.

## Co siedzi w kodzie

| Plik | Za co odpowiada |
|---|---|
| `MIDIManager.swift` | CoreMIDI, SysEx, odczyt i zapis modułu, odsłuch |
| `KitEditor.swift` | model edycji: lista zmian, cofanie, wysyłka, próba przed zapisem |
| `KitScreen.swift` | główny ekran edytora |
| `TD17KitStage.swift` | scena z padami |
| `TD17InstrumentCatalog.swift` | katalog brzmień TD-17 |
| `TD0EditorModel.swift`, `TD0StudioView.swift` | obsługa plików `.TD0` |
| `TriggersScreen.swift` | ustawienia triggerów (na razie tylko odczyt) |
| `AppExpiry.swift` | termin ważności wersji testowej |

Pełna historia zmian: [`ZMIANY.md`](ZMIANY.md).

## Termin ważności

Ta wersja przestaje działać **29 września 2026**. Data siedzi w jednym miejscu,
w `AppExpiry.swift`.

## Zastrzeżenie

Program pisze do pamięci modułu. Przed pierwszymi eksperymentami zrób kopię
zestawów — sekcja **Backup**. Roland nie ma z tym projektem nic wspólnego.
