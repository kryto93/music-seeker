# Oprava 1 — rozsekání statického frontendu: evidence autora

Worktree: `/home/lucas/music-seeker-wt/oprava-1`, větev `oprava-1-rozsekani`, základna `5663b32`.
Zadání: `notes/impl/oprava-1-zadani.md` (přednost: dodatek 2 > dodatek 1 > původní znění).

Necommitoval jsem, nepushoval, nenasazoval. `entrypoint.sh`, `app/**`, `static/js/**`,
`static/css/**`, `desktop/**`, `.github/**` jsem se nedotkl (`git status` níže to dokládá).

---

## 1. Co vzniklo

### Celek 1 — rozdělení, bajtově shodné

| soubor | obsah |
|---|---|
| `frontend/partials/*.html` | 16 částí, dohromady 1 760 řádků = celý původní soubor |
| `scripts/build-index.sh` | `cat` částí → `static/index.html`; jediný, kdo do něj píše |
| `scripts/check-index.sh` | hradlo: sestaví do **dočasného** souboru a jen porovná |
| `scripts/lib-partials.sh` | sdílená pravidla obou skriptů (kolo 2, viz R1/R4) |

### Celek 2 — pojistka proti driftu

| soubor | změna |
|---|---|
| `frontend/partials/00-head.html` | 1 řádek: `<!-- GENERATED FILE - … -->` hned za `<!DOCTYPE html>` |
| `static/index.html` | regenerováno → diff **přesně 1 přidaný, 0 smazaných** řádků |
| `.gitattributes` | nový: `static/index.html linguist-generated=true` |
| `.githooks/pre-commit` | nový: pouští `scripts/check-index.sh` nad zastagovaným obsahem |
| `docs/architecture.md` | přepsán ř. 109 + nová sekce „`static/index.html` is generated" |
| `README.md` | přepsán ř. 110 (kolo 2, R6) |

---

## 2. Švy — bod zadání → soubor/řádek

Dodatek 1 §5 dává kotvy, ne čísla řádků; rozsahy níže jsem odvodil z `grep -n` nad
původním souborem a doložil je hradlem. Části jsou **souvislé úseky původního souboru
v původním pořadí** (dodatek 1 §4) — žádný řádek nepřidán, nesmazán, nepřeformátován,
neposunut. Jediná výjimka je ten jeden řádek celku 2.

| část | ř. originálu | ř. | kotva ze zadání |
|---|---|---|---|
| `00-head.html` | 1–96 | 96 | `head` |
| `10-login.html` | 97–117 | 21 | `#loginScreen` |
| `20-nav.html` | 118–176 | 59 | `nav` (+ otevření `#appContainer`) |
| `30-search.html` | 177–280 | 104 | `#pageSearch` |
| `40-discover.html` | 281–319 | 39 | `#pageDiscover` |
| `50-library.html` | 320–507 | 188 | `#pageLibrary` vč. `#pagePlaylists`, `#pagePodcasts`, `#pageFavorites` |
| `60-settings.html` | 508–511 | 4 | `#pageSettings` — hlavička + `.settings-form` |
| `61-settings-playback.html` | 512–851 | 340 | `settings-group` „Playback & Sound" (kotva ř. 512) |
| `62-settings-downloads.html` | 852–1020 | 169 | `settings-group` „Library & Downloads" (kotva ř. 852) |
| `63-settings-account.html` | 1021–1112 | 92 | `settings-group` „Account & App" (kotva ř. 1021) |
| `64-settings-admin.html` | 1113–1160 | 48 | `settings-group` „Admin" (kotva ř. 1113) |
| `70-download-modal.html` | 1161–1216 | 56 | `#downloadModal` |
| `80-player-bar.html` | 1217–1254 | 38 | `#playerBar` |
| `90-full-player.html` | 1255–1411 | 157 | `#fullPlayer` |
| `95-panels.html` | 1412–1440 | 29 | `#fpQueuePanel` + `#downloadsPanel` |
| `99-scripts.html` | 1441–1760 | 320 | `scripts` (vč. inline `<script>`, zůstává inline) |

Součet 1 760, bez děr a překryvů — ověřeno generátorem, který kontroloval `a == prev+1`
u každého švu a vypsal by `GAP/OVERLAP`; nevypsal nic, poslední pokrytý řádek 1 760.

