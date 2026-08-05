# PulsoKit — audyt bezpieczeństwa

Wersja **v0.99**, sierpień 2026. Audyt objął cały program, wczytywanie plików
z zewnątrz, odbiór danych z modułu, ryzyko dla sprzętu, prywatność, publiczne
repozytorium, kompilację na GitHubie i sposób rozdawania programu.

Wszystko, co dało się poprawić bez sprzętu, jest już poprawione w tej wersji.
Dwie rzeczy zostawiłem świadomie — są opisane na końcu razem z powodami.

**Znalezisk krytycznych: brak.** Nie udało się doprowadzić do przejęcia
kontroli nad komputerem ani przez plik, ani przez MIDI. Znaleziska są
z kategorii „program ginie", „program cicho psuje dane" i „program okłamuje
użytkownika o stanie sprzętu". Ta ostatnia okazała się najpoważniejsza.

---

## Najważniejsze: pięć rzeczy, które mogły kosztować kogoś zestaw

### 1. Szybki zapis mógł zostawić kit nadpisany w połowie i nie powiedzieć o tym

Pętla „Fast write of the whole kit" wysyłała 105 bloków i **nie sprawdzała, czy
którykolwiek w ogóle zszedł na kabel**. Wyrwany w połowie kabel, wyłączony
moduł albo miniony termin ważności nie zatrzymywały jej: licznik dobiegał do
„105 z 105", a w module zostawał kit złożony z połowy nowej i połowy starej
zawartości. Ani stary, ani nowy. Program meldował potem tylko, że nie udał się
odczyt weryfikacyjny — o tym, że kit jest niekompletny, nie mówił nic, a ostrzeżenie
„nie wyłączaj modułu" też nie padało.

Teraz pętla przerywa się na pierwszym bloku, który nie wyszedł, i pisze wprost,
przy którym stanęła i że kit jest niekompletny.

### 2. Odruchowe naciśnięcie Enter nadpisywało cały kit

`NSAlert` robi z **pierwszego** dodanego przycisku przycisk domyślny,
z klawiszem Enter. W oknie potwierdzenia szybkiego zapisu pierwszy był „Fast
write", a Cancel drugi. Wystarczyło odruchowe Enter — albo spacja, jeśli
chwilę wcześniej pisało się w polu tekstowym — żeby nadpisać cały kit bez
możliwości cofnięcia.

Kolejność odwrócona. Do tego treść okna mówi teraz wprost, że operacji nie da
się cofnąć i że warto najpierw wyeksportować kit.

### 3. Przyciski „Restore" wchodziły w środek trwającego zapisu

Trzynaście przycisków przywracania z sekcji Backup sprawdzało tylko `isWriting`
— flagę, która między dwoma krokami serii z edytora opada na kilkadziesiąt
milisekund, a przez cały szybki zapis i przez trzydziestosekundowe ustawianie
się modułu jest opuszczona na stałe.

Kliknięcie w tym czasie wpuszczało drugi zapis w środek pierwszego: przestawiał
fazę weryfikacji, przez co odpowiedź na tamten pierwszy nie pasowała już do
niczego. Edytor meldował „moduł nie potwierdził" o zmianie, która **doszła** —
i porzucał resztę serii. Program i moduł rozjeżdżały się, a nie było jak
stwierdzić, która strona ma rację.

Teraz przyciski są wyłączone przez cały czas trwania jakiejkolwiek operacji,
a warunek w modelu pilnuje tego drugi raz, niezależnie od interfejsu.

### 4. Numer kitu z modułu szedł prosto do adresów zapisu, bez sprawdzenia

`currentKitNumber` brał się z bajtu przysłanego przez moduł i nie był
ograniczany. Numer 128 dawał adres `04 7E 00 00` — daleko za końcem obszaru
stu kitów, czyli w miejsce, o którym nie wiemy nic. Wszystkie kolejne zapisy
(nazwa, instrumenty, mikser, MFX, nuty) leciałyby właśnie tam.

