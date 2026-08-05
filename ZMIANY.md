# PulsoKit v0.74 — poprawki krytyczne

Wersja naprawcza. Bez nowych funkcji — sześć błędów, które mogły zawiesić
aplikację, uszkodzić dane w module albo w pliku TD0.

Zmienione pliki: `MIDIManager.swift`, `TD0EditorModel.swift`, `ContentView.swift`.

---

## 1. Trwałe zablokowanie aplikacji po nieudanym zapisie

**Było:** `isWriting` ustawiane w 21 metodach `write*`, kasowane wyłącznie po
otrzymaniu odpowiedzi weryfikacyjnej. Brak odpowiedzi — odpięty kabel, zgubiony
pakiet, zmiana kitu w trakcie zapisu — zostawiał flagę ustawioną na stałe.
`isOperationInProgress` blokowało wtedy każdą kolejną operację, łącznie
z ponownym odczytem kitu, który jako jedyny potrafił tę flagę skasować.
Ratunkiem był restart aplikacji.

**Jest:** obserwator `didSet` na `isWriting` uruchamia watchdog z licznikiem
generacji. Po 8 sekundach bez potwierdzenia zapis jest przerywany:
flaga kasowana, `readPhase` wraca do `.idle`, użytkownik dostaje komunikat
z nazwą fazy, która nie doszła do skutku. Trwające przywracanie wsadowe też
jest przerywane, zamiast po cichu lecieć dalej.

Limit 8 s jest krótszy niż 10-sekundowy polling w `runNextBatchRestoreAction`,
żeby to watchdog decydował o przerwaniu.

## 2. Odczyt śmieci ze stosu przy wielu pakietach MIDI

**Było:** `bytes(from:)` kopiowało pierwszy `MIDIPacket` na stos i wołało
`MIDIPacketNext(&packet)` na tej kopii. Adres kolejnego pakietu był więc
liczony względem zmiennej lokalnej, a nie oryginalnej listy. Działało
wyłącznie przy `numPackets == 1`; przy dwóch i więcej pakietach — czyli
zawsze, gdy moduł wysyłał równolegle nuty albo zegar — druga iteracja
czytała niezainicjalizowaną pamięć stosu.

**Jest:** iteracja przez `packetList.unsafeSequence()`, które przechodzi po
oryginalnej liście.

## 3. Bajty Real-Time psujące ramki SysEx

**Było:** po napotkaniu `0xF0` każdy kolejny bajt trafiał do bufora, łącznie
z System Real-Time (`0xF8` zegar, `0xFE` Active Sensing, `0xFF` reset).
Standard MIDI pozwala wysłać je w środku ramki SysEx, a TD-17 to robi.
Taki bajt trafiał do payloadu, suma kontrolna przestawała się zgadzać, pakiet
był odrzucany — a że maszyna stanów odczytu rusza dalej dopiero po pasującej
odpowiedzi, jeden `0xFE` zatrzymywał cały odczyt kitu aż do watchdoga 60 s.
Bufor nie miał też górnego limitu: urwana ramka rosła aż do następnego `0xF0`.

**Jest:** bajty `0xF8`–`0xFF` są pomijane przed trafieniem do bufora.
Inny bajt statusu przerywa ramkę i wraca do obsługi kanałowej. Bufor ma limit
4 kB. Porzucone ramki są logowane, zamiast znikać bez śladu.

Obsługa Program Change (w tym running status) zachowuje się identycznie
jak wcześniej — została tylko wydzielona do `handleChannelByte`.

## 4. Szybki zapis kasował nieznane dane V-Edit

**Było:** blok `KitUnitVEdit` ma 33 bajty (`0x21`), z czego program rozumie
12 (parametry 1–3, bajty 1–12). Szybki zapis snapshotu wysyłał mimo to pełne
33 bajty, wypełniając bajt 0 i bajty 13–32 zerami — dla wszystkich 20 stref
MAIN i każdej aktywnej SUB. Cokolwiek moduł tam trzymał, było kasowane
bezpowrotnie przy każdym szybkim zapisie, a weryfikacja tego nie wykrywała,
bo porównuje wyłącznie trzy znane parametry.

**Jest:** zapisywany jest wyłącznie znany fragment — adres przesunięty o 1
i 12 bajtów danych. Dokładnie ten sam adres i format, którego używa
pojedynczy zapis `writeVEditTuning` / `writeVEditParameter`. Nieznany obszar
pozostaje nietknięty.

## 5. Crash przy szybkim zapisie edytowanego snapshotu

**Było:** `makeFastSnapshotBlocks` przepuszczało wartości z JSON-a przez
pułapkujące inicjalizatory `UInt8()`, `UInt16()`, `Int16()`. `validateSnapshot`
nie sprawdzało zakresów V-Edit, miksera, ambience, reverbu, MFX, kompresora
ani nut. Snapshot z ujemnym `secondary` albo `roomShape` równym 500 przechodził
walidację przy imporcie i zabijał proces w momencie kliknięcia szybkiego zapisu.

**Jest:** komplet metod `checkedByte` / `checkedSigned16` / `checkedUnsigned16`
/ `checkedSignedByte`, które rzucają `SnapshotError` z nazwą pola, wartością
i oczekiwanym zakresem. Zakresy wyciągnięte do dziewięciu stałych na
`MIDIManager` i uzgodnione z tym, co akceptują pojedyncze metody `write*`.

Wyjątek: Fade Point ma dwa zakresy. `fadePointEditRange` (1–127) dla wartości
wpisywanej przez użytkownika i `fadePointStorageRange` (0–127) dla danych
odczytanych z modułu — parametr dotyczy tylko warstw FADE1/FADE2, więc przy
MIX i SWITCH moduł zwraca 0 i użycie węższego zakresu blokowałoby szybki zapis
całego snapshotu.

## 6. Błędy zakresów w plikach TD0

**Nuta OFF.** `writeEditedValues` przycinało numery nut do `0...127`, podczas
gdy 128 oznacza OFF. Każdy wyłączony pad po eksporcie stawał się nutą 127.
Teraz zakres to `0...128`, a stepper w interfejsie pokazuje dla 128 napis „OFF".

**Balans hi-hat.** W grze były trzy różne zakresy tego samego parametru:
zapis pliku przycinał do `-100...100`, interfejs oferował `-100...100`,
a ścieżka SysEx wymagała `-64...63`. Zapis pliku obcinał więc wartości
wczytane z pliku, których użytkownik w ogóle nie dotknął. Teraz interfejs
używa zakresu modułu, a zapis przepisuje wartość bez straty.

> Do potwierdzenia na sprzęcie: rzeczywista skala tego pola w pliku TD0.
> Pole ma 16 bitów, a w mapie SysEx jest to bajt ze znakiem.

---

## Czego ta wersja nie zmienia

Świadomie nie ruszane, żeby zmiany dało się zweryfikować pojedynczo:

- martwy kod (`td0Tab` i jego pomocnicy, `TD0ZoneEditorCard`, `infoGroup`,
  `snareHead` / `snareRim`) — ok. 370 linii nieosiągalnego UI
- `runModal()` blokujący główny wątek, przez który idzie cały odbiór MIDI
- `log` rosnący bez ograniczeń
- brak gwarancji kolejności przy przeskoku odbioru na `@MainActor`
- porównywanie `vEditSub` po pozycji w tablicy, mimo że zawiera tylko
  aktywne warstwy SUB
- braki funkcjonalne: przełączanie kitów z aplikacji, „wyślij wszystko",
  undo/redo, kopiuj/wklej między strefami, audycja padów, wyszukiwarka
  instrumentów

## Uwaga o weryfikacji

Zmiany były sprawdzane przez czytanie kodu, nie przez kompilator — w tym
środowisku nie ma Xcode. Zbuduj w Xcode i zgłoś, co się wysypało.