Největší část je 340 řádků (`61-settings-playback.html`) — pod 394 ř. souboru
`static/css/search.css`, který zadání výslovně vyřadilo jako dost malý.

Přiznávám, co přiznává dodatek 1 §4: **žádná část není samostatně validní HTML.**
`#appContainer` se otevírá v `20-nav.html` a zavírá v `64-settings-admin.html`,
`.settings-form` se otevírá v `60-settings.html` a zavírá v `62-settings-downloads.html`.
Nespárované uzavírací tagy jsem nechal tam, kde textově leží; nic jsem nepřelepoval.

Dvouciferné předpony (dodatek 1 §5). Pořadí globu v `LC_ALL=C`:
`00 10 20 30 40 50 60 61 62 63 64 70 80 90 95 99`.

---

## 3. Jak je to ověřené

### 3a. Migrační kontrola celku 1 — před celkem 2

Nejsilnější dostupná forma: hradlo prošlo nad **nedotčeným** `static/index.html`.
Soubor nebyl v tu chvíli ani jednou přepsán (`git status` neukazoval `M`), takže shoda
nemohla vzniknout tím, že bych si cíl sám vygeneroval.

```
$ ./scripts/check-index.sh
check-index: static/index.html matches 16 partials
exit=0
$ sha256sum static/index.html
7fabd48756bc0bf9b655cc999623759e8961b85dda9f39dcb0c6cebcb133bde8
$ git status --short        # static/index.html se neobjevil
?? frontend/
?? scripts/
```

Teprve pak `./scripts/build-index.sh` — hash se nehnul, `git diff -- static/index.html`
prázdný. Reference uložena do `notes/impl/oprava-1-index.sha256`, `sha256sum -c` → `OK`.

### 3b. Celek 2 — diff přesně 1 řádek

```
$ git diff --numstat -- static/index.html
1	0	static/index.html
```

Přidaný řádek je HTML komentář, tedy nulový vliv na chování. Komentář je čistě ASCII
záměrně: leží **před** `<meta charset="UTF-8">` (ř. 4→5) a nechtěl jsem před deklaraci
kódování dávat nic vícebajtového. Posun `<meta charset>` o 124 bajtů je hluboko pod
1 024bajtovým oknem, ve kterém ho prohlížeč hledá.

Dokument se pořád parsuje: `html.parser` ho přečetl bez chyby, 49 komentářů, první je
ten nový.

### 3c. Oddělitelnost celků

V izolované kopii plného stromu (celek 1 + 2) jsem odebral celek 2 — smazal
`.gitattributes` a `.githooks/`, vrátil `docs/architecture.md` na `HEAD`, smazal řádek
s komentářem z `00-head.html` — a pustil `build-index.sh`:

```
plný strom (celek 1+2):  b2d78fd6d930c0fcd24cbab7990353434a576c190d50184d23209421691eb8c6
po odebrání celku 2:     7fabd48756bc0bf9b655cc999623759e8961b85dda9f39dcb0c6cebcb133bde8
reference:               7fabd48756bc0bf9b655cc999623759e8961b85dda9f39dcb0c6cebcb133bde8
RESULT: byte-identical -> celek 2 is separable
```

Hradlo v tom osekaném stromě prošlo (`exit=0`) a `docs/architecture.md` byl bajtově
shodný s `HEAD`. Celek 2 tedy nemá do celku 1 žádný přesah kromě toho jednoho řádku.

### 3d. Mutace

Izolovaná kopie mimo worktree (`…/scratchpad/autor/lab`), pro každou mutaci čerstvá.
Kontrolní běh bez mutace (M0) **zelený před sadou**. U každého běhu jsem navíc kontroloval
sha256 `static/index.html` *po* doběhnutí hradla — doklad k dodatku 2 §9, že hradlo není
tautologie.

