# Předávka vedení — oprava 1 (rozsekání frontendu)

## 2026-10-16, zahájení

Základna: `5663b32`, worktree `/home/lucas/music-seeker-wt/oprava-1`
(větev `oprava-1-rozsekani`). Hlavní strom měl v tu chvíli jen netrackovaný
`snap-albums.md` — základna čistá.

**Měření před zadáním** (ne odhady):
- `static/index.html` = 1 760 řádků; `#pageSettings` 653 ř. a `#fullPlayer` 505 ř.
  dávají dohromady 66 % souboru.
- CSS je už rozsekané do 14 souborů, největší 394 ř. → **vyřazeno z rozsahu**,
  původní formulace „a vše další, co dává smysl" se tím u CSS vyčerpala.
- Na `static/index.html` sahají dvě místa: `app/__init__.py:88`, `entrypoint.sh:13`.

**Ověření oracle (vedení, před kritikou).** Premisa zadání je, že servírovaný
dokument je repo soubor s dosazeným cache bustem. Ověřeno proti běžící produkci:

    curl http://192.168.1.22:8090/ → 1 760 řádků, 16 výskytů ?v=<číslo>
    po normalizaci ?v=[0-9]+ → ?v=__CACHE_BUST__  ==  static/index.html  (bajtová shoda)

Oracle je tedy platný: hradlo nad bajtovou shodou sestaveného souboru skutečně
pokrývá to, co dostane prohlížeč.

**Rozhodnutí vedení k rozsahu:** JS do této dávky nepatří (A2 = ne). Pro JS
neexistuje bajtový oracle a repo nemá testovou sadu; rozdělení modulu je změna
chování, dokud se neprokáže opak. Jiná třída rizika → vlastní dávka.

**Odchylka od metodiky, přiznaná:** metodika předepisuje mutace přes `tsc --noEmit`
a `pnpm test`. Tenhle repo nemá TypeScript, testovou sadu ani mutační nástroj
(`package.json` obsahuje jen Playwright). Mutace se proto dělají nad hradlem
bajtové shody — pro refaktor bez změny chování je to silnější oracle než test.
7fabd48756bc0bf9b655cc999623759e8961b85dda9f39dcb0c6cebcb133bde8  static/index.html (celek 1, migrační reference)

## Kritika (verdikt: po úpravách)

Kritik vyvrátil **šest** mých tvrzení v zadání, všechna jsem označil za „měřeno":
`#fullPlayer` 139 ř. (tvrdil jsem 505), `#loginScreen` 19 (80), dva největší bloky
44,8 % (66 %), jeden `modal-overlay` (21), `settings-group` 4 (12), a hlavně
„repo nemá testovou sadu" — má 42 pytest testů. Měřil jsem mezery mezi značkami,
ne rozsahy elementů.

**Nejcennější nález: varianta (d), kterou zadání vůbec nemělo.** Sestavovat lokálně
skriptem a `static/index.html` nechat trackovaný → `entrypoint.sh` ani
`app/__init__.py` se nedotknou. Tím padly tři vysoké nálezy naráz:
- N1: `entrypoint.sh` nemá `set -e` ani `set -u`; `cat ... > index.html` při selhání
  utne soubor na 0 B a kontejner nastartuje dál → bílá stránka bez hlášky.
- N2: `.gitignore` na trackovaný soubor nic nedělá; po `git rm --cached` by deploy
  (tar pracovního stromu) začal záviset na tom, co má kdo na disku.
- N7: dnešní `sed` je **jednorázový** (ověřeno vedením) — druhý průchod nedělá nic,
  takže `docker restart` dnes bust nebumpne. Varianta (a) by to tiše změnila.

**Cena varianty (d), kterou kritik pojmenoval a vedení ověřilo:** hradlo nic
nevynucuje — žádný aktivní hook, `core.hooksPath` nenastaveno, žádný
`.pre-commit-config.yaml`, žádné `.gitattributes`, a `build-desktop.yml` nemá job
nad repem. A protože bajtový oracle zakazuje do `index.html` cokoli přidat, nemohl by
nést ani značku „generováno". Řešeno rozdělením na dva celky: celek 1 bajtově shodný,
celek 2 přidá přesně jeden řádek komentáře + `.gitattributes` + hook + docs.
`core.hooksPath` se po `git clone` nenastaví samo — komentář vidí každý.

## Autor (stop přijat 12:46)

16 částí v `frontend/partials/`, největší 340 ř. (méně než 394 ř. `search.css`,
které jsem z rozsahu vyřadil jako dost malé). 7 mutací, všechny zemřely.

**Vedení ověřilo nezávisle, nepřebíralo:**
- celek 1 sestavený bez řádku celku 2 → `7fabd487…bde8` = reference ✓
- a zároveň **bajtově shodný s tím, co v tu chvíli servírovala produkce** (po
  normalizaci `?v=[0-9]+`) ✓ — silnější doklad, než zadání žádalo
- celek 2: `git diff --numstat` = `1 0` ✓
- hradlo zelené a hash cíle se po jeho běhu nehnul → není tautologie ✓
- `pytest tests/ -q` = 39 passed, 3 skipped, před i po ✓

**Přiznaná mez od autora, kterou beru:** hradlo hlídá jen bajtovou shodu, ne
smysluplnost švů. Kdo přesune řádek mezi sousedními částmi a přegeneruje, projde —
a právem, výstup je stejný. Proti rozsypání švů oracle není a být nemůže.

## Otisk zamrazeného stromu (předán všem třem drahám)

    status-md5     3075d596172167abd66f82ce23177627
    diff-md5       692924062e794a67933096d5dee68915
    untracked-md5  909f20408ef0187f3fd9cbb6c99aa15b
