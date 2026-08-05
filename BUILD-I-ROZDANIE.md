# PulsoKit — zbudowanie wersji dla innych

Wersja bez podpisu Apple. Uruchomi się, ale przy pierwszym otwarciu macOS
pokaże ostrzeżenie — instrukcja dla odbiorcy jest w punkcie 4.

## 1. Zbuduj

1. Otwórz `PulsoKit.xcodeproj`.
2. Schemat **PulsoKit**, cel **My Mac**, konfiguracja **Release**:
   Product → Scheme → Edit Scheme → Run → Build Configuration → *Release*.
3. Product → **Archive**. Jeśli Archive jest wyszarzone, ustaw cel na
   „Any Mac" zamiast konkretnego urządzenia.
4. W oknie Organizer: **Distribute App** → **Custom** → **Copy App**.
   Wskaż katalog — dostaniesz w nim `PulsoKit.app`.

Jeśli Xcode marudzi o podpisywaniu: Signing & Capabilities → Team: *None*,
Signing Certificate: *Sign to Run Locally*. Do rozdania bez konta
deweloperskiego to wystarczy.

## 2. Podpisz ad-hoc — **bez tego macOS powie „uszkodzona"**

To nie jest opcjonalne. Na Apple Silicon procesor nie uruchomi binarki bez
żadnego podpisu, a Gatekeeper melduje to jako „aplikacja jest uszkodzona"
zamiast napisać, o co naprawdę chodzi.

W katalogu z `PulsoKit.app`:

```sh
codesign --force --deep --sign - PulsoKit.app
codesign -dv --verbose=4 PulsoKit.app    # sprawdzenie: ma pokazać Signature=adhoc
```