| # | co jsem změnil | co hradlo vypsalo | nenulový kód |
|---|---|---|---|
| M0 | nic (kontrola) | `check-index: static/index.html matches 16 partials` | ne, 0 — správně |
| M1 | smazal `40-discover.html` | `does NOT match` + diff s 39 ubranými řádky `#pageDiscover` | **ano, 1** |
| M2 | prohodil `30-search.html` ↔ `40-discover.html` | `does NOT match` + diff ukazující Discover před Search | **ano, 1** |
| M3 | `id="playerBar"` → `id="playerBar "` v `80-player-bar.html` | `does NOT match` + jednořádkový diff na ř. 1218 | **ano, 1** |
| M4 | přidal prázdný řádek na konec `40-discover.html` | `does NOT match` + diff s jedním `+` prázdným řádkem | **ano, 1** |
| M6 | přejmenoval `20-nav.html` → `5-nav.html` | `does NOT match` + diff s přesunutým `<nav>`/`#appContainer` | **ano, 1** |
| M7 | ubral koncový novořádek z `40-discover.html` | `partial does not end with a newline: frontend/partials/40-discover.html` + `add the missing final newline(s), then re-run.` | **ano, 2** |

M7 je důvod, proč je kontrola novořádků samostatný krok (dodatek 2 §10): bez ní by to
spadlo až na bajtové porovnání a diff by byl nečitelný. Takhle hradlo pojmenuje přesně
ten soubor a nic víc nevypíše.

**Ve všech sedmi bězích zůstal `static/index.html` na referenčním hashi** — hradlo do něj
nikdy nesáhlo.

M5 z původního zadání odpadá (dodatek 1 §6): cache bust se dávky netýká, `entrypoint.sh`
zůstává nedotčený.

### 3e. Pre-commit hook

Vyzkoušený v jednorázovém gitovém repu (ne ve worktree), `core.hooksPath .githooks`:

- commit se synchronními částmi → hook vypsal `matches 16 partials`, **commit prošel**.
- pak jsem ručně upravil `static/index.html` (přidal atribut do `#playerBar`) a commitnul
  → hook vypsal `does NOT match` + diff, **commit exit=1**, `git log` obsahuje jen ten
  původní. Tedy přesně ten drift z dodatku 2 §8 je zachycený.

### 3f. Regrese

```
před prací: 39 passed, 3 skipped in 0.50s
po práci:   39 passed, 3 skipped in 0.47s
```

Beze změny, jak dodatek 2 §11 předpokládá — dávka na backend nesahá.

### 3g. Rozsah zásahu

```
$ git status --short
 M docs/architecture.md
 M static/index.html
?? .gitattributes
?? .githooks/
?? frontend/
?? notes/
?? scripts/
```

`git diff --stat -- entrypoint.sh app/` je prázdný.

---

## 4. Co jinak a proč

1. **Části začínají na komentáři sekce, ne na samotné kotvě.** Zadání říká „každá část
   začíná na uvedené kotvě". Originál má před každou kotvou řádek typu
   `<!-- ── Player Bar ── -->`; nechal jsem ho vést svou část, ne uzavírat tu předchozí.
   Část se tak sama představí hned prvním řádkem. Na bajtový oracle to nemá vliv —
   rozklad je pořád úplný a ve správném pořadí, posouvá se jen hranice o 1–2 řádky.

2. **`20-nav.html` otevírá `#appContainer`.** Mezi `#loginScreen` a `<nav>` leží
   `<div id="appContainer">` (ř. 119), který není v seznamu kotev. Dal jsem ho k navigaci
   — je to první část uvnitř kontejneru. Alternativa (nechat ho v `10-login.html`) by
   znamenala, že část „login" končí otevřením něčeho, co s loginem nesouvisí.

3. **`#pageSettings` je 5 částí, ne 4.** Zadání mluví o 4 skupinách `settings-group`.
   Řádky 508–511 (`<main>`, `<h2>`, `<div class="settings-form">`) ale do žádné z nich
   nepatří, takže mají vlastní `60-settings.html` (4 řádky). Bez toho by první skupina
   začínala něčím, co není skupina.

4. **Vytvořil jsem `notes/impl/oprava-1-index.sha256`**, ačkoli ho výčet celku 1 nemá.
   Dodatek 1 §2 ho jako migrační referenci vyžaduje a dodatek 2 §12 říká, že se po
   přejímce maže. Nepatří do žádného z celků, je to artefakt této dávky.