Do wywołania wystarczyłaby przekłamana ramka z poprawną sumą kontrolną albo
drugi sprzęt Rolanda na tym samym porcie. Rzadkie — ale to dokładnie ten
scenariusz, którego się obawiałeś.

Teraz są dwie niezależne bariery: sprawdzenie `0…99` przy odczycie numeru
i zacisk w `kitAddress`, przez który przechodzi **każdy** adres zapisu do kitu.

### 5. Włączenie warstwy SUB zmieniało wartość, której nikt nie dotykał

Moduł trzyma Fade Point równy 0 dla warstw MIX i SWITCH, a zapis przyjmował
dopiero 1. Samo włączenie warstwy SUB na takim padzie podnosiło więc Fade Point
z 0 na 1 — wartość, która nie pojawiła się na liście zmian. A gdy moduł wracał
do zera, weryfikacja się nie zgadzała i **cała reszta serii szła do kosza**.

---

## Pliki z zewnątrz

Zagrożenie: ktoś podsyła plik `.TD0` albo kopię zapasową znalezioną na forum.

**Pamięciowo parser plików TD0 jest zrobiony dobrze** — sprawdziłem każdy stały
offset względem obu możliwych rozmiarów rdzenia i wszystkie są zabezpieczone.
Nie ma `try!`, nie ma wymuszonych rozpakowań na danych z pliku, nie ma
pułapkujących konwersji. Nie udało się doprowadzić do awarii.

Ale była luka innego rodzaju: **plik przechodził walidację sumy MD5 i nic poza
tym**. A MD5 w formacie TD0 sprawdza tylko, czy plik nie zepsuł się po drodze —
policzyć ją na spreparowanym pliku umie każdy. Program pokazywał więc zieloną
plakietkę „MD5 OK" nad wartościami, których moduł nigdy by nie wystawił, i
zachęcał do zapisania kopii, którą można wgrać komuś do TD-17. Doszło
sprawdzanie zakresów: typ warstwy, poziomy, wysyłki, wzmocnienia EQ, nuty MIDI.

Przy okazji poprawki, których nie było w zleceniu, a wyszły po drodze:

- **Program odrzucał własne pliki.** Pierwsza wersja walidacji była węższa niż
  to, co sam zapisuje — wystarczyło podnieść wysyłkę, zapisać kopię i otworzyć
  ją z powrotem, żeby dostać „Send level out of range". Zakresy przy wczytywaniu
  i przy zapisie są teraz zgodne co do jednego.
- **Zapis mógł trafić w plik, o który okno zapisu nie pytało.** Nazwa „.TD0"
  zostawiała pustą podstawę, a na dysku wrażliwym na wielkość liter „kit.td0"
  po cichu kasowało istniejące „kit.TD0" — bez pytania o nadpisanie.
- **Mapowanie pamięciowe pliku** trzymane przez całe życie okna: obcięcie pliku
  albo wypięcie pendrive'a w tym czasie zabija program sygnałem, którego
  w Swifcie nie da się przechwycić. Usunięte — przy limicie 64 MiB niczego nie
  oszczędzało.
- Migawki JSON: powtórzone numery stref w sekcjach V-Edit (dwadzieścia bloków
  pod jeden adres, a podsumowanie liczyło dwadzieścia stref), brak sprawdzania
  zakresów V-Edit przy szybkim zapisie, i napis „kompletne" nad przyciskiem
  nadpisującym kit, na który podgląd nie miał pokrycia.

---

## Odbiór MIDI

Zagrożenie: strumień bajtów z portu, który nie musi być TD-17. Wirtualny port
MIDI może na macOS utworzyć **dowolna aplikacja, bez żadnych uprawnień**.

