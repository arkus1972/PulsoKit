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

> macOS zablokuje pierwsze uruchomienie, bo program nie jest podpisany
> u Apple. Rozpakuj, przenieś **PulsoKit** do katalogu Programy, potem
> **kliknij prawym przyciskiem → Otwórz** i w okienku jeszcze raz **Otwórz**.
> Wystarczy raz — kolejne uruchomienia idą normalnie.
>
> Jeśli system pokaże „nie można sprawdzić, czy nie zawiera złośliwego
> oprogramowania" i nie da przycisku Otwórz: Ustawienia systemowe →
> Prywatność i ochrona → na dole „PulsoKit został zablokowany" → **Otwórz
> mimo to**.
>
> A jeśli mimo wszystko wyskoczy **„aplikacja jest uszkodzona"** — to znaczy,
> że plik przeszedł przez internet i dostał znacznik kwarantanny. Wtedy raz,
> w Terminalu:
>
> ```sh
> xattr -cr /Applications/PulsoKit.app
> ```

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

## 6. Termin ważności

Ta wersja przestaje działać **29 września 2026**. Na dwa tygodnie przed
terminem pokazuje pasek z licznikiem dni, po terminie — ekran z informacją
o wygaśnięciu i nic więcej. Termin siedzi w `AppExpiry.swift`, w jednym
miejscu:

```swift
static let lastDay = DateComponents(year: 2026, month: 9, day: 29)
```

## 7. Czego ta wersja NIE ma

- **Podpisu i notaryzacji Apple.** To wymaga konta deweloperskiego
  (99 USD rocznie). Bez tego każdy odbiorca przechodzi przez punkt 4.
- **Automatycznej aktualizacji.** Nowa wersja = nowy plik do rozdania.
- **Odporności na cofnięcie zegara.** Program pamięta najpóźniejszą widzianą
  datę, więc zwykłe cofnięcie zegara nie odblokuje wygasłej wersji, ale to
  nie jest zabezpieczenie przed kimś, kto chce je obejść.
