# Jak wrzucić to do repozytorium

Do zrobienia raz. Potem już tylko `git add / commit / push`.

## Jeśli repozytorium jest jeszcze puste

Rozpakuj archiwum, wejdź do katalogu i:

```sh
git init
git branch -M main
git remote add origin https://github.com/UŻYTKOWNIK/REPO.git
git add -A
git commit -m "PulsoKit v0.98 + kompilacja na GitHub Actions"
git push -u origin main
```

## Jeśli coś już tam wrzuciłeś

Skopiuj do katalogu repozytorium te cztery rzeczy z archiwum:

```
.github/workflows/build.yml
.gitignore
README.md
PulsoKit.xcodeproj/xcshareddata/xcschemes/PulsoKit.xcscheme
```

plus katalog `PulsoKit/` ze źródłami, jeśli chcesz od razu wersję v0.98.

**Jednej rzeczy trzeba przypilnować.** Jeśli wcześniejszy commit wciągnął
katalog `xcuserdata`, samo dopisanie go do `.gitignore` nic nie da — git
pilnuje plików, które już śledzi. Trzeba go wypisać:

```sh
git rm -r --cached "PulsoKit.xcodeproj/xcuserdata" 2>/dev/null || true
```

Potem sprawdź, czy schemat na pewno wchodzi — bez niego kompilacja na
GitHubie nie ma czego zbudować:

```sh
git add -A
git status --short | grep xcshareddata
```

Ma się pokazać `PulsoKit.xcodeproj/xcshareddata/xcschemes/PulsoKit.xcscheme`.
Jeśli się nie pokazuje, wymuś:

```sh
git add -f PulsoKit.xcodeproj/xcshareddata/xcschemes/PulsoKit.xcscheme
```

I na koniec:

```sh
git commit -m "Kompilacja na GitHub Actions"
git push
```

## Co się stanie po pushu

Zakładka **Actions** → przebieg **Build**. Trwa jakieś 3–6 minut.

- **zielony znaczek** → na dole strony przebiegu, w **Artifacts**, leży
  `PulsoKit-v0.98-…` z gotową aplikacją,
- **czerwony** → na samej górze strony przebiegu jest podsumowanie z listą
  błędów kompilacji, gotowe do skopiowania. Wklej mi je, a poprawię.

## Wydanie do rozdawania

```sh
git tag v0.98
git push origin v0.98
```

Wystawi się Wydanie ze stałym adresem, który możesz wkleić w przycisk
„Pobierz" na stronie:

```
https://github.com/UŻYTKOWNIK/REPO/releases/latest/download/PulsoKit.zip
```

Ten adres nigdy się nie zmienia — zawsze pokazuje najnowsze wydanie.

## Jeśli pierwszy przebieg padnie na starcie

Najczęstsze dwie przyczyny, obie do sprawdzenia w 10 sekund:

1. **„scheme PulsoKit not found"** — nie wszedł plik `.xcscheme`. Patrz wyżej,
   `git add -f`.
2. **Błędy w rodzaju „unknown attribute" albo „cannot find … in scope"
   w plikach, które u Ciebie się kompilują** — mac na GitHubie ma inną wersję
   Xcode niż Twój. W logu przebiegu, w kroku *Wybierz najnowszy Xcode*, jest
   wypisana jego wersja. Podaj mi ją.