**Składanie ramek SysEx jest zrobione porządnie** i to warto powiedzieć wprost:
fragmentacja między pakietami, `0xF0` w środku ramki, zabłąkany `0xF7`, bajty
czasu rzeczywistego wstrzyknięte w środek, ramka bez końca — wszystkie te
przypadki są obsłużone. Suma kontrolna jest liczona i egzekwowana. Adres
odpowiedzi jest porównywany z adresem, o który pytaliśmy. Nie znalazłem ani
jednego odczytu pod stały offset bez wcześniejszego sprawdzenia długości.

Poprawione:

- **Odczyt poza buforem pakietu.** Kod kopiował całą 256-bajtową krotkę `data`,
  podczas gdy pakiety leżą w liście ciasno jeden za drugim — dla ostatniego
  pakietu odczyt wychodził poza bufor od CoreMIDI. Przy okazji: pakiet dłuższy
  niż 256 bajtów gubił resztę po cichu.
- **Kolejka odbioru bez ograniczenia.** Źródło szybsze niż główny wątek mogło
  ją rozdmuchać aż do zabicia programu przez system. Teraz jest ograniczona.
- **Log bez ograniczenia.** Strumień samych bajtów `0xF0` generował jedną linię
  na bajt, a przycinanie następowało dopiero po przepisaniu wszystkiego.
- **Program podłączał się sam do pierwszego portu na liście.** Podłączone
  wejście może komunikatem Program Change przestawić numer bieżącego kitu —
  a z tego numeru liczą się adresy zapisów. Obce wejście potrafiło więc
  skierować Twoją edycję do zupełnie innego kitu w prawdziwym module. Teraz
  automat sięga po port bez pytania tylko wtedy, gdy jest dokładnie jeden,
  a Program Change jest honorowany dopiero po rozpoznaniu modułu.
- **Numer urządzenia** nie był sprawdzany. Program zapamiętuje teraz ten
  z pierwszej poprawnej odpowiedzi i dalej trzyma się jego.
- Burza powiadomień CoreMIDI mogła zapchać główny wątek — doszło opóźnienie.
- `MIDIPacketListAdd` zwracał błąd, którego nikt nie czytał: wiadomość, która
  nie zmieściła się w pakiecie, była raportowana jako wysłana.

---

## Prywatność

**Program nie łączy się z internetem. W ogóle.** Sprawdzone przez przeszukanie
kodu pod kątem wszystkich interfejsów sieciowych — nie ma ani analityki, ani
sprawdzania aktualizacji, ani zgłaszania awarii. Nie uruchamia też żadnych
procesów zewnętrznych i nie osadza przeglądarki.

Nie czyta żadnego pliku poza tym, który sam wskażesz w oknie otwierania. Zapisuje
dokładnie **jedną** wartość w ustawieniach systemowych: datę na potrzeby terminu
ważności.

Drobiazgi poprawione: nazwa konta w systemie znikła z nagłówków plików testowych
i z okien po zapisie pliku TD0, a nad przyciskiem „Copy log" jest teraz uwaga,
że log zawiera nazwy Twoich urządzeń MIDI (na wielu komputerach biorą się one
z nazwy samego komputera) i nazwy kitów.

---

## Repozytorium i kompilacja

**Nie ma wstrzykiwania do skryptów** — sprawdziłem wszystkie dziewięć miejsc,
gdzie workflow wstawia wartości do poleceń powłoki. Żadne nie pochodzi
z zewnątrz. Nazwa tagu idzie przez zmienną środowiskową, nie przez podstawienie
— czyli dokładnie tak, jak być powinno. Nie ma `pull_request_target`, a przy
publicznym repozytorium `push` nie uruchamia się dla kopii od obcych. Projekt
nie ma też żadnych skryptów budowania, więc podczas kompilacji nie wykonuje się
nic poza kompilatorem Swift.

W repozytorium nie ma żadnych kluczy, tokenów, haseł, adresów prywatnych ani
identyfikatorów zespołu deweloperskiego. Katalog `xcuserdata` jest skutecznie
wykluczony — sprawdziłem to na prawdziwym repozytorium, nie przez czytanie
wzorców. Obrazki nie mają metadanych.