---

# PulsoKit v0.75 — poprawka znaleziona przez test

## Poziom główny efektów miał za wąski zakres

**Znalezione:** w logu pełnego odczytu z modułu:

```
REVERB: OFF, HALL1, ..., Level +0.1 dB
```

Moduł zwraca **dodatni** poziom Reverbu (wartość 1). Tymczasem cała ścieżka
SysEx sprawdzała poziomy Ambience, Reverbu i MFX zakresem `-601…0`.

**Dlaczego to było groźne dopiero teraz:** w v0.73 kontrola zakresu w szybkim
zapisie w ogóle nie istniała — wartość leciała do modułu bez pytania.
Walidacja dodana w v0.74 zaczęła te dane **odrzucać**: szybki zapis snapshotu
tego kitu przerywałby się komunikatem „Reverb Level: wartość 1 poza zakresem
-601…0", a przywracanie pojedynczego poziomu po cichu nic by nie robiło.

**Jest:** nowa stała `effectLevelRange` (-601…60) — ta sama skala, co
pozostałe poziomy w urządzeniu i ta, której od początku używała ścieżka
plików TD0. Zastosowana w: `writeAmbienceLevel`, `writeReverb`, `writeMFX`,
trzech ścieżkach przywracania ze snapshotu, ścieżce szybkiego zapisu
i trzech stepperach w interfejsie.

Wysyłki efektów per strefa (`sendLevelRange`) zostają przy `-601…0` — te
faktycznie tylko tłumią.

Przy okazji: wszystkie literały `-601...0` zniknęły z kodu na rzecz dwóch
nazwanych stałych, więc rozjazd nie powtórzy się przy kolejnej edycji.

## Obserwacja z logu — nieznany obszar V-Edit

W odczytanym kicie **wszystkie bajty 13–32 każdego bloku V-Edit są zerowe**,
podobnie bajt 0. To znaczy, że dla tego kitu poprawka z v0.74 (zaprzestanie
zerowania nieznanego obszaru) nie zmieni obserwowalnego wyniku — stare
zachowanie wpisywało zera tam, gdzie i tak były zera.

Poprawka zostaje, bo zapisywanie bajtów, których program nie rozumie, jest
błędem niezależnie od tego, czy akurat coś w nich siedzi. Ale test 4 na tym
kicie nie jest w stanie tego potwierdzić ani obalić.

---

# PulsoKit v0.76 — dlaczego odczyt kitu był wolny

## Diagnoza

Test „pełny odczyt przy graniu na padach" wykonany pięć razy pod rząd
przerwał się na czwartym i piątym przebiegu komunikatem o przekroczeniu
60 sekund. Ale w logu **nie było ani jednej błędnej sumy kontrolnej** —
filtr bajtów Real-Time z v0.74 działał poprawnie.

Winna była zakładka Log.

`log` było jednym `@Published String`, sklejanym przez `log += …`.
Widok renderował całość jako pojedynczy `Text` z włączonym zaznaczaniem.
Pełny odczyt kitu dopisuje ponad 200 linii, więc każdy odczyt to 200 ×
(kopia całego tekstu + unieważnienie widoku + ponowne rozmierzenie całego
bloku tekstu). Log nie był czyszczony między przebiegami, więc rósł —
i koszt rósł kwadratowo. Przy piątym przebiegu odczyt nie mieścił się
w limicie mimo że szedł do przodu.

To nie było spowolnienie MIDI. To było spowolnienie rysowania.

## Poprawki

**Log jako lista linii z buforowaniem.** `logLines: [TD17LogLine]` zamiast
jednego `String`. Dopiski trafiają do bufora i są zrzucane zbiorczo co
150 ms, więc burst 200 linii daje kilka odświeżeń widoku zamiast dwustu.
Limit 3000 linii, starsze odpadają. Widok używa `LazyVStack`, więc składa
tylko widoczne wiersze. Linie mają trwałe identyfikatory, żeby obcięcie
bufora nie przenumerowywało całej listy. Doszedł przycisk **Kopiuj log**,
bo zaznaczanie w poprzek wielu wierszy przestało być możliwe.

**Watchdog odczytu liczy bezczynność, nie łączny czas.** Sztywny limit 60 s
na cały odczyt przerywał operację, która szła do przodu, tylko wolno.
Teraz liczy się, czy przez 12 sekund nie zmieniła się faza — czyli czy
odczyt naprawdę stanął.

**Odbiór MIDI w jednym uporządkowanym strumieniu.** Każdy callback CoreMIDI
tworzył wcześniej osobne `Task`. Swift nie gwarantuje kolejności wykonania
niezależnych zadań, a odbiór SysEx składa ramkę bajt po bajcie — zamiana
dwóch porcji miejscami cicho psuła dane. Teraz wszystko idzie przez jeden
`AsyncStream`, konsumowany po kolei.

**Porównywanie stref po numerze, nie po pozycji.** Odczyt pokazał, że
`vEditSub` zawiera tylko strefy z aktywną warstwą SUB — w testowym kicie
7 z 20. Porównanie snapshotu z modułem zestawiało te listy po pozycji
w tablicy, więc przy różnym zestawie aktywnych SUB-ów zestawiało ze sobą
dwa różne pady: pokazywało różnice, których nie ma, i pozwalało przywrócić
wartość do złej strefy. Teraz obie listy są zestawiane po `zoneIndex`,
a strefy występujące tylko po jednej stronie są raportowane osobno.