5. ~~**Hook kontroluje pracovní strom, ne staged obsah.**~~ Zrušeno v kole 2 (R2) —
   byla to obejitelná mez, ne odchylka. Hook teď kontroluje zastagovaný obsah.

6. **`99-scripts.html` není jen inline script.** (R7) Vedle inline `<script>` (ř. 1442–1758)
   obsahuje i `<script type="module" src="/static/js/app.js?v=__CACHE_BUST__">` na ř. 1441
   a uzávěry `</body>` / `</html>` na ř. 1759–1760. Nedělil jsem to dál — kotva ze zadání
   zní „scripts" a tři řádky navíc nestojí za vlastní část. Přiznáno, ne opraveno.

7. **`.gitignore` jsem nechal být.** Dodatek 1 §1 ruší variantu (a) ve prospěch (d);
   `static/index.html` zůstává trackovaný, takže zápis do `.gitignore` z původního B2 je
   bezpředmětný (a podle nálezu N2 by stejně nic neudělal).

---

## 5. Přiznané meze

1. **Neověřil jsem to v prohlížeči.** Celek 1 to nepotřebuje — dokument je bajtově týž.
   U celku 2 jsem ověřil jen parsování (`html.parser`) a to, že jde o HTML komentář;
   neviděl jsem vykreslenou stránku ani konzoli. Body 2–4 přejímky (7 stránek, full
   player, DJ panel, 3 modály, konzole, 404 na statiku) nejsou splněné — to je přejímka
   po mergi a restartu, ne moje dávka.

2. **Neověřil jsem, že `/static/partials/` vrací 404** (bod 4 přejímky). Doložil jsem jen
   to, že žádná část pod `static/` neleží; samotný požadavek proti běžící instanci jsem
   neposílal.

3. **Neověřil jsem chování v Dockeru.** `Dockerfile` má `COPY . .`, takže `frontend/`
   i `scripts/` se do image dostanou, a runtime se jich nedotkne — image jsem ale
   nestavěl. `.dockerignore` obsahuje jen `certs/`, takže nic nevylučuje.

4. **Hradlo nekontroluje, že části pokrývají dokument *smysluplně*** — jen že se slepí
   na bajt přesně. Kdyby někdo přesunul řádek z jedné části do sousední a soubor
   regeneroval, hradlo mlčí (a právem: výstup je stejný). Proti „rozsypání" švů tedy
   oracle není, ani být nemůže.

5. **Pořadí globu jsem ověřil v `LC_ALL=C`**, což si skripty samy nastavují. Netestoval
   jsem chování, kdyby někdo skript spustil s vynuceným jiným locale přes prostředí —
   `export LC_ALL=C` uvnitř obou skriptů to má pokrýt, ale neprověřoval jsem každou
   variantu shellu.

6. **Pytest je backendová sada a frontendu se nedotýká** (dodatek 1 §0). Shoda
   39/3 před i po tedy dokládá jen „nic jsem nerozbil v backendu", ne správnost dávky.
   Oracle této dávky je hradlo, ne testy.

7. **`.mjs` Playwright skripty v kořeni repa jsem nepouštěl** — vyžadují běžící instanci
   a `node_modules`, což zadání do autorské dávky nedává.

---

# Kolo 2 — po review (R1–R8)

Verdikt tří drah: `po úpravách`, nic blokujícího. Dodatek po review je na konci
`notes/impl/oprava-1-zadani.md`. Opravy jdou **jen do skriptů, hooku a dokumentace** —
částí jsem se nedotkl, takže celek 1 drží `7fabd487…bde8` (znovu doloženo v §K2.8).

Manifest očekávaných částí jsem **neimplementoval** — rozhodnutí vedení, zdůvodněné
v dodatku. Nahrazuje ho R8: mez je napsaná nahlas.

## K2.1 — R1: pod `frontend/partials/` smí být jen obyčejné `*.html`

`scripts/lib-partials.sh:23` `partials_collect()`. Prochází adresář s `dotglob`, takže
vidí i skryté položky, a **každá** položka, která není obyčejný nelinkový soubor
s malou příponou `.html`, je tvrdá chyba s vlastní hláškou a exit 2. `-L` se testuje
**před** `-d`/`-f`, protože ty symlink následují a odkaz na adresář nebo na `.html`
soubor by jinak prošel jako ta věc.

