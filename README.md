# PulsoKit

Edytor zestawów perkusyjnych do modułu **Roland TD-17**, na macOS.

Czyta i zapisuje ustawienia kitu przez MIDI SysEx, otwiera i zapisuje pliki
`.TD0`, pokazuje ustawienia triggerów i pozwala odsłuchać zmiany, zanim
trafią na stałe do modułu. Przy odsłuchu widać na scenie, który pad właśnie
zabrzmiał — przydatne na słuchawkach, gdzie dźwięk słychać, ale nie wiadomo,
skąd wyszedł.

Wymagania: macOS 14 lub nowszy, TD-17 podłączony kablem USB i **włączony przed**
uruchomieniem programu.

**TD-27** jest rozpoznawany, ale na razie wyłącznie do odczytu — układ pamięci
kitu nie jest jeszcze potwierdzony na żywym sprzęcie. Jeśli masz TD-27 i chcesz
pomóc: [`TD27.md`](TD27.md).

## Skąd pobierać

Jedyne oficjalne miejsce:

```
https://github.com/arkus1972/PulsoKit/releases
```

Nie pobieraj PulsoKita spod żadnego innego adresu. Repozytorium jest publiczne,
więc każdy może je skopiować i wystawić własną wersję z moim opisem i moją
ikoną — jeśli ktoś podeśle Ci plik z innego źródła, nie jest ode mnie.

Program **nie łączy się z internetem**, nie zbiera żadnych danych i nie czyta
żadnych plików poza tymi, które sam wskażesz w oknie otwierania. Nie zapisuje
też niczego poza plikami, o które go wprost poprosisz — żadnych ustawień,
żadnych śladów.

Do każdego wydania dołączona jest suma kontrolna `PulsoKit.zip.sha256`
i poświadczenie pochodzenia z GitHuba. Jak je sprawdzić — niżej.

## Skąd wziąć gotowy program

Nie trzeba mieć Xcode — kompilacja idzie na GitHubie.

**Dla wszystkich:** zakładka **Releases**, plik `PulsoKit.zip`. Stały adres,
zawsze najnowsze wydanie, działa bez konta na GitHubie:

```
https://github.com/arkus1972/PulsoKit/releases/latest/download/PulsoKit.zip
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

### Pierwsze uruchomienie

Program nie jest notaryzowany u Apple, więc macOS zablokuje pierwsze
uruchomienie. Wtedy: **Ustawienia systemowe → Prywatność i ochrona** → na dole
**„PulsoKit został zablokowany" → Otwórz mimo to**. Wystarczy raz.

Na starszych systemach działa też **prawy przycisk → Otwórz**, ale od macOS 15
Apple tę drogę zamknął.

Cała procedura i co powiedzieć odbiorcy: [`BUILD-I-ROZDANIE.md`](BUILD-I-ROZDANIE.md).

Binarka jest uniwersalna — chodzi i na Apple Silicon, i na Intelu.

### Jak sprawdzić, że plik jest ode mnie

Podpis ad-hoc, który nosi ta aplikacja, **nie potwierdza autorstwa** — taki
podpis potrafi zrobić każdy, na dowolnym pliku. Realne sprawdzenie jest jedno,
i wymaga narzędzia `gh` (`brew install gh`):

```sh
gh attestation verify PulsoKit.zip --repo arkus1972/PulsoKit
```

To dowodzi kryptograficznie, że plik powstał z tego repozytorium, w tym
przebiegu kompilacji, z tego commita.

Suma kontrolna sprawdza mniej — tylko czy plik pobrał się w całości:

```sh
shasum -a 256 PulsoKit.zip
```

Wynik ma się zgadzać z zawartością `PulsoKit.zip.sha256` z tego samego wydania.

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
| `AppExpiry.swift` | termin ważności (wyłączony) |
| `ModuleProfile.swift` | co jest inne w każdym module: adresy, strefy, model ID |

Instrukcja obsługi: [po polsku](PulsoKit-instrukcja.pdf) ·
[in English](PulsoKit-manual.pdf).

Pełna historia zmian: [`ZMIANY.md`](ZMIANY.md).

## Termin ważności

**Wyłączony — program nie przestaje działać.**

Mechanizm został w kodzie, za jednym wyłącznikiem w `AppExpiry.swift`:

```swift
static let isEnabled = false
```

Zmiana na `true` przywraca wygasanie w dniu ustawionym obok, w `lastDay`.
Przy `false` program nie wygasa, nie ostrzega i nie zapisuje daty w ustawieniach
systemowych.

## Licencja

MIT — patrz [`LICENSE`](LICENSE). Rób z tym, co chcesz.

## Zastrzeżenie

PulsoKit zapisuje dane do pamięci Twojego modułu TD-17. Staram się, żeby działał
poprawnie, ale jest to darmowy program pisany po godzinach — może zawierać błędy
i **nie daję na niego żadnej gwarancji**.

**Zanim zaczniesz cokolwiek zmieniać, zrób kopię zestawów** — sekcja **Backup**.
Szczególnie przed „Fast write of the whole kit": ta operacja nadpisuje cały kit
i nie da się jej cofnąć.

Używasz programu na własne ryzyko i odpowiedzialność; nie odpowiadam za utratę
ustawień ani za jakiekolwiek szkody powstałe w związku z jego użyciem.

Roland i TD-17 to znaki towarowe Roland Corporation. Ten projekt nie jest
z Rolandem w żaden sposób związany, nie jest przez niego wspierany ani
autoryzowany.