**Natychmiastowe przerwanie zapisu, gdy wysyłka nie doszła do skutku.**
Widoczne w teście watchdoga: po odpięciu kabla `sendDT1` nie wysłał nic
(„Nie wybrano wyjścia MIDI"), a program i tak czekał 8 sekund na
odpowiedź na pytanie, którego nikt nie zadał. Teraz przerywa od razu
z osobnym komunikatem.

**Kontrola spójności w przywracaniu instrumentu.** `restoreSnapshotInstrument`
jako jedyne z sześciu przywracań nie sprawdzało, czy pozycja w tablicy
snapshotu opisuje tę strefę, za którą się podaje. Dopisane.

## Co sprawdzić w tej wersji

1. Zakładka Log → **Wyczyść log**. Potem pięć pełnych odczytów pod rząd,
   z graniem na padach, **bez czyszczenia logu między nimi**. Wszystkie
   powinny się skończyć, a licznik linii zatrzymać na 3000.
2. Odczyt przy otwartej zakładce Log — wcześniej to był najgorszy przypadek.
3. Test watchdoga z odpiętym kablem: teraz przerwanie ma być natychmiastowe,
   nie po 8 sekundach.

---

# PulsoKit v0.77 — porządki i wizualny edytor TD0

## Martwy kod — 444 linie mniej

Usunięte z `ContentView.swift`: `td0Tab` (kompletny, drugi edytor TD0, do
którego nie prowadziła żadna ścieżka), `TD0ZoneEditorCard`, `td0InfoCard`,
`td0NumberEditor`, `td0LevelText`, `td0ArrayBinding`, `td0PanText`,
`infoGroup`. Z `MIDIManager` zniknęły `snareHead` i `snareRim` —
publikowane, nigdy przez nikogo nieczytane.

Unikalne edytory, które siedziały w martwym `td0Tab`, nie zostały wyrzucone
— zostały przeniesione do TD0 Studio (niżej).

## Wspólne katalogi

Powstały `TD17ZoneCatalog`, `TD17ReverbCatalog`, `TD17LayerCatalog`
i `TD17MIDINoteCatalog`. Wcześniej te same tablice były wpisane osobno
w kilku miejscach: nazwy stref w dwóch plikach, typy reverbu w sześciu,
typy warstw w sześciu, „128 = OFF" w pięciu. Każda korekta wymagałaby
znalezienia wszystkich kopii, a rozjazd między nimi cichnie kończył się
podstawieniem pierwszej pozycji z listy.

## Nowa scena zestawu

`drumStage` rysowany ręcznie z elips i prostokątów zastąpiony renderem
TD-17KV. Pady są klikalne, wybrany dostaje obwódkę i podpis z poziomem.
Pod sceną wiersz stref: podstrefy wybranego pada (HEAD / RIM / BELL) oraz
AUX, który nie ma na tym zestawie fizycznego pada.

Grafika jest przezroczysta, więc pod spodem leży jasne tło — czarne pady
na ciemnym interfejsie byłyby nieczytelne.

Współrzędne padów siedzą w `TD17KitLayout` jako wartości 0…1 względem
obrazu, a nie względem pola widoku, więc scena skaluje się poprawnie przy
dowolnym rozmiarze okna. Widok jest osobnym plikiem i nie zna TD0 —
da się go użyć również po stronie SysEx.

## TD0 Studio — cztery strony zamiast dwóch

**Zestaw** — scena zestawu, mikser, inspektor strefy.

**Efekty** — pełne parametry zamiast trzech suwaków:
Ambience (typ, rozmiar, kształt, ściana, mikrofon, poziom), Reverb (typ
i 8 parametrów), kompresor (typ, mix balance), MFX (typ, poziom i 32
parametry). Każda karta z zakresami wziętymi ze stałych `MIDIManager`,
więc TD0 i SysEx nie mogą się już rozjechać.

**MIDI** — 24 przypisania nut. Wartość 128 pokazuje się jako OFF na
pomarańczowo, a nie jako liczba.

**Ogólne** — głośność kitu, pedal hi-hat, cross stick i jego włącznik,
balans hi-hat, oraz informacje o pliku.

Inspektor strefy dostał **V-Edit SUB** (wcześniej tylko MAIN), typ warstwy,
pełny Pad EQ z nazwami częstotliwości z katalogu, a surowe pole „Instrument
ID" zastąpił wybór z katalogu 311 instrumentów pogrupowany według rodziny —
płaska lista 311 pozycji byłaby nie do przejrzenia i kosztowna w rysowaniu.

## Poprawki

**Mikser i scena odświeżają się na żywo.** Oba czytały wartości
z `TD0ZoneDraft` w ciele widoku nadrzędnego, który obserwuje tylko `td0`.
Tablica `zones` nie zmienia tożsamości przy edycji poziomu, więc miernik
i podpis pokazywały nieaktualne wartości aż do przypadkowego przerysowania.
Oba są teraz osobnymi widokami obserwującymi swoją strefę.

**Rozmiar okna.** `.defaultSize(760×580)` przy `.frame(minWidth: 1080,
minHeight: 740)` w `ContentView` oznaczał domyślną wielkość, której nie
dało się osiągnąć. Teraz 1240×860.

**Wartości spoza katalogu** nie są już po cichu zamieniane na pierwszą
pozycję listy — picker pokazuje „nieznana (N)" na pomarańczowo.

## Do sprawdzenia

1. Zakładka **Plik TD0** → otwórz plik → strona **Zestaw**. Kliknij po
   padach, sprawdź czy zaznaczenie i podpis z poziomem trafiają we
   właściwą strefę i czy podpis zmienia się od razu po edycji poziomu
   w inspektorze.
2. Strony **Efekty**, **MIDI**, **Ogólne** — czy wartości zgadzają się
   z tym, co pokazuje moduł dla tego samego kitu.
3. **Zapisz kopię** i wczytaj ją z powrotem — MD5 musi się zgadzać.

---

# PulsoKit v0.78 — zaznaczanie padów

## Ramka narożnikowa zamiast obwódki

Zaznaczony pad dostaje cztery narożniki — `[ ]` — tak jak w edytorach
perkusji. Nic nie zasłania naciągu, nic się nie świeci i nie rozlewa na
sąsiednie pady. Wybrany pad ma narożniki cyjanowe, wskazany kursorem —
białe. Ramka jest prostokątna i nieobrócona; przekręcona wygląda jak błąd.

## Kształty padów

Pole klikalne każdego pada to elipsa dopasowana do jego rzeczywistego
obrysu, z obrotem. Wartości pochodzą z dopasowania elipsy do największej
spójnej plamy pikseli pada — naciąg mesh dla bębnów, czarny talerz dla
blach. Dzięki temu kliknięcie w werbel nie łapie stopy stojącej tuż obok,
a talerze nie zabierają połowy sceny.

Samo zaznaczenie i tak jest prostokątną ramką, więc dokładność kształtu
służy wyłącznie trafianiu kliknięć.

## Podpisy tylko gdy trzeba

Nazwa pada pokazuje się pod padem wybranym albo wskazanym kursorem, razem
z poziomem dla wybranego. Dziewięć stale widocznych plakietek robiło
z czytelnego zdjęcia gąszcz.

## Porządki przy okazji

Zniknęły ostatnie powielone literały: typy reverbu w pickerze na zakładce
Zestaw, nazwy parametrów reverbu w dwóch miejscach `MIDIManager` oraz
zamiana „128 → OFF" w pięciu. Wszystko idzie teraz przez katalogi.

Grafika zestawu leży w Assets jako pojedyncza skala w natywnej
rozdzielczości — dwie skale o różnych proporcjach powodowały minimalny
dryf pozycji padów.

---

# PulsoKit v0.79 — dlaczego przełączanie zakładek mulilo

## Picker instrumentów budował tysiące widoków

Zakładka Instrumenty miała przy każdej strefie `Picker` z pełnym katalogiem:
**311 widoków `Text`, każdy z formatowaniem tekstu**. Przy widocznej grupie
padów to kilkanaście takich pickerów naraz, czyli ponad trzy tysiące widoków
— i budowanych od nowa **przy każdym przeliczeniu widoku**, a nie tylko przy
otwarciu listy. Wejście w zakładkę oznaczało zbudowanie tego wszystkiego.

Zastąpione wspólnym `TD17InstrumentPicker`: menu z podziałem na rodziny
instrumentów, którego zawartość powstaje dopiero po otwarciu. Ten sam
komponent działa teraz po stronie SysEx i w edytorze plików TD0 — wcześniej
były to dwa osobne rozwiązania.

## Leniwe budowanie zakładek

Zakładki Zestaw, Instrumenty i V-Edit składały całą zawartość od razu, łącznie
z sekcjami, do których trzeba przewinąć pół ekranu. `LazyVStack` buduje tylko
to, co widać.

## Uwaga

To jest doraźna poprawka, nie rozwiązanie docelowe. Prawdziwa przyczyna leży
głębiej: `MIDIManager` ma około pięćdziesięciu publikowanych słowników
roboczych na jednym obiekcie, więc **każda zmiana dowolnego parametru
unieważnia cały interfejs**. Naprawia to dopiero przebudowa warstwy edycji,
opisana w planie przeprojektowania.

---

# PulsoKit v0.80 — nowy edytor kitu

Pierwsza partia z przeprojektowanego interfejsu. Ustalenia projektowe:
`claude/pulsokit-projekt-interfejsu.md` w projekcie.

## Nowa zakładka „Edytor"

Stare zakładki zostają nietknięte, żeby było z czym porównywać i żeby dało
się wrócić, gdyby coś nie działało. Nowy ekran jest pierwszy i domyślny.

**Klikasz pad na zestawie, po prawej masz komplet jego parametrów.** Koniec
z rozbiciem na Zestaw / Instrumenty / V-Edit, gdzie zmiana wszystkiego przy
werblu wymagała obejścia czterech ekranów.

**Mikser wszystkich dwudziestu stref** z suwakami do przeciągania i panoramą
pod każdym. Dwuklik na panoramie wraca na środek. Strefy ze zmienionym
poziomem albo panoramą świecą akcentem.

## Odroczone zmiany zamiast przycisku przy każdym parametrze

To najważniejsza zmiana i dotyczy warstwy pod interfejsem.

Edytujesz swobodnie. Zmiany zbierają się na liście obok sceny: strefa,
parametr, wartość przed i po. Każdą można wyrzucić osobno albo cofnąć
wszystkie naraz. Jest **Undo i Redo**.

**„Send changes"** wysyła tylko to, co zmienione, parametr po parametrze,
z weryfikacją każdego zapisu. Nie blokowo. Zapis blokowy dotykałby bajtów,
których nie zmieniałeś, a awaria byłaby widoczna dopiero przy odczycie
kontrolnym. Pasek pokazuje postęp, a przy niepowodzeniu mówi, na którym
parametrze stanął i ile zmian zostało niewysłanych.

Kolejność wysyłki jest ustalana: ustawienia warstwy SUB idą przed jej
instrumentem i poziomem, bo inaczej moduł nie ma czego potwierdzić.

## Osobny obiekt na strefę

Pod spodem powstał nowy model. Wcześniej wszystkie wartości robocze siedziały
w kilkudziesięciu słownikach na jednym `MIDIManager`, więc ruszenie dowolnego
suwaka unieważniało **cały** interfejs — stąd zacinanie się przy przełączaniu
zakładek. Teraz widok strefy odświeża się wtedy i tylko wtedy, gdy zmienia się
ta strefa. Poprawka z v0.79 była łatą; to jest rozwiązanie.

## Dwa błędy znalezione przy weryfikacji

**Zapis, który nie wystartował, był meldowany jako udany.** Metody `write*`
mają na wejściu warunki wstępne i przy niespełnionym którymkolwiek po cichu
wracają, nie podnosząc flagi zapisu. Pętla czekająca widziała „nie pisze" już
przy pierwszym sprawdzeniu i uznawała zapis za potwierdzony — zmiana znikała
z listy, choć do modułu nic nie poszło. Teraz najpierw sprawdzamy, czy zapis
w ogóle ruszył.

**Fade Point 0 blokował każde włączenie warstwy SUB.** Moduł zwraca 0 dla
warstw MIX i SWITCH, a zapis ustawień warstwy przyjmuje dopiero 1. W połączeniu
z poprzednim błędem wyglądałoby to tak, że włączasz warstwę, program melduje
sukces, a w module nic się nie zmienia.

## Do sprawdzenia

1. **Odczytaj kit** — nowa zakładka zapełni się dopiero po pełnym odczycie.
2. Poklikaj po padach, sprawdź czy inspektor pokazuje właściwą strefę.
3. Pociągnij kilka suwaków w mikserze i kilka parametrów w inspektorze.
   Lista zmian po prawej ma pokazać dokładnie to, co ruszyłeś.
4. **Undo, Redo, wyrzucenie pojedynczej pozycji, revert all.**
5. **Send changes** — obserwuj postęp i sprawdź w module, czy zmiany doszły.
6. Sprawdź, czy przełączanie między strefami jest płynne — to był główny
   powód przebudowy modelu.

Czego jeszcze nie ma w nowym ekranie: V-Edit, przypisania MIDI, efekty
globalne i wizualna przeglądarka instrumentów. Wybór instrumentu działa
przez menu z podziałem na rodziny. Te rzeczy dochodzą w kolejnej partii.

---

# PulsoKit v0.81 — poprawka kompilacji

`.foregroundStyle(count == 0 ? .secondary : .orange)` — operator warunkowy
wymaga jednego typu w obu gałęziach, a kompilator ustalił dla `.secondary`
typ `HierarchicalShapeStyle`, w którym nie ma `.orange`. Jawny `Color` po
obu stronach rozwiązuje sprawę.

Przy okazji `pulsoAccent` przeniesiony z rozszerzenia protokołu `ShapeStyle`
na zwykłe rozszerzenie `Color` i wszędzie wołany z jawnym typem — poleganie
na wyszukiwaniu składowej przez rozszerzenie protokołu to dokładnie ta sama
klasa problemów.

---

# PulsoKit v0.82 — układ edytora zgodny z projektem

Nie zaimplementowałem układu, który zatwierdziliśmy w makiecie. Inspektor
wylądował **pod** mikserem, na całą szerokość, zamiast być kolumną po prawej.

## Trzy kolumny

Scena i mikser po lewej, **inspektor tuż obok nich**, lista zmian na końcu.
Klikasz pad i parametry masz od razu po prawej, bez przeskakiwania wzrokiem
przez listę zmian. Inspektor musi być kolumną: edytujesz jedną strefę i patrzysz na
jej parametry cały czas, a wciśnięty pod spód wymagałby przewijania przy
każdej zmianie pada.

## Mikser rośnie razem ze sceną

Suwaki miały sztywne 190 px wysokości i zostawały paskiem na dole niezależnie
od wielkości okna. Teraz scena i mikser dzielą wysokość po połowie, więc
potencjometry rosną razem z widokiem zestawu. Minimalna wysokość sceny zeszła
z 380 na 220 px, żeby na niższym oknie mikser miał gdzie urosnąć.

---

# PulsoKit v0.83 — mikser ze stałą wysokością

W v0.82 mikser rósł razem z oknem. Efekt: tor suwaka robił się bardzo długi,
a nakładka, grubość toru i czcionki zostawały te same — wyglądało to jak
włosy z małym prostokątem gdzieś na górze.

Rozciąganie miksera wymagałoby skalowania **wszystkiego** razem: grubości
torów, wielkości nakładek, gałek i podpisów. To osobna robota i nie ma jej
po co robić, skoro dobrze dobrana stała wysokość wygląda lepiej. Mikser ma
teraz 198 px, czyli proporcje z zatwierdzonej makiety.

Przy okazji wypełnienie toru dostało kolor zamiast czystej szarości — na
ciemnym tle panelu ginęło.

---

# PulsoKit v0.84 — mikser w osobnym oknie

Na niskim ekranie scena, inspektor i mikser nie mieszczą się w jednym oknie —
coś zawsze zostaje ściśnięte do nieużywalności. Rozwiązanie znane z programów
muzycznych: mikser wychodzi do własnego okna.

## Co się zmieniło

**Przycisk „Mixer window"** w dolnym pasku edytora otwiera mikser jako osobne
okno. Można je odłożyć na drugi ekran albo otwierać tylko wtedy, gdy ustawiasz
balans całego zestawu.

**Otwarcie okna chowa mikser z edytora.** Dzięki temu główne okno nie musi się
przeskalowywać przy każdym otwarciu i zamknięciu. Zamknięcie okna przywraca go
na miejsce.

**Przycisk „Hide mixer" / „Show mixer"** chowa mikser bez otwierania osobnego
okna — stan zapamiętywany między uruchomieniami.

**Wybór strefy jest wspólny dla obu okien.** Kliknięcie paska w oknie miksera
przełącza strefę w edytorze i odwrotnie.

## Zmiana architektury

Modele — `MIDIManager`, `TD0EditorModel` i `KitEditor` — przeniesione z
`ContentView` na poziom aplikacji i wstrzykiwane przez środowisko. Bez tego
drugie okno nie miałoby do czego się podpiąć. Wybór strefy przeniesiony
z widoku do `KitEditor` z tego samego powodu.

## O blokowaniu rozmiaru głównego okna

Nie zablokowałem możliwości skalowania głównego okna przy otwartym mikserze.
Na macOS okno, którego nie da się chwycić za róg, wygląda jak zawieszone,
a problem, który miało to rozwiązać, znika sam, gdy mikser przestaje zabierać
miejsce w edytorze. Jeśli mimo to ma być zablokowane — do zrobienia.

---

# PulsoKit v0.85 — mikser układa się po ustaleniu rozmiaru

Podczas przeciągania krawędzi okna SwiftUI przelicza układ przy każdej klatce.
Mikser to dwadzieścia pasków, każdy z suwakiem poziomu i panoramy liczonymi
z własnej geometrii — przy każdym drgnięciu okna wszystko to powstawało od
nowa. Stąd skakanie i chwilowo złe proporcje.

Nowy `SettledSize` pokazuje zawartość dopiero wtedy, gdy rozmiar kontenera
przestanie się zmieniać, i podaje jej ten ustalony rozmiar. Mikser układa się
raz, po zatrzymaniu okna, a nie kilkadziesiąt razy w trakcie.

Zwłoka wynosi 120 ms — na tyle krótko, żeby nie było widać czekania, i na tyle
długo, żeby przeciąganie krawędzi zmieściło się w jednym oknie czasu.

---

# PulsoKit v0.86 — wyciszanie padów i poprawione suwaki

## Okno miksera zawsze na wierzchu

Osobne okno miksera trzyma się nad edytorem zamiast chować się pod nim przy
każdym kliknięciu w główne okno. Przy pulpicie do miksowania inaczej nie ma
to sensu.

Mikser w edytorze dostał **ikonę zamykania** w swoim nagłówku.

## Wyciszanie padów

Każdy pasek miksera ma przycisk **M**. Wyciszony pad na wizualizacji zestawu
jest przygaszony, przekreślony i nie dostaje podświetlenia zaznaczenia.

**Uwaga o sprzęcie:** TD-17 nie ma osobnego wyciszenia pada. Jedyne, co da się
wysłać, to poziom -INF. Wyciszenie zapamiętuje więc poprzedni poziom i ustawia
-INF jako zwykłą zmianę na liście, a odciszenie przywraca wartość. W module
zapisze się to jako poziom, nie jako flaga.

Wyciszenie **nie jest osobnym stanem**, tylko odczytem z poziomu — przycisk
świeci dokładnie wtedy, gdy pad milczy. Pierwsza wersja trzymała obok tego
własny zbiór wyciszonych stref i rozjeżdżała się przy cofaniu: poziom wracał,
a pad zostawał przekreślony.

## Suwaki: najpierw zaznaczenie, potem edycja

Kliknięcie w suwak przestawiało poziom w miejsce kursora. Teraz:

- kliknięcie w **niezaznaczony** pasek tylko go zaznacza, nic nie zmieniając,
- kolejne przeciągnięcie zmienia wartość **względnie**, od miejsca, w którym
  suwak stał — samo kliknięcie nigdy nie przeskakuje wartości.

To samo dotyczy panoramy. Dwuklik na panoramie dalej wraca na środek.

---

# PulsoKit v0.87 — mikser tylko w oknie, wyszarzone pady

## Mikser wyłącznie jako osobne okno

Panel pod sceną zniknął. Zabierał jej wysokość i na niższym ekranie nie dało
się sensownie ustawić ani jednego, ani drugiego. Zostaje jeden przycisk
**Show mixer**, który otwiera okno — a jeśli już jest otwarte, przenosi je
na wierzch.

Dzięki temu główne okno ma stały układ: scena, inspektor, lista zmian.
Nic się nie przeskalowuje przy otwieraniu i zamykaniu miksera.

## Wyciszony pad na szaro

Zamiast przyciemnienia z przekreśleniem pad dostaje jednolitą szarość.
Spłaszcza to zarówno biały naciąg, jak i czarny talerz do tego samego
martwego koloru, więc od razu widać, że pad nie gra — bez czytania czegokolwiek.

---

# PulsoKit v0.88 — mikser trzyma się okna, lista zmian w dymku

## Okno miksera przypięte do okna programu

Mikser jest teraz **oknem potomnym** okna edytora (`addChildWindow`). Wynika
z tego jedno i drugie naraz: przesuwasz główne okno — mikser jedzie razem
z nim, także na drugi ekran, i nigdy nie chowa się pod spód.

Pozycja ustawiana jest **raz**: pod oknem edytora, przy jego lewej krawędzi.
Jeśli pod spodem nie ma miejsca na ekranie, mikser staje obok, po prawej —
nigdy na oknie edytora, bo jako okno potomne zasłoniłby na stałe dolny pasek
z Undo i Send. Gdy przeciągniesz go gdzie indziej, kolejne otwarcia już tego
miejsca nie kasują.

## Show mixer / Hide mixer — jeden przycisk

Zamiast przycisku, który tylko otwiera, jest przełącznik dwustanowy. Napis
idzie ze stanu okna, więc widać, co się stanie po kliknięciu. W nagłówku
samego miksera działa też krzyżyk.

## Lista zmian zeszła na dolny pasek

`PENDING CHANGES` nie jest już trzecią kolumną. Zabierała 250 px scenie,
a zagląda się do niej raz na kilkanaście edycji. Teraz licznik zmian na dolnym
pasku jest jednocześnie przyciskiem — klikasz i lista rozwija się w dymku,
z tym samym „revert all" i krzyżykiem przy każdej pozycji.

## Większy rysunek zestawu

Główne okno ma teraz dwie kolumny: zestaw bierze wszystko, co zostanie,
inspektor parametrów stoi przy prawej krawędzi. Scena urosła o całą szerokość
dawnej listy zmian.

---

# PulsoKit v0.89 — cztery sekcje zamiast siedmiu

## Koniec z dublowaniem

Zakładka **Instrumenty** pokrywała się w całości z inspektorem Edytora —
instrument MAIN, ustawienia warstwy SUB, instrument SUB. Zniknęła.

Zakładka **Zestaw** była trzema różnymi rzeczami sklejonymi w jeden ekran:
mikserem stref (duplikat okna miksera), ustawieniami całego kitu i obsługą
snapshotów. Mikser i ustawienia poszły do Edytora, snapshoty zostały jako
osobna sekcja **Backup** — bo backup to nie edycja.

**V-Edit** i **MIDI** dotyczyły pojedynczych stref, więc wylądowały w inspektorze
tej strefy, której dotyczą. Nut MIDI jest 24, a stref 20 — hi-hat i werbel mają
po kilka — więc przypisanie siedzi w tablicy `TD17NoteMap`.

Zostają cztery sekcje: **Editor**, **Backup**, **TD0 file**, **Log**.

## Inspektor: przełącznik ZONE / KIT

Prawa kolumna ma u góry przełącznik. **ZONE** to parametry wybranego pada —
instrument, poziom, panorama, V-Edit z nazwami zależnymi od rodziny instrumentu
(dla werbla strojenie i sprężyna, dla talerza rozmiar i taśma), warstwa SUB
z własnym V-Editem, wysyłki, EQ pada i nuty MIDI. **KIT** to nazwa i opis kitu,
głośność, pedał hi-hatu, cross stick, balans hi-hatu oraz Ambience, Reverb,
MFX i kompresor główny.

Klik w pad albo w pasek miksera zawsze wraca do ZONE.

## Jeden model edycji dla wszystkiego

Ustawienia globalne miały wcześniej przycisk „Zapisz" przy każdym polu. Teraz
jadą tą samą drogą co parametry stref: na listę zmian, pod Undo/Redo i pod jeden
przycisk **Send changes**. Dwa sprzeczne zachowania na jednym ekranie byłyby
gorsze niż siedem zakładek.

## Poprawki znalezione przy okazji

- **Zapis odrzucony przez moduł był meldowany jako udany.** Warstwa edycji
  patrzyła tylko na to, czy zapis się skończył — a tak samo kończy się zapis
  potwierdzony, zapis, przy którym moduł odesłał inną wartość, i zapis przerwany
  przez watchdoga. Teraz liczy się potwierdzenie, a nie samo zakończenie.
- **Odczyt kitu uruchomiony z sekcji Backup nie docierał do edytora.** Sygnał
  o zakończonym odczycie był podpięty do ekranu edytora, którego w tym momencie
  nie ma w drzewie widoków — edytor zostawał ze starymi wartościami wyjściowymi
  i wysyłał zmiany policzone względem nieaktualnego stanu.
- **Pusta nazwa kitu** nie trafia już na listę zmian. Moduł odrzuca ją po cichu,
  a to zrywało całą dalszą wysyłkę.
- Nazwa kitu jest zapisywana bez spacji na końcu — dokładnie tak, jak przyjmuje
  ją moduł, więc stan po wysyłce zgadza się z modułem.
- Częstotliwość podziału kompresora pokazuje herce, a nie surową liczbę.
- Kolejność wysyłki jest powtarzalna, zgodna z kolejnością edycji.
- Poziomy w sekcji KIT mają obok suwaka krok co 0.1 dB.

---

# PulsoKit v0.90 — sam się ładuje, kit zmieniasz z aplikacji

## Pełny odczyt po uruchomieniu

Program przestaje otwierać się pusty. Po starcie (albo po podpięciu modułu)
sam robi **pełny** odczyt kitu, który stoi na TD-17. Do czasu, aż skończy,
ekran edytora pokazuje, że trwa odczyt, zamiast milczeć.

Odczyt startuje raz na uruchomienie. Jeśli próba nie dojdzie do skutku — moduł
nie jest jeszcze gotowy albo trwa inna operacja — szansa nie przepada
i „Odśwież" nadal działa.

## Zmiana kitu na module: podstawowe od razu, reszta po 5 sekundach

Tak jak było w planie. Kręcisz pokrętłem — od razu leci szybki odczyt (nazwa,
instrumenty, poziomy), żeby było widać, na czym stoisz. Pełny odczyt (ok. 3 s,
z efektami, V-Editem i nutami) czeka, aż wybór **nie zmieni się przez 5 sekund**.
Każdy kolejny skok kitu odsuwa ten moment, więc przewijanie kitów nie zamula.

Jeśli w tym momencie trwa coś innego, odczyt sam się ponawia zamiast przepadać.

## Zmiana kitu z poziomu aplikacji

Strzałki przy numerze kitu w nagłówku. Numer bieżącego kitu leży pod tym samym
adresem SysEx, spod którego go czytamy, więc zapis pod ten adres przestawia
moduł — nie trzeba zgadywać kanału MIDI dla Program Change.

Po przełączeniu leci szybki odczyt, a reszta dociąga się według tej samej
zasady pięciu sekund, żeby dało się przewijać kity bez czekania.

## Poprawki

- **Odczyt mógł wejść w środek wysyłki.** Między krokami serii flaga „trwa
  zapis" na chwilę opada i wszystko, co pytało „czy coś trwa", widziało
  bezczynność. Wystarczyło, żeby odroczony odczyt albo zmiana kitu weszły
  w tę szparę: numer kitu szedł na zero, reszta serii lądowała jako
  niewysłana, a już wysłane kroki dostawały cudzy werdykt. Wysyłka zgłasza
  się teraz jako osobna operacja.
- **Werdykt zapisu jest przypisany do konkretnego zapisu.** Gdyby między
  końcem naszego zapisu a sprawdzeniem wcisnął się inny, czytalibyśmy jego
  wynik.
- **Zmiana kitu w trakcie innej operacji nie znika.** Numer kitu celowo nie
  jest wtedy podmieniany (zapisy biorą go w chwili wysyłki, więc trafiłyby
  do innego kitu), ale program zapamiętuje, że musi się zsynchronizować,
  i robi to po zakończeniu.
- **Numer kitu nad danymi poprzedniego kitu** — przy zmianie kitu czyszczone
  są też bloki szczegółowe, żeby nie było widać nowego numeru nad starą
  zawartością.
- **Karta kitu nie znika przy odczycie**, więc strzałki zmiany kitu nie uciekają
  spod kursora.
- **Przerwanie wysyłki.** W trakcie serii jest przycisk Stop — wcześniej przy
  niemrawym module zostawało czekanie na watchdoga.
- Po przeładowaniu kitu widać komunikat, ile niewysłanych zmian zostało przy
  tym skasowanych (odnosiły się do poprzedniego stanu modułu).

---

# PulsoKit v0.91 — lista kitów, wykrywanie modułu, kompaktowy inspektor

## Lista wszystkich kitów

Przy numerze kitu w nagłówku jest ikona listy. Nazwy stu kitów moduł oddaje
po jednej, więc czytamy je raz na sesję (zaraz po pierwszym pełnym odczycie)
i trzymamy. Lista jest podzielona na dziesiątki, aktualny kit ma ptaszka,
klik przestawia moduł. Nazwa zmieniona w programie od razu poprawia się
na liście.

## Wykrywanie modułu bez zgadywania po nazwie

Wykrywanie po nazwie portu działa tylko przez USB — kto wpina TD-17 przez
zwykły interfejs MIDI, ma port nazwany po interfejsie. Teraz, gdy nazwa nic
nie mówi, program wysyła Identity Request i czeka na odpowiedź. Odpowiedział
Roland — jest z kim rozmawiać, więc leci odczyt. Cisza — program nie zużywa
swojej jedynej automatycznej próby i mówi wprost, żeby wybrać porty ręcznie.

Do tego: wypięcie i ponowne wpięcie kabla znów uruchamia automat, a odczyt
przerwany przez watchdoga nie zjada tej jednej szansy.

## Inspektor jak w TD0 Studio

Kontrolki miały sztywne szerokości (150–210 punktów) i to one wyznaczały
wysokość wiersza. Teraz jest gęściej, tak jak na ekranie pliku TD0:

- wartości liczbowe **wpisuje się z klawiatury**, strzałki są obok — wcześniej
  zmiana strojenia o czterdzieści jednostek to było czterdzieści kliknięć,
- poziomy podaje się w decybelach („-3.5"), a nie w dziesiątych częściach,
- suwaki poziomu zniknęły z inspektora — zjadały pół szerokości wiersza,
  a od zamaszystych ruchów jest okno miksera,
- podpis obok liczby pojawia się tylko wtedy, gdy coś wnosi („CENTER",
  „+3 dB", „16.0\""), a nie powtarza tej samej wartości dwa razy,
- wartość wpisana poza zakresem jest przycinana — moduł i tak by jej nie
  przyjął.

W trakcie wysyłki pola są zablokowane, bo model i tak odrzuca wtedy zmiany.

---

# PulsoKit v0.92 — układ jak w TD0

## Scena, mały mikser pod nią, inspektor po prawej

Dokładnie tak, jak na ekranie pliku TD0. Osobne okno miksera zostało usunięte
razem z przyciskiem Show/Hide.

Pasek pod sceną to **mały** mikser, nie ten poprzedni na 190 punktów: słupek
poziomu, nazwa, wartość, panorama i wyciszenie. Tyle, żeby ustawić balans
zestawu bez schodzenia do inspektora — i tylko 102 punkty wysokości, więc
reszta zostaje dla rysunku zestawu.

- przeciągnięcie po słupku w pionie zmienia głośność,
- przeciągnięcie po pasku pod nazwą zmienia panoramę, dwuklik wraca na środek,
- **M** wycisza pad; wyciszony pad szarzeje też na rysunku zestawu,
- pierwsze kliknięcie w niezaznaczoną strefę tylko ją zaznacza — wartość
  nigdy nie przeskakuje w miejsce kursora.

## Inspektor 330 zamiast 430

Szeroki musiał być tylko po to, żeby zmieścić suwak poziomu obok liczby.
Suwaków w wierszach już nie ma, więc kolumna schudła o sto punktów.

## Poprawki

- **Kliknięcie w słupek mogło wyciszyć pad.** Gest z zerowym progiem zgłasza
  też sam moment wciśnięcia, z zerowym przesunięciem; przy bardzo niskim
  poziomie zaokrąglenie schodziło wtedy do -INF. Ten sam mechanizm przy
  każdym kliknięciu kasował stos ponawiania i przestawiał kolejność cofania.
  Błąd był w kodzie od v0.86 — wyszedł dopiero teraz.
- Minimalna wysokość okna wróciła na 740 punktów: mały pasek mieści się
  spokojnie tam, gdzie mikser na 190 punktów już nie.

---

# PulsoKit v0.93 — główny ekran w układzie TD0

Plik `.TD0` to ten sam kit co w module: te same dwadzieścia stref, instrumenty,
poziomy, panorama, V-Edit, warstwy SUB, EQ, wysyłki, nuty i efekty. Dwa ekrany
robiły więc tę samą robotę w dwóch układach. Lepszy okazał się ten z TD0, więc
przejmuje go edytor modułu.

## Lewy pasek

**EDITOR** — cztery strony: Kit, Effects, MIDI, General.
**KIT** — nazwa i opis zestawu wpisywane od razu, bez schodzenia gdziekolwiek.
Na dole numer kitu i informacja, czy w pamięci jest komplet danych, czy tylko
podstawowe.

## Strony

- **Kit** — scena z padami i mały mikser pod nią (głośność, panorama, mute).
- **Effects** — Ambience, Reverb, MFX z parametrami P01–P32, Master Comp.
- **MIDI** — wszystkie 24 przypisania nut.
- **General** — głośność kitu, pedał hi-hatu, cross stick, balans hi-hatu.

Inspektor wybranej strefy stoi po prawej **niezależnie od strony**, więc
parametry pada są pod ręką zawsze. Przełącznik ZONE/KIT zniknął — ustawienia
kitu mają teraz własne strony.

## Poprawki

- Pasek stref przewija się w poziomie przy stałej szerokości komórki, jak
  w TD0. Rozciąganie dwudziestu komórek na szerokość okna dawało przy węższym
  oknie 23 punkty na komórkę, czyli same wielokropki zamiast nazw.
- Nazwa i opis kitu są blokowane na czas wysyłki — model i tak odrzuca wtedy
  zmiany, a wpisany tekst zostawałby w polu jako cicha nieprawda.

## Suwaki — wariant „rowek z karbem"

Sam słupek nie mówił, że da się go chwycić. Teraz każdy tor ma rowek
w kolorze akcentu i wąski jasny uchwyt:

- **poziom** — rowek 12 pt, uchwyt 18×6 pt; wysokość uchwytu jest odjęta od
  drogi, więc przy skrajnych wartościach nie wystaje poza rowek,
- **panorama** — ten sam język: rowek, kreska środka, wypełnienie **od środka**
  w stronę odchylenia (widać kierunek i siłę bez czytania liczby) i ten sam
  uchwyt; dwuklik dalej wraca na środek,
- **wyciszenie** — przycisk M przeniesiony **nad** suwak, na całą szerokość
  komórki; nazwa odzyskała przez to całe miejsce pod spodem.

Oczekująca zmiana świeci pełnym akcentem na uchwycie i w wypełnieniu.
Sprawdzana jest **przed** wyciszeniem — samo wyciszenie to zapis poziomu -INF,
więc inaczej pad wyciszony w aplikacji wyglądałby dokładnie tak samo jak pad
wyciszony już w module.

## Wyszarzenie wyciszonego pada — naprawione

Działało wyłącznie na stopie. Warunek brzmiał „wszystkie strefy pada
wyciszone", a prawie każdy pad ma ich kilka: werbel to naciąg i obręcz, ride
nawet trzy. Wyciszenie werbla wyciszało strefę SNARE HEAD, obręcz zostawała
głośna — i pad na scenie wyglądał normalnie.

Teraz:

- **cały pad milczy** — pełna szarość, jak dotąd,
- **milczy część stref** — szarość przygaszona, bo pad nadal gra obręczą,
- **pastylki stref** (SNARE HEAD, AUX RIM…) dostały ikonę przekreślonego
  głośnika i przygaszony kolor. Strefy AUX i obręcze nie mają własnego
  kształtu na zdjęciu, więc pastylka była jedynym miejscem, gdzie w ogóle
  dało się je zobaczyć — i akurat tam wyciszenia nie było widać wcale,
- **wyciszony pad znów pokazuje zaznaczenie**, tylko szarą ramką zamiast
  niebieskiej. Wcześniej klik w wyciszony bęben nie dawał żadnej reakcji
  na scenie.

## Lista kitów: jedna, płaska, wczytywana od razu

Podział na dziesiątki zniknął — jest jedna lista od 1 do 100, którą macOS sam
przewija. Skan startuje zaraz po wykryciu modułu, a nie dopiero po pierwszym
pełnym odczycie kitu.

Trzy rzeczy, które trzeba było przy tym poprawić:

- **Pierwszy odczyt kitu przepadał.** Skan listy startował pół sekundy po
  podpięciu, pierwszy odczyt siedemset milisekund — czyli skan zajmował moduł
  pierwszy, a odczyt trafiał na „coś już trwa" i po prostu rezygnował. Okno
  zostawało puste do czasu ręcznego kliknięcia. Odczyt ma teraz pierwszeństwo,
  a skan czeka, aż tamten skończy.
- **Skan mógł strzelać w cudze urządzenie.** Zadanie budziło się pół sekundy
  później i nie sprawdzało, czy moduł nadal jest podpięty. Po wyjęciu kabla
  wybór portu spada na pierwsze lepsze wyjście MIDI — skan waliłby w nie
  zapytaniami i zablokował program do czasu watchdoga.
- **Sto pozycji przeliczało się bez potrzeby.** `Menu` buduje całą zawartość
  od razu, a nagłówek przelicza się przy każdej zmianie w `MIDIManager` —
  także przy każdej porcji logu. Lista porównuje się teraz po wartościach,
  więc powstaje tylko wtedy, gdy naprawdę się zmieni.

---

# PulsoKit v0.94 — karta kitu otwiera listę

Kliknięcie w kartę z numerem i nazwą kitu rozwija listę stu kitów. Osobna
ikonka listy obok zniknęła — były to dwa przyciski do tej samej rzeczy.
Strzałki góra/dół zostają, bo przeskok o jeden kit ma być jednym kliknięciem.

---

# PulsoKit v0.95 — angielski interfejs, termin ważności, zrzut SETUP

## Cały interfejs po angielsku

Przetłumaczone zostały **wszystkie** napisy widoczne dla użytkownika: przyciski,
zakładki, etykiety, statusy i cały log komunikacji SysEx. Komentarze w kodzie
zostają po polsku.

Najpierw trzeba było usunąć pułapkę: wynik zapisu był rozpoznawany po polskich
przedrostkach „POTWIERDZONO" i „NIEZGODNOŚĆ" w treści logu. Przetłumaczenie
komunikatów bez ruszenia tego zamieniłoby każdy udany zapis w „moduł nie
potwierdził". Flaga jest teraz ustawiana jawnie w każdej z 21 gałęzi
weryfikacji — 21 razy „potwierdzone", 21 razy „niezgodność", policzone
i sprawdzone parami.

Tłumaczenie robiło narzędzie ruszające wyłącznie treść literałów tekstowych,
z pominięciem komentarzy, nazw i wnętrz interpolacji. Recenzent i tak znalazł
w nim błąd: reguła „Typ → Type" trafiła w już angielskie słowo `Type` wewnątrz
**kluczy JSON snapshotu**, robiąc z `layerType` → `layerTypee`. Snapshoty
zapisane wcześniej wczytywałyby się bez błędu, ale Room Type, Wall Type i typ
warstwy SUB po cichu wypadłyby z porównania i z przywracania. Poprawione.

## Wersja testowa do 29.09.2026

Po tej dacie program pokazuje ekran z informacją o wygaśnięciu i nic więcej.
Na dwa tygodnie przed terminem u góry pojawia się pasek z licznikiem dni.

Uczciwie: to zabezpieczenie przed przypadkiem, nie DRM. Cofnięcie zegara jest
wyłapywane (program pamięta najpóźniejszą widzianą datę), ale kogoś
zdeterminowanego to nie zatrzyma.

Blokada siedzi w jednym wąskim gardle — funkcji wysyłającej dane na łącze —
więc po terminie nie wychodzi ani jeden bajt, także z operacji, która zdążyła
wystartować przed północą. Termin jest przeliczany co minutę, a nie tylko przy
starcie, bo program potrafi chodzić tygodniami.

## Zrzut ustawień modułu (Log → Dump module setup)

Wyłącznie odczyt. Program pyta po kolei o bloki z obszarów `00`, `01` i `02`
i wypisuje surowe bajty do logu. Kity siedzą pod `03 00 00 00`, a jedyne, co
z obszaru ustawień znamy, to numer bieżącego kitu pod `00 00 00 00` — reszty
mapy nie ma nigdzie, więc trzeba ją odkryć porównując zrzut z tym, co moduł
pokazuje na własnym ekranie.

Nieistniejące adresy nie odpowiadają, więc każdy blok ma własny krótki limit
czasu. Cały zrzut to najwyżej 35 sekund przy zupełnie niemym module.

---

# PulsoKit v0.96 — ikona i szerszy zrzut SETUP

## Ikona aplikacji

`Assets.xcassets/AppIcon.appiconset` ma komplet rozmiarów od 16 do 1024
punktów: ciemny bordowy kwadrat, naciąg bębna widziany z góry i impuls
w kolorze akcentu. Xcode wciąga ją sam.

## Zrzut SETUP sięga dalej

Pierwszy zrzut ze sprzętu pokazał, że obszar triggerów `02` ma blok wspólny
i po jednym bloku na wejście, co 128 adresów — ale odpowiedziało tylko siedem
wejść, bo reszta leżała poza zasięgiem skanu. Teraz obszar `02` jest czytany
do 4096, a `01` do 2048. Limit czasu na blok bez odpowiedzi skrócony z 360 do
240 ms, bo moduł odpowiada w kilkadziesiąt milisekund.

---

# PulsoKit v0.97 — ustawienia triggerów (odczyt)

Nowa sekcja **Triggers**. Dziesięć wejść modułu z rozszyfrowanymi wartościami:
typ pada, czułość, próg, krzywa, wzmocnienie obręczy, korekta naciąg/obręcz,
czas skanowania, maskowanie, retrig cancel i przesłuch. Na razie **wyłącznie
odczyt** — zapis dojdzie dopiero, gdy liczby na ekranie programu zgodzą się
co do jednej z tym, co pokazuje moduł.

Mapa adresów powstała ze zrzutu z żywego modułu i została potwierdzona
porównaniem z jego ekranem:

- blok wspólny `02 00 00 20`: Xstick Adjust i dziesięć wartości przesłuchu,
- blok wejścia `02 00 00 00 + numer×128`, dziesięć bajtów:
  typ pada, czułość (od zera), wzmocnienie obręczy ×10, próg,
  retrig cancel (od zera), ext noise cancel, korekta naciąg/obręcz,
  czas skanowania w dziesiątych ms, maskowanie w ms, krzywa.

To, że czułość i retrig cancel są liczone **od zera**, wyszło z testu na
sprzęcie: zmiana czułości werbla z 6 na 8 przesunęła bajt z 5 na 7.

Kody typów padów rozpoznane na żywym module: 5 stopa, 21 PDX-12, 22 tom,
30 CY-14C, 34 CY-8, 35 CY-5. Nieznany kod pokazujemy liczbą, zamiast zgadywać.

Odczyt przerwany kasuje tabelę — siedem wierszy wygląda jak komplet i nikt
by nie zauważył, że brakuje trzech wejść.

---

# PulsoKit v0.98 — odsłuch i próba przed zapisem

## Odsłuch

Program nie ma czym zagrać sam — próbki siedzą w pamięci TD-17. Wysyła więc
zwykłą nutę na kanale 10 i dźwięk wychodzi z modułu tak samo jak przy
uderzeniu pałką.

- kliknięcie w pad na rysunku gra ten pad,
- **Play kit** przechodzi cały zestaw pad po padzie, przycisk zamienia się
  w **Stop**,
- suwak siły uderzenia i przełącznik głośnika w dolnym pasku.

Za nutą zawsze idzie jej zamknięcie po 120 ms — bez tego przy hi-hacie
zostaje wiszący dźwięk. Zamknięcie wychodzi tylko wtedy, gdy otwarcie
faktycznie poszło: po terminie ważności ani w środku odczytu z programu nie
wychodzi ani jeden bajt.

Nut nie wysyłamy w trakcie rozmowy SysEx. Gdy moduł ma włączone Soft Thru,
echo nuty wpada w niedokończoną ramkę i cały odczyt trzeba zaczynać od nowa.

## Próba przed zapisem — „Try it"

Do tej pory zmianę było słychać dopiero po wgraniu jej na stałe. Teraz
**Try it** wysyła oczekujące zmiany do modułu *na próbę* i od razu gra pady,
których dotyczą. Zmiany zostają na liście, a program pamięta wartości sprzed
próby, więc są dwa wyjścia:

- **Undo in module** — moduł wraca do stanu sprzed próby, zmiany zostają
  na liście do dalszej pracy,
- **Keep N** — to, co gra, staje się zapisane.

Powrót wysyła listę **odwróconą**: `push` zawsze wgrywa wartość docelową,
więc bez odwrócenia „cofnij" wysłałoby jeszcze raz dokładnie to, co przed
chwilą poszło na próbę.

Kolejność też jest inna, ale tylko w jednym miejscu. Warstwę SUB trzeba
włączyć, zanim pojedzie jej instrument i głośność — więc powrót, który
warstwę gasi, gasi ją **na końcu**, żeby reszta nie trafiła do martwej
warstwy. Pozostałe zależności działają tak samo w obie strony: wgranie
instrumentu ustawia padowi fabryczny V-Edit, a zmiana typu efektu zeruje jego
parametry, więc rodzic idzie przed dziećmi również przy powrocie.

Krok trafia na listę „do cofnięcia" w chwili, gdy bajty schodzą na kabel,
a nie gdy moduł je potwierdzi. Brak potwierdzenia nie znaczy „nie doszło" —
mogła zginąć sama odpowiedź. Lepiej mieć przycisk powrotu na coś, co nie
dotarło (powrót wgra tę samą wartość, która i tak tam siedzi), niż nie mieć
go na coś, co dotarło i zostałoby w module na zawsze.

**Keep** zatwierdza wszystko, co poszło na próbę — także wtedy, gdy po
odsłuchu poprawiłeś wartość. Nowsza edycja wraca na listę, ale liczona już od
tego, co naprawdę gra w module, a nie od stanu sprzed próby. Pominięcie
którejkolwiek pozycji zostawiłoby program z fałszywym obrazem sprzętu.

Zmiana instrumentu kasuje w module V-Edit tego pada, więc powrót wgra stary
instrument, ale jego V-Edit będzie już fabryczny. Program mówi o tym wprost,
zanim naciśniesz.

Jeśli w trakcie próby kit na module się przełączy, komunikat po przeładowaniu
mówi osobno, ile zmian przepadło **i** ile zostało wgranych w moduł — te
wartości tam są, tylko program przestaje o nich wiedzieć.