Ověřeno v izolované kopii, pro každý případ čerstvý strom, **oba skripty**:

| případ | hláška (oba skripty, exit 2) |
|---|---|
| podadresář `partials/settings/` s markupem | `subdirectory in partials: … (the build does not recurse)` |
| `ln -s /etc/hostname 55-link.html` (adversariální únik) | `symbolic link in partials: … (only plain files belong here)` |
| symlink na legitimní část | `symbolic link in partials: …` |
| `.40-discover.html.swp` | `hidden entry in partials: … (remove it or move it out)` |
| `55-x.HTML` | `not a .html file in partials: … (the extension is lowercase)` |
| `55-x.htm` | `not a .html file in partials: …` |
| adresář jménem `55-x.html` | `subdirectory in partials: …` (ne `cat: Is a directory`) |
| FIFO jménem `55-x.html` | `not a regular file in partials: …` |
| prázdný adresář částí | `no partials found in …` |

**V žádném z nich se `static/index.html` nezměnil** — `build-index.sh` odmítne dřív,
než sáhne na cíl. Výpis: `…/scratchpad/autor/r1.txt`, 24 nenulových návratů
(12 případů × 2 skripty), jediný zelený je kontrolní běh.

## K2.2 — R4: zapisovatel vynucuje totéž co kontrolor

Místo zdvojení pravidel jsem je dal do `scripts/lib-partials.sh`, který **oba** skripty
sourcují. Shoda build/check tím přestává být slib a stává se strukturou: neexistuje
místo, kde by se mohly rozejít.

`build-index.sh:29` volá `partials_require_final_newline` před `cat`. Ověřeno: část bez
koncového novořádku → `build-index` exit 2, `index.html` nedotčený (dřív zapsal slepený
soubor s exit 0 a teprve hradlo ho odmítlo).

## K2.3 — R5: hlášky

- **nečitelná část** (`chmod 000`): `partial is not readable: frontend/partials/40-discover.html`,
  exit 2. Dřív syrové `tail: Permission denied` a exit 1. Řeší to explicitní `[ -r ]`
  v `partials_collect`; navíc `partials_require_final_newline` testuje
  `if ! last="$(tail -c 1 -- "$partial")"`, takže selhání čtení neprojde jako „prázdné".
- **prázdná část**: `partial is empty: … (delete it, or put the markup back)` — už žádná
  rada o chybějícím novořádku, která pro prázdný soubor nedává smysl.
- **adresář s příponou `.html`**: `subdirectory in partials: …`, exit 2, místo `cat: Is a directory`.
- Cesty jsou ve všech hláškách obou funkcí ve stejném tvaru relativním ke kořeni.

## K2.4 — R2: hook kontroluje zastagovaný obsah

`.githooks/pre-commit` materializuje zastagované `frontend/partials` a
`static/index.html` přes `git ls-files -z | git checkout-index -z --stdin --prefix=`
do scratch stromu a pustí hradlo nad ním. Skripty bere z pracovního stromu — ony jsou
ten nástroj, který kontroluje; kontrolovaný je commitovaný obsah.

Doložený průchod toho obejití, oba stavy změřené na jednom stromě:

```
stage ruční editaci static/index.html, pak build-index.sh (uklidí pracovní strom)
  starý hook (kontrola pracovního stromu):   exit 0   <- pustil by to
  nový hook (kontrola zastagovaného obsahu): exit 1   <- blokuje
```

End-to-end v jednorázovém repu s `core.hooksPath .githooks`:

| # | scénář | výsledek |
|---|---|---|
| H1 | čistý strom | commit prošel, exit 0 |
| H2 | zastagovaná ruční editace + `build-index.sh` | **commit exit 1**, `data-smuggled` se do HEADu nedostal (`grep -c` = 0) |
| H3 | zastagovaná jen část, `index.html` nechaný starý | **commit exit 1** |
| H5 | část rozeditovaná v pracovním stromě, ale nezastagovaná | commit prošel, exit 0 |

H5 je záměr, ne díra: hook soudí to, co jde do historie.

## K2.5 — R3: hook mlčí tam, kde dávka není

