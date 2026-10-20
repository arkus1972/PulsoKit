# Build 243 — czytelność napisów + długie nazwy piosenek

## Co wgrać (GitHub, przez stronę WWW)
1. `app/src/main/assets/Pulsometron.html` — podmień.
2. `BUILD_NUMBER` — podmień (243).
3. Ręcznie: `app/build.gradle` → `versionCode 243`, `versionName "243"`.

## Zmiany
- Okno pomocy (i): tytuł, ✕ i „klawisze” w tekście były jasne na jasnym — teraz czytelne.
- Toast z „Undo”: ciemny pasek z jasnym napisem.
- „Load setlist into metronome”: ciemny przycisk zamiast pomarańczowego.
- Motyw scena: Songs / Setlists / Ustawienia / okno MORE / Training miały własne kremowe kolory
  (zmienne z Build 107/115) — teraz idą za motywem.
- Ekran metronomu: długa nazwa piosenki łamie się na drugą linię zamiast ucinać.