Podpis ad-hoc („na siebie") nie wymaga żadnego konta u Apple. Nie usuwa
ostrzeżenia przy pierwszym otwarciu, ale zamienia „uszkodzona" w normalne
„pochodzi od niezidentyfikowanego dewelopera", które da się kliknąć.

## 3. Spakuj

W Terminalu, w katalogu z `PulsoKit.app`:

```sh
ditto -c -k --sequesterRsrc --keepParent PulsoKit.app PulsoKit-0.95.zip
```

`ditto` zamiast zwykłego zipowania z Findera — zachowuje strukturę pakietu
aplikacji. Zwykły zip potrafi ją uszkodzić.

## 4. Co powiedzieć odbiorcy

> macOS zablokuje pierwsze uruchomienie, bo program nie jest notaryzowany
> u Apple. Rozpakuj, przenieś **PulsoKit** do katalogu Programy i spróbuj go
> otworzyć. Gdy system odmówi: **Ustawienia systemowe → Prywatność i ochrona**
> → na dole **„PulsoKit został zablokowany" → Otwórz mimo to**. Wystarczy raz.
>
> (Na macOS 14 i starszych działa też prawy przycisk → Otwórz. Od macOS 15
> Apple tę drogę zamknął, więc powyższa jest pewniejsza.)
>
> Jeśli wyskoczy **„aplikacja jest uszkodzona"**, prawie zawsze znaczy to, że
> plik pobrał się niekompletnie. Pobierz go jeszcze raz ze strony Wydań
> i porównaj sumę kontrolną:
>
> ```sh
> shasum -a 256 PulsoKit.zip
> ```
>
> **Nie uruchamiaj żadnych poleceń „naprawiających" w Terminalu.**

### Dlaczego zniknęło stąd `xattr -cr`

Ta instrukcja stała tu wcześniej i było to błędem. Trzy powody, od
najważniejszego:

**Uczy ludzi złego odruchu.** „Pobierz program z internetu, a potem wklej
w Terminal polecenie, którego nie rozumiesz, żeby ostrzeżenie zniknęło" —
to dokładnie ten sam scenariusz, który dołącza się do podrobionych
instalatorów. Działa właśnie dlatego, że uczciwi autorzy sami go publikują.
Kto raz to zrobił i nic złego się nie stało, zrobi to i następnym razem —
a następny plik może już nie być od Ciebie.

**Wyłącza więcej, niż się wydaje.** Skasowanie znacznika kwarantanny sprawia,
że Gatekeeper nie sprawdza pliku **w ogóle** — łącznie ze skanowaniem
antywirusowym XProtect przy pierwszym uruchomieniu. Droga przez Ustawienia
robi coś innego: pełne sprawdzenie się odbywa, a użytkownik świadomie
przechodzi ponad jego wynikiem. Dla czystego pliku efekt jest ten sam, ale
mechanizm zupełnie inny.

**Jest zbyt szerokie.** `-c` kasuje *wszystkie* atrybuty rozszerzone, `-r`
na każdym pliku w pakiecie.

Gdybyś kiedyś potrzebował furtki, wersja celowana to
`xattr -dr com.apple.quarantine /ścieżka/PulsoKit.app` — jeden nazwany atrybut,
jedna ścieżka. Ale prościej i lepiej: pobrać plik jeszcze raz.

## 4a. Jak odbiorca sprawdzi, że plik jest od Ciebie

Podpis ad-hoc **nie potwierdza autorstwa**. To skrót pliku bez klucza i bez
łańcucha zaufania — `codesign -dv` pokaże `Signature=adhoc` tak samo dla Twojej
aplikacji, jak dla podrobionej. Nie ma się na czym oprzeć.

Realne sprawdzenie daje poświadczenie pochodzenia, które GitHub wystawia przy
każdym wydaniu za darmo (konfiguracja jest już w `.github/workflows/build.yml`):

```sh
gh attestation verify PulsoKit.zip --repo arkus1972/PulsoKit
```

Dowodzi kryptograficznie, że plik powstał w tym repozytorium, w tym przebiegu
kompilacji, z tego commita.

**Najważniejsze zabezpieczenie tego wszystkiego leży jednak poza kodem:** Twoje
konto na GitHubie. Kto się na nie dostanie, podmieni plik pod adresem
`releases/latest/download/PulsoKit.zip` i nikt tego nie zauważy. Włącz
uwierzytelnianie dwuskładnikowe kluczem sprzętowym albo passkey — pięć minut,
a jest to pojedyncza rzecz o największym znaczeniu w całym rozdawaniu.

Do pracy potrzebny jest TD-17 podłączony kablem USB i włączony **przed**
uruchomieniem programu. Program sam odczyta kit wybrany na module.

## 5. Ikona

Ikona jest już w projekcie: `PulsoKit/Assets.xcassets/AppIcon.appiconset`,
komplet rozmiarów od 16 do 1024 punktów. Xcode wciąga ją automatycznie, bo
projekt używa synchronizowanych grup — nic nie trzeba dodawać ręcznie.

Sprawdź tylko raz, czy cel jej używa: zaznacz projekt → target **PulsoKit** →
zakładka **General** → **App Icon** ma wskazywać `AppIcon`. Gdyby pole było
puste, wybierz z listy.

Po zbudowaniu ikona pojawia się w Finderze, w Docku i w Launchpadzie. Jeśli
Finder uparcie pokazuje starą (albo pustą) — to jego pamięć podręczna:

```sh
touch PulsoKit.app
killall Finder
```

### Podmiana na własną grafikę

Potrzebny jest jeden kwadratowy PNG 1024×1024 z przezroczystym tłem.
W Terminalu, w katalogu z tym plikiem:

```sh
mkdir PulsoKit.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s   moja-ikona.png --out PulsoKit.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) moja-ikona.png --out PulsoKit.iconset/icon_${s}x${s}@2x.png
done
```

Potem przeciągnij powstałe pliki do `AppIcon` w Xcode, na odpowiadające
im pola. Uwaga: macOS **nie zaokrągla rogów sam** — grafika musi mieć
gotowy kształt zaokrąglonego kwadratu z marginesem dookoła, inaczej ikona
będzie ostrym kwadratem odstającym od reszty systemu.

## 6. Termin ważności — wyłączony

Program **nie wygasa**. Cały mechanizm został w `AppExpiry.swift`, ale jest
zgaszony jednym wyłącznikiem:

```swift
static let isEnabled = false
```

Gdybyś kiedyś chciał go przywrócić — zmieniasz na `true` i ustawiasz datę
w wierszu obok:

```swift
static let lastDay = DateComponents(year: 2026, month: 9, day: 29)
```

Wtedy na dwa tygodnie przed terminem pojawia się pasek z licznikiem dni,
a po terminie ekran z informacją o wygaśnięciu i ani jeden bajt na kabel.

## 7. Czego ta wersja NIE ma

- **Podpisu i notaryzacji Apple.** To wymaga konta deweloperskiego
  (99 USD rocznie). Bez tego każdy odbiorca przechodzi przez punkt 4.
- **Automatycznej aktualizacji.** Nowa wersja = nowy plik do rozdania.
- **Odporności na cofnięcie zegara.** Program pamięta najpóźniejszą widzianą
  datę, więc zwykłe cofnięcie zegara nie odblokuje wygasłej wersji, ale to
  nie jest zabezpieczenie przed kimś, kto chce je obejść.