`.githooks/pre-commit:27` — `[ -z "$(git ls-files -- 'frontend/partials')" ] && exit 0`.

**Proč si to neodporuje s R2:** obě otázky se ptají **indexu**, ne disku. „Existuje
dávka?" i „souhlasí obsah?" čtou tentýž zastagovaný strom, takže nemůže nastat stav,
kdy se hook rozhodne kontrolovat podle disku a pak kontroluje něco jiného.

Ověřeno (H4): commit na stromě bez zastagovaného `frontend/` prošel, exit 0, hradlo
nevypsalo ani řádek.

## K2.6 — R6: `README.md:110`

Dnes: `- **No build step** — single HTML shell generated from `frontend/partials/`,
vanilla JS modules`. „No build step" ponecháno — za běhu se pořád nic nesestavuje.

## K2.7 — R8: mez napsaná nahlas

Dvě místa, obě s konkrétní reprodukcí (`rm 90-full-player.html` → build → check zelené,
`#fullPlayer` pryč):

- hlavička `scripts/check-index.sh`, blok „WHAT A GREEN RESULT MEANS, AND WHAT IT DOES NOT"
- `docs/architecture.md`, podsekce „What a green `check-index.sh` proves"

Obojí říká totéž: hradlo dokazuje **shodu** obou reprezentací, ne zachování obsahu;
smazanou část chytí diff, ne hradlo; manifest byl zvážen a vědomě zamítnut.

Úspěšná hláška hradla to navíc pojmenovává na jeden řádek:
`agrees with 16 partials (agreement only — a deleted partial also agrees; see the header)`.
To už dodatek nežádal; přidal jsem to proto, že člověk, kterého R8 chrání, uvidí
nejdřív výstup a teprve pak hlavičku.

## K2.8 — co drží z kola 1

| kontrola | výsledek |
|---|---|
| M0–M7 (původní sada) proti novým skriptům | M0 zelená, M1–M6 exit 1, M7 exit 2; `index.html` ve všech 7 bězích nedotčený |
| oddělitelnost celků (nově i s `README.md` a `lib-partials.sh`) | plný strom `b2d78fd6…`, po odebrání celku 2 `7fabd487…bde8` = reference; hradlo v osekaném stromě exit 0 |
| celek 2 = 1 řádek | `git diff --numstat -- static/index.html` → `1  0` |
| `pytest tests/ -q` | 39 passed, 3 skipped (shodné s výchozím stavem) |
| spuštění přes dash | `sh scripts/build-index.sh` i `check-index.sh` → exit 2, `index.html` nedotčený |

Harness kola 1 jsem musel opravit: měl zadrátovaný hash celku 1, takže po celku 2
hlásil „MUTATED BY GATE" u všech běhů včetně kontrolního. Byla to chyba měřidla, ne
skriptů — po opravě konstanty je ve všech 7 bězích „untouched".

## K2.9 — přiznané meze kola 2

1. **R1 kontroluje jmennou a typovou podobu, ne obsah.** Obyčejný `.html` soubor
   s čímkoli uvnitř projde — a musí, je to zdrojový tvar dokumentu.
2. **Hook se nespustí bez `git config core.hooksPath .githooks`.** To je vlastnost gitu,
   ne tohoto řešení, a je to přesně důvod, proč celek 2 nese i ten komentář v dokumentu.
3. **Hook kontroluje celý zastagovaný strom, ne jen dotčené soubory.** Commit, který se
   dávky vůbec netýká, přesto spadne, pokud je `index.html` rozejitý. Považuju to za
   správné (nerozejitost je vlastnost větve, ne commitu), ale je to volba.
4. **`shellcheck` tu není nainstalovaný**, takže skripty neprošly statickou kontrolou —
   jen ručním čtením a těmi 13 negativními případy.
5. **Pořád to nikdo neviděl v prohlížeči.** Platí mez č. 1 z kola 1; kolo 2 na vykreslený
   dokument nesáhlo vůbec (jediný řádek, který celek 2 přidává, je z kola 1).
6. **Scratch strom hooku jde přes `mktemp -d` v `$TMPDIR`.** Na stroji, kde je `/tmp`
   plné nebo `noexec`, hook selže — selže ale uzavřeně (commit neprojde), ne tiše.