Utwardzone: uprawnienia domyślnie tylko do odczytu (zapis dostaje wyłącznie krok
wystawiający Wydanie), `checkout` nie zostawia już tokenu w `.git/config` na
czas kompilacji, obie akcje przypięte do konkretnych commitów zamiast do
ruchomych tagów.

### Rozdawanie — tu było najwięcej do poprawienia

**Usunąłem z instrukcji `xattr -cr`.** To jest zmiana, na której zależy mi
najbardziej z całej tej listy. Nie dlatego, że polecenie jest groźne dla
Twojego pliku — dla czystego pliku efekt jest ten sam. Chodzi o odruch, którego
uczy: „pobierz program z internetu, a potem wklej w Terminal polecenie, którego
nie rozumiesz, żeby ostrzeżenie zniknęło". To jest dosłownie ten sam scenariusz,
który dołącza się do podrobionych instalatorów, i działa on właśnie dlatego, że
uczciwi autorzy sami go publikują. Kto raz to zrobił i nic złego się nie stało,
zrobi to i następnym razem — a następny plik może już nie być od Ciebie.

Dodatkowo: kasowanie znacznika kwarantanny wyłącza sprawdzanie pliku przez
Gatekeeper **w całości**, razem ze skanowaniem antywirusowym przy pierwszym
uruchomieniu. Droga przez Ustawienia systemowe robi co innego — pełne
sprawdzenie się odbywa, a użytkownik świadomie przechodzi ponad jego wynikiem.
Przy okazji: od macOS 15 Apple zamknął drogę „prawy przycisk → Otwórz", więc
instrukcja i tak wymagała poprawki.

**Odbiorca nie miał czym sprawdzić, że plik jest od Ciebie.** Podpis ad-hoc tego
nie dowodzi — to skrót pliku bez klucza i bez łańcucha zaufania, `codesign -dv`
pokaże `Signature=adhoc` tak samo dla podrobionej aplikacji. A repozytorium jest
publiczne, więc każdy może je skopiować i wystawić własną wersję z Twoim opisem
i Twoją ikoną.

Doszły dwie rzeczy: suma kontrolna obok pliku (broni przed pobraniem uciętym
w połowie — a to najczęstsza przyczyna komunikatu „aplikacja jest uszkodzona")
i **poświadczenie pochodzenia z GitHuba**, które dowodzi kryptograficznie, że
plik powstał z Twojego repozytorium, w tym przebiegu, z tego commita:

```sh
gh attestation verify PulsoKit.zip --repo arkus1972/PulsoKit
```

Do tego blok „Skąd pobierać" w README i w opisie każdego Wydania.

### Licencja

Nie było żadnej — a kod bez licencji to domyślnie „wszelkie prawa zastrzeżone",
czyli ludzie, którym rozdajesz program, formalnie nie mają prawa go uruchamiać.
Absurd przy Twoich intencjach.

Ważniejsze jest jednak drugie: **nie było nigdzie napisanego wyłączenia
gwarancji**, a program zapisuje do sprzętu wartego kilka tysięcy złotych.
Dodałem licencję MIT (jej ostatni akapit to dokładnie to wyłączenie) plus
zastrzeżenie po polsku w README, razem z informacją o braku związku z Rolandem.

W `LICENSE` stoi `Copyright (c) 2026 Arek` — zmień na to, czego chcesz używać
publicznie. To jest praktyczna informacja o zwyczajach w otwartym
oprogramowaniu, a nie porada prawna; nie jestem prawnikiem i prawo konsumenckie
w Polsce i UE ogranicza, jak daleko takie wyłączenie sięga.

---

## Czego świadomie NIE zrobiłem

### Piaskownica aplikacji — czeka gotowa, wymaga Twojego sprzętu

Program działa bez piaskownicy, czyli z pełnymi uprawnieniami konta
użytkownika: mógłby czytać klucze SSH, hasła do chmury, historię powłoki, i
zapisać się tak, żeby startował po każdym uruchomieniu komputera. Nie robi
żadnej z tych rzeczy — ale gdyby ktoś podstawił podrobioną wersję, nic by go
nie powstrzymało. To najpoważniejsza rzecz do poprawienia z całej listy.

Dobra wiadomość: **kod nie wymaga żadnych zmian**. Wszystkie sięgnięcia po
pliki idą już przez okna systemowe, a CoreMIDI działa w piaskownicy bez
dodatkowych uprawnień. Plik `PulsoKit/PulsoKit.entitlements` leży gotowy.

Nie włączyłem tego, bo jedynym ryzykiem jest to, że moduł przestanie być
widoczny — a tego nie sprawdzi ani kompilator, ani GitHub. Sprawdzić można
wyłącznie z podłączonym TD-17. Jesteś na urlopie; włączenie tego w ciemno
i wystawienie Wydania mogłoby zostawić wszystkich z aplikacją, która nie
widzi modułu.

Gdy wrócisz do perkusji, to jest cała robota: w Xcode zaznacz projekt → target
**PulsoKit** → **Build Settings** → wpisz `PulsoKit/PulsoKit.entitlements`
w polu **Code Signing Entitlements** (dla obu konfiguracji) i ustaw **Enable
Hardened Runtime** na `Yes`. Potem w `.github/workflows/build.yml` zamień
wiersz podpisywania na:

```sh
codesign --force --options runtime \
  --entitlements PulsoKit/PulsoKit.entitlements \
  --sign - "$APP"
```

Bez tej zmiany w workflow uprawnienia zostaną po cichu pominięte przy
kompilacji na GitHubie.

**Co przetestować po włączeniu:** czy moduł jest widoczny na liście portów, czy
odczyt kitu przechodzi, czy otwieranie i zapisywanie plików TD0 działa, czy
eksport i import kopii zapasowej działa. Jeśli cokolwiek z tego padnie, cofnij
pole Code Signing Entitlements i wróć do mnie z komunikatem.

### ~~Identyfikator pakietu~~ — zrobione

Było `Arek.PulsoKit`: Twoje imię w każdej zbudowanej aplikacji, i do tego nie
jest to poprawny identyfikator odwrotno-domenowy. Zmienione na
`io.github.arkus1972.pulsokit` (oraz `.tests` i `.uitests` dla celów testowych).

Skutek uboczny, o którym warto wiedzieć: aplikacja trafia teraz w inne miejsce
w ustawieniach systemowych, więc zapamiętana data terminu ważności liczy się od
nowa. Nikomu to nie przeszkadza, ale gdybyś testował wygasanie — to jest powód,
dla którego licznik się zresetował.

### ~~Zabezpieczenie czasowe~~ — wyłączone na życzenie

Program nie wygasa. Mechanizm został w `AppExpiry.swift` za wyłącznikiem
`isEnabled = false`; zmiana na `true` przywraca go.

Ocena, dla porządku, gdyby kiedyś wrócił: to był kurtuazyjny licznik i nic
więcej. Zapamiętanie najpóźniej widzianej daty broni przed zwykłym cofnięciem
zegara i przed niczym innym — skasowanie jednego wpisu w ustawieniach plus
przestawienie daty to dziesięć sekund bez żadnych narzędzi.

Sprawdziłem natomiast to, co naprawdę było ważne, jeszcze zanim padła decyzja
o wyłączeniu: czy sam mechanizm terminu nie może wysłać czegoś do modułu albo
urwać operacji w połowie. Nie może — wszystko wychodzące przechodzi przez jedno
miejsce, które sprawdza datę jako pierwszą rzecz. Jedyny problem był na styku
z szybkim zapisem i jest opisany w punkcie 1.

Efekt uboczny wyłączenia, na plus: program **nie zapisuje już niczego**
w ustawieniach systemowych. Wcześniej trzymał tam jedną datę.

---

## Co musisz zrobić sam

1. **Włącz uwierzytelnianie dwuskładnikowe kluczem sprzętowym albo passkey na
   koncie GitHub.** To jest pojedyncza rzecz o największym znaczeniu w całym
   rozdawaniu — Twoje konto jest korzeniem zaufania dla każdego pobrania. Kto
   się na nie dostanie, podmieni plik pod stałym adresem i nikt tego nie
   zauważy. Pięć minut.
2. **Podmień `arkus1972/PulsoKit`** w `README.md`, `JAK-WRZUCIC.md`,
   `BUILD-I-ROZDANIE.md` i w workflow. Podaj mi adres, to zrobię to za Ciebie.
3. **Wpisz w `LICENSE`** nazwę, której chcesz używać publicznie.
4. **Sprawdź pochodzenie `td17-kit.png`.** Jeśli to zdjęcie produktowe Rolanda,
   a nie Twój render, to na publicznym repozytorium jest to kwestia praw
   autorskich — jedyna rzecz w tym audycie, której nie potrafię rozstrzygnąć
   przez obejrzenie pliku.
5. **Pilnuj repozytorium strony z Ko-fi.** Adres przycisku wsparcia to jedna
   zmieniona litera od przekierowania na cudze konto. Czytaj każdą zmianę, choćby
   wyglądała niewinnie — to jest nawracający atak na projekty utrzymywane
   z darowizn.
6. **Po powrocie do modułu:** piaskownica (wyżej) i porównanie tabeli Triggers
   wartość po wartości z ekranem modułu.

---

## Co sprawdzono i jest w porządku

Żeby nie zostało wrażenie, że wszystko było źle — poniżej rzeczy, które
audytorzy próbowali złamać i się nie dało:

- **Ustawienia triggerów są naprawdę tylko do odczytu.** Prześledzone wszystkie
  22 miejsca wysyłania danych: dokładnie jedno wychodzi poza obszar kitów i jest
  to bajt numeru kitu, ograniczony do 1…100. Do obszaru kalibracji triggerów
  i do obszaru systemowego nie prowadzi żadna ścieżka zapisu.
- **Arytmetyka adresów wewnątrz kitu jest poprawna** — dodawanie w bazie 128
  działa na całej wartości, nie bajt po bajcie, więc błąd przeniesienia jest
  niemożliwy. Żaden offset podbloku nie może wyjść poza swój obszar.
- **Zaciskanie wartości w zwykłym zapisie jest kompletne** — sprawdzone wszystkie
  21 metod zapisujących, każda waliduje przed zakodowaniem. Jedyna dziura była
  w szybkim zapisie V-Edit i jest załatana.
- **Nie ma wyścigów danych.** Cały odbiór idzie przez jeden strumień
  konsumowany po kolei, klasa jest przypięta do głównego wątku, wątek czasu
  rzeczywistego CoreMIDI nie dotyka żadnego stanu.
- **Nic nie zapisuje się do modułu w trakcie edycji.** Żaden suwak, picker ani
  pole tekstowe niczego nie wysyła — wszystko czeka na liście zmian.
- **Walidacja importu migawek jest surowa i dobrze zrobiona**: dokładny zestaw
  kluczy, zakresy, sprawdzenie krzyżowe nazw instrumentów z katalogiem, limit
  rozmiaru pliku, limit zagnieżdżenia JSON, drugie potwierdzenie przy migawce
  z innego kitu.

---

## Jedna rzecz do obserwacji przy pierwszej kompilacji

W `MIDIManager.swift`, w funkcji składającej bajty z pakietów MIDI, jest linia
sięgająca po przesunięcie pola `data` w strukturze `MIDIPacket`. Jest tam
gałąź awaryjna, więc program nie zginie, ale gdyby kompilator na GitHubie
zaprotestował — to jest ta jedna linia, którą warto mi pokazać. Reszta zmian
używa wyłącznie konstrukcji, których jestem pewien.
