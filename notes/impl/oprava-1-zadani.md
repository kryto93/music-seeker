# Oprava 1 — rozsekání statického frontendu

Vedení: hlavní session. Autor nepíše nic mimo svůj worktree.

## Nález

`static/index.html` má **1 760 řádků** markupu pro celou aplikaci v jednom souboru.
Dva bloky tvoří dvě třetiny (měřeno, ne odhad):

| řádků | blok |
|---|---|
| 653 | `#pageSettings` |
| 505 | `#fullPlayer` |
| 104 | `#pageSearch` |
| 85 | `#pageLibrary` |
| 80 | `#loginScreen` |
| 56 | `#downloadModal` |
| 55 | `#pagePlaylists` |
| 39 | `#pageDiscover` |
| 38 | `#playerBar` |
| 35 | `#pagePodcasts` |
| 13 | `#pageFavorites` |

Dohromady 21 modálů (`grep -c 'class="modal'`).

**Co NENÍ nález:** CSS je už rozsekané do 14 souborů, největší 394 řádků
(`static/css/search.css`). Do této dávky nepatří.

## Příčina

Žádná. Není to chyba, je to růst bez dělicích švů. Soubor vznikal přírůstkově a
nikdy se nerozdělil, protože projekt nemá build step a HTML nemá nativní include.

## Omezení (nevyjednatelná)

1. **Nulová změna chování.** Výsledný dokument, který dostane prohlížeč, musí být
   **bajt po bajtu shodný** s dnešním `static/index.html` (po dosazení `__CACHE_BUST__`).
   Toto je oracle celé dávky — není-li shoda bajtová, dávka neprošla.
2. **Žádný framework, žádná nová runtime závislost.** `jinja2` v `requirements.txt` není
   a touto dávkou tam nepřibude.
3. **Nesahat na:** `static/js/**`, `static/css/**`, `app/**` kromě případné jedné cesty,
   `desktop/**`, `.github/**`.
4. Autor **necommituje, nepushuje, nenasazuje**, nespouští deploy skripty.

## Body

### B1 — rozdělit `static/index.html` na části

Části do `static/partials/` s číslovaným pořadím (`00-head.html`, `10-login.html`, …),
aby bylo pořadí zřejmé ze jmen a sestavení bylo deterministické.

Dělicí švy (přesně tyto, žádné jemnější):
`head` · `loginScreen` · `nav` · `pageSearch` · `pageDiscover` · `pageLibrary` ·
`pagePlaylists` · `pagePodcasts` · `pageFavorites` · `pageSettings` · `playerBar` ·
`fullPlayer` · `modals` (všech 21 pohromadě) · `scripts`

`#pageSettings` (653 ř.) se dělí dál po `settings-group`.
`#fullPlayer` (505 ř.) se dělí dál na `fp-player`, `fp-queue`, `fp-dj-panel`.

### B2 — sestavení bez nové závislosti

Sestavení probíhá v `entrypoint.sh` **před** dosazením `__CACHE_BUST__` (dnes ř. 13):
části se spojí do `static/index.html`. Důvod volby viz „Otevřené volby" níže.

`static/index.html` se tím stává **generovaným souborem** — autor to zaznamená do
`.gitignore` **a** do `docs/architecture.md`, jinak příští session bude editovat soubor,
který se při startu přepíše.

### B3 — hradlo shody

Skript `scripts/check-index.sh`, který sestaví části a porovná s referenčním otiskem
dnešního `index.html` (uloženým v repu jako `notes/impl/oprava-1-index.sha256`).
Vrací nenulový kód při rozdílu a vypíše `diff`.

## Ověření místo mutací

Repo **nemá testovou sadu, TypeScript ani mutační nástroj** — `pnpm test`, `tsc --noEmit`
ani vitest tu neexistují. Mutace se proto dělají nad hradlem B3, které je pro refaktor
bez změny chování silnější oracle než jakýkoli test:

| # | mutace | co musí zčervenat |
|---|---|---|
| M1 | smazat jednu část ze `static/partials/` | `check-index.sh` → nenulový kód |
| M2 | prohodit pořadí dvou částí | `check-index.sh` → nenulový kód |
| M3 | změnit jeden znak uvnitř části (např. `id="playerBar"` → `id="playerBar "`) | `check-index.sh` → nenulový kód |
| M4 | přidat na konec části prázdný řádek | `check-index.sh` → nenulový kód |
| M5 | sestavit, ale vynechat dosazení `__CACHE_BUST__` | hradlo projde (správně — bust je mimo rozsah), ale `grep __CACHE_BUST__` v sestaveném souboru musí najít shodu |

Kontrolní běh bez mutace musí být zelený **před** celou sadou.

**D18:** hradlo musí nad dnešním stromem (před rozdělením) projít triviálně a po každé
mutaci spadnout — autor doloží oba stavy.

## Přejímka

Proti běžící instanci po merge a restartu:
1. `GET /` vrátí dokument, jehož sha256 (po normalizaci `?v=` bustu) odpovídá
   referenci z `notes/impl/oprava-1-index.sha256`.
2. Projít všech 7 stránek (`pageSearch`…`pageSettings`), otevřít full player a DJ panel,
   otevřít 3 modály. Snímky do `snimky/`, názvy podle tvrzení.
3. Konzole bez chyb; žádný 404 na statiku.
4. Rozpočet placených volání: **0** (vše je statika a lokální instance).

## Otevřené volby pro Lukáše

**A1 — kde se index sestavuje** (vedení volí (a), Lukáš může změnit před mergem):

| | cena | ztráta |
|---|---|---|
| **(a) `entrypoint.sh` při startu** ← zvoleno | ~5 řádků shellu | `index.html` v repu je generovaný; kdo ho edituje ručně, přijde o změnu |
| (b) Jinja2 `{% include %}` | nová závislost, `FileResponse` → `TemplateResponse`, šablonování za běhu | runtime náklad na každý požadavek, nová vrstva v produkci |
| (c) krok v `Dockerfile` | build-time, čistší než (a) | části se musí dostat do image i při lokálním běhu bez Dockeru |

Důvod pro (a): drží dnešní model „FastAPI servíruje jeden statický soubor", nepřidává
závislost, a sedí vedle existujícího `sed` na `__CACHE_BUST__` na témže řádku životního cyklu.

**A2 — rozsekat i JS?** (vedení volí **ne**)
`library.js` 1 279 ř., `settings.js` 1 147 ř., `player_v3.js` 2 190 ř. jsou také velké.
Ale pro JS **neexistuje bajtový oracle** a repo nemá testovou sadu — rozdělení modulu je
změna chování, dokud se neprokáže opak. Jiná třída rizika, patří do vlastní dávky
s vlastním ověřením. Do této dávky nepatří.

---

# Dodatek po kritice (2026-10-16)

**Verdikt kritiky: `po úpravách`.** Dodatek má přednost před původním zněním výše.
Kde si odporují, platí dodatek. Body původního zadání, které tu nejsou zmíněné, platí.

## 0. Opravy chyb vedení

Tohle jsem v zadání napsal špatně. Ověřeno nezávisle vedením i kritikou:

| tvrzení v zadání | skutečnost |
|---|---|
| `#fullPlayer` 505 ř. | **139 ř.** (1256–1394) |
| `#loginScreen` 80 ř. | **19 ř.** (98–116) |
| „dva bloky = 66 % souboru" | **44,8 %** — a jsou to jiné dva bloky, viz níže |
| „21 modálů" | **1** `modal-overlay` (`#downloadModal`); 21 je počet tříd `modal-*` uvnitř něj. Dalších 13 modálů staví JS za běhu |
| `#fullPlayer` dělit na `fp-queue` | `#fpQueuePanel` (1413–1425) leží **za** uzávěrem `#fullPlayer` — nejde |
| `settings-group` = 12 | **4** skutečné skupiny (512, 852, 1021, 1113) |
| „repo nemá testovou sadu" | **42 pytest testů** v `tests/`. Správně: neexistuje `pnpm test`, `tsc` ani mutační nástroj, a pytest **netestuje frontend** (download perms, navidrome admin, slskd, ytpick) |

Měřil jsem mezery mezi značkami, ne rozsahy elementů. Závěr o mutacích nad bajtovým
hradlem platí dál, ale jeho odůvodnění bylo postavené na nepravdě a tímto se opravuje.

**Skutečné složení souboru** (1 760 ř.):

| ř. | % | blok |
|---|---|---|
| 649 | 36,9 | `#pageSettings` (509–1157) |
| 317 | 18,0 | **inline `<script>` 1442–1758** |
| 186 | 10,6 | podstrom `#pageLibrary` |
| 139 | 7,9 | `#fullPlayer` |
| 102 | 5,8 | `#pageSearch` |
| 97 | 5,5 | `head` (z toho inline `<style>` 24–93 = 70 ř.) |

## 1. A1 se mění z (a) na (d) — rozhodnutí vedení

Kritika našla variantu, kterou zadání nemělo, a která je přísně bezpečnější než
všechny tři nabízené:

**(d) Sestavovat lokálně skriptem. `static/index.html` zůstává trackovaný v gitu.
`entrypoint.sh` ani `app/__init__.py` se nedotknou vůbec.**

Důvod: ruší tři vysoké nálezy naráz, aniž by za to něco vyměnila.

- **N1** (sestavení utne soubor na 0 B a kontejner nastartuje dál — `entrypoint.sh`
  nemá `set -e` ani `set -u`, ověřeno) — **odpadá**, za běhu se nic nesestavuje.
- **N2** (`.gitignore` na trackovaný soubor nic neudělá; po `git rm --cached` by deploy
  začal záviset na tom, co má autor na disku) — **odpadá**, soubor zůstává trackovaný.
- **N7** (dnešní `sed` je jednorázový — ověřeno: druhý průchod nedělá nic, takže
  `docker restart` bust nebumpne; po (a) by se regeneroval a bumpoval při každém
  startu, navíc nesoulad s `?v=` uvnitř `static/js/*.js`) — **odpadá**, chování
  cache bustu zůstává bit po bitu dnešní.

Runtime, deploy i revert zůstávají beze změny. Lukáš může před mergem změnit.

## 2. Hradlo se předefinovává (N9, N8)

Původní B3 porovnával proti zamražené sha256. To by od příštího legitimního commitu
do frontendu červenalo navždy. Nově:

- **Trvalé hradlo** `scripts/check-index.sh`: sestaví části a porovná s **aktuálním
  `static/index.html` v repu**. Tvrzení = „části a sestavený soubor jsou v souladu".
  Přežije všechny budoucí změny frontendu.
- **`scripts/build-index.sh`**: sestaví části → `static/index.html`. Tohle se pouští
  po každé editaci části.
- **Jednorázová migrační kontrola této dávky**: sestavený soubor se musí rovnat
  sha256 z `notes/impl/oprava-1-index.sha256`
  (`7fabd48756bc0bf9b655cc999623759e8961b85dda9f39dcb0c6cebcb133bde8`).
  Tím je D18 vyřešené: před rozdělením se porovnává existující soubor proti referenci.

## 3. Části jdou mimo `static/` (N6)

`app/__init__.py:78` mountuje `StaticFiles(directory="static")` bez autentizace —
ověřeno, `/static/css/base.css` vrací HTTP 200. Části pod `static/` by byly veřejně
dostupné jako druhá, rozbitá kopie markupu s nenahrazeným `__CACHE_BUST__`.

**Části patří do `frontend/partials/`**, mimo mount. Deploy je veze (`tar` celého
stromu), do image se dostanou, runtime se jich nedotkne.

## 4. Části jsou rozklad řádků, ne přepis (N4)

**Pravidlo: části jsou souvislé úseky původního souboru v původním pořadí. Žádný
řádek se nepřidává, nemaže, nepřeformátovává ani neposouvá.** Bajtová shoda je pak
triviálně dosažitelná a zbývá jediná otázka — kde vést hranice.

Kritika má pravdu, že švy protínají otevřené elementy: `#appContainer` (119–1159)
obaluje nav i všech sedm stránek, `.settings-form` (511–1019) obaluje jen první dvě
skupiny. **Důsledek, který se tímto přiznává: žádná část nebude samostatně validní
HTML.** To je u konkatenace nevyhnutelné a je to přijatelné — cílem je navigovatelnost,
ne izolovaná validita. Nespárovaný uzavírací tag patří do té části, ve které textově
leží; nikdo ho nikam nepřelepuje.

## 5. Švy — kotvy, ne čísla řádků

Autor si rozsahy odvodí sám a dokládá je hradlem; čísla níže jsou orientační kontext
(a jednou už jsem je spočítal špatně). Každá část **začíná** na uvedené kotvě:

`head` · `#loginScreen` · `nav` · `#pageSearch` · `#pageDiscover` · `#pageLibrary`
(včetně vnořených `#pagePlaylists`, `#pagePodcasts`, `#pageFavorites`) ·
`#pageSettings` · `#downloadModal` · `#playerBar` · `#fullPlayer` ·
`#fpQueuePanel` + `#downloadsPanel` · `scripts`

- `#pageSettings` (649 ř.) se dělí dál na **4** skutečné `settings-group`
  (kotvy na ř. 512, 852, 1021, 1113). Největší výsledná část vyjde ~339 ř. —
  přijatelné, je to méně než 394 ř. `static/css/search.css`, které zadání vyřadilo.
- **Inline `<script>` (1442–1758, 317 ř.) dostane vlastní část a ZŮSTÁVÁ INLINE.**
  Je inline schválně („no module dependency" — update checker musí běžet i při selhání
  modulového grafu). Převod na `.js` soubor by rozbil bajtový oracle a byl by to zásah
  do chování. Patří do vlastní dávky, pokud vůbec.
- **Předpony jsou vždy dvouciferné** (`00-`, `10-`, …). Ověřeno: glob i `ls` řadí
  `5-x.html` **za** `10-x.html` v `LC_ALL=C` i `cs_CZ.UTF-8`.

## 6. Mutace — aktualizováno

M1–M4 platí beze změny, cílem je `scripts/check-index.sh`. M5 odpadá (cache bust se
už netýká). Přibývá:

| # | mutace | co musí zčervenat |
|---|---|---|
| M6 | přejmenovat `20-nav.html` na `5-nav.html` | hradlo → nenulový kód (špatné pořadí z globu) |
| M7 | odstranit koncový novořádek z jedné části | hradlo → nenulový kód |

Kontrolní běh bez mutace zelený **před** sadou. Mutace v izolované kopii, ne ve worktree.

## 7. Přejímka — zjednodušená

Protože runtime se nemění, přejímka dokládá hlavně „nezměnilo se nic":
1. `GET /` po merge a restartu → sha256 po normalizaci `?v=[0-9]+` se rovná referenci.
2. Projít 7 stránek, full player, DJ panel, 3 modály. Snímky do `snimky/`.
3. Konzole bez chyb, žádný 404 na statiku.
4. `/static/partials/` **neexistuje** (404) — doklad k N6.
5. Rozpočet placených volání: 0.

---

# Dodatek po kritice — část 2 (2026-10-16)

Kritika dorazila na tři zprávy; tohle je zbytek. Přednost: dodatek 2 > dodatek 1 > původní.

## 8. Dávka se dělí na DVA celky

Kritika správně ukazuje, že (d) nepřidává produkční riziko, ale přidává jedno
neviditelné: `static/index.html` zůstane trackovaný, 1 760 řádků dlouhý a **bez
jakékoli značky, že je generovaný** — protože bajtový oracle zakazuje do něj cokoli
přidat. Někdo ho upraví, nasadí, funguje; části zůstanou staré; kdo pak pustí
`build-index.sh`, tu úpravu **tiše vrátí**. V gitu to vypadá jako revert bez autora.

Ověřeno vedením, že to nic nezachytí: aktivní hooky **žádné**, `core.hooksPath`
**nenastaveno**, `.pre-commit-config.yaml` **neexistuje**, `.gitattributes`
**neexistuje**, a `build-desktop.yml` má jen `version`/`build-macos`/`build-linux`/
`package-arch`/`build-android` — **žádný job nad repem**.

Řešení zachovává perfektní oracle tam, kde na něm záleží, a značku dává zvlášť:

**Celek 1 — rozdělení.** Bajtově shodné. `sha256(static/index.html)` se nesmí hnout
z `7fabd48756bc0bf9b655cc999623759e8961b85dda9f39dcb0c6cebcb133bde8`.
Obsahuje: `frontend/partials/**`, `scripts/build-index.sh`, `scripts/check-index.sh`.

**Celek 2 — pojistka proti driftu.** Smí a má bajty změnit, a to přesně o jeden řádek:
- HTML komentář na začátek `frontend/partials/00-head.html` (hned za `<!doctype html>`,
  aby byl první, co kdokoli v `index.html` uvidí) ve smyslu
  „generated from frontend/partials/ — run scripts/build-index.sh; do not edit directly".
  HTML komentář nemá žádný vliv na chování; diff v `static/index.html` musí být
  **přesně 1 přidaný řádek**, to je celé ověření tohoto celku.
- `.gitattributes` s `static/index.html linguist-generated=true`
- `.githooks/pre-commit` (verzovaný), který pouští `scripts/check-index.sh`,
  + řádek v docs, že se aktivuje `git config core.hooksPath .githooks`
- přepsat `docs/architecture.md:109` — dnes tam stojí
  „**Single HTML file** (`static/index.html`) with modular JS" — což po dávce neplatí.

**Pozor na pořadí:** celek 2 posune sha256. Migrační kontrola celku 1 se proto dělá
**před** aplikací celku 2, a autor ji doloží. Celky musí jít oddělit (metodika: ověřit
odebráním druhého ze stromu).

Důvod, proč komentář a ne jen hooky: `core.hooksPath` **není samodistribuující** —
po `git clone` ho musí každý nastavit ručně (ověřeno, dnes nenastaveno). Komentář vidí
každý, kdo soubor otevře, člověk i agent, s nulovým nastavováním.

## 9. Hradlo nesmí být tautologie (D-a)

- `scripts/build-index.sh` — **jediný**, kdo zapisuje do `static/index.html`.
- `scripts/check-index.sh` — sestaví do **dočasného** souboru a jen `cmp`.
  **Do `static/index.html` nikdy nezapisuje.** Kdyby nejdřív generoval do cíle a pak
  porovnával, projde vždycky a nehlídá nic.

## 10. Koncové novořádky jako samostatný krok (N11)

Soubor končí `</html>\n` (ověřeno `od -c`). Když editor jedné části koncový novořádek
sebere, `cat` slepí poslední řádek s prvním řádkem další části — v kritikově testu
**84 359 rozdílných bajtů ze 105 352**. Hradlo to chytí, ale diff bude nečitelný.

`check-index.sh` proto **před** porovnáním hashe samostatně ověří, že každá část končí
`\n`, s vlastní chybovou hláškou. Je to zároveň pravidlo pro autora, ne jen kontrola.

## 11. Regresní kontrola testy (oprava mého tvrzení)

Autor pustí `python3 -m pytest tests/ -q` před prací i po ní a uvede obě čísla.
Je to backendová sada (42 testů) a tahle dávka na backend nesahá — čísla se tedy
nesmí lišit. Moje původní věta „repo nemá testovou sadu" by autora vedla k tomu,
aby tuhle levnou regresní kontrolu přeskočil.

## 12. Úklid po dávce (D-c)

`notes/impl/oprava-1-index.sha256` je **jednorázová** migrační reference. Po přejímce
se maže; hash zůstává jako důkaz v `notes/impl/predavka-oprava-1.md`. Jinak ho příští
session najde a bude ho považovat za živou referenci.

## 13. Oprava zadání pro kritika (N12)

Worktree jsem kritikovi popsal jako „prázdný" — je to plný checkout větve
`oprava-1-rozsekani`. Bez dopadu na dávku, uvedeno pro pořádek.

---

# Dodatek po review (2026-10-16)

Všechny tři dráhy odevzdaly, verdikt shodně `po úpravách`, nic blokujícího.
Tohle je **jediný** dodatek za všechny tři — kolo autora začíná teprve teď (D25).

## Co review potvrdila (neměnit)

- Celek 1 bajtově shodný — ověřeno třikrát nezávisle, mimo jiné `cmp` proti
  `git show HEAD:static/index.html` → identical, a vedením proti živé produkci.
- Celek 2 = přesně 1 přidaný řádek.
- Hradlo není tautologie — nikdy nepřepsalo svůj cíl (měřeno před/po u 24 mutací).
- Žádná mutace nedala zelené hradlo **a zároveň** špatný `static/index.html`.
- 16 částí je souvislé rozsekání bez mezer a překryvů, součet 105 352 B.
- Nepřátelské názvy (mezera, apostrof, diakritika, novořádek, `$(id)`, `*`) neprojdou
  expanzí — pole jsou správně uvozená.
- Spuštění přes `sh`/dash selže uzavřeně (`pipefail`), index nedotčen.
- `pytest tests/ -q` = 39 passed, 3 skipped, před i po.

## Zjištění na úrovni návrhu, které mění, co o hradle tvrdíme

Adversariální dráha (bez zadání) ukázala sekvenci, kterou obě dráhy se zadáním minuly:

    rm frontend/partials/90-full-player.html
    ./scripts/build-index.sh     →  "wrote ... from 15 partials"
    ./scripts/check-index.sh     →  "matches 15 partials", exit 0
    index.html 1761 → 1604 ř., id="fullPlayer" pryč

**Hradlo dokazuje soulad částí a souboru, ne zachování obsahu.** Přestavění ho
uspokojí po jakékoli destruktivní změně. Ověřeno vedením.

## Požadavky kola 2

**R1 [střední] — pod `frontend/partials/` smí být jen obyčejné soubory `*.html`.**
Oba skripty musí odmítnout cokoli jiného, s vlastní hláškou a exit 2:
podadresář, symlink (`-type l`, nenásledovat), tečkou uvozený soubor, jinou příponu
včetně `.HTML`. Zavírá naráz: vlití cizího souboru do veřejného dokumentu
(`ln -s /etc/hostname …` → build i check zelené, obsah v dokumentu — ověřeno),
tiché ignorování nově přidaného markupu v `partials/settings/`, i překlep v příponě.
Tohle je **jediný tiše ztrácející režim**, a proto povinné.

**R2 [střední] — hook kontroluje ZASTAGOVANÝ obsah, ne pracovní strom.**
Dnes jde obejít bez `--no-verify`: `git add static/index.html` s cizí změnou,
pak `build-index.sh` (uklidí pracovní strom), pak commit → hook vidí „matches",
commit projde a v HEADu je ta cizí změna. Stejně tak `git add` jen části nechá
v HEADu starý `index.html`. Autor mez v komentáři přiznal — přiznání ji neruší.
Sestav kontrolu z `git show :cesta`, nebo `git stash -k`.

**R3 [střední] — hook mlčí tam, kde dávka neexistuje.**
Dnes `core.hooksPath` zablokuje **každý** commit na větvi bez `frontend/partials/`
(checkout starší větve, `git bisect`) — reprodukováno. Řádek před `exec`:
`[ -d "$root/frontend/partials" ] || exit 0`. Nesmí si odporovat s R2.

**R4 [nízká–střední] — `build-index.sh` vynucuje totéž pravidlo o koncových
novořádcích, které `check-index.sh` vyžaduje.** Dnes `cat` bez kontroly zapíše
slepený soubor s exit 0 a teprve hradlo ho odmítne. Zapisovatel nesmí umět vyrobit
stav, který kontrolor považuje za vadný.

**R5 [nízká] — hlášky:** nečitelná část (`chmod 000`) dnes vypíše jen syrové
`tail/cat: Permission denied` a vrátí 1 místo dokumentované 2 (`[ -n "$(tail …)" ]`
spolkne selhání, `set -e` nenaskočí). Prázdná část dostane radu „add the missing
final newline(s)", která pro ni nedává smysl. Adresář s příponou `.html` vrátí 1 a
holé `cat: Is a directory`.

**R6 [nízká] — `README.md:110`.** Dnes: `- **No build step** — single HTML file,
vanilla JS modules`. Po dávce neplatí „single HTML file". Návrh dráhy kód:
`single HTML shell generated from frontend/partials/`. „No build step" ponechat —
za běhu se pořád nic nesestavuje.

**R7 [nit] — evidence.** Doplnit do „Co jinak a proč" čtvrtou odchylku:
`99-scripts.html` obsahuje vedle inline scriptu i `<script type="module" src=…>`,
`</body>` a `</html>`. Nerozdělovat, jen přiznat.

**R8 [povinné, dokumentace] — napsat tu mez nahlas.** Do hlavičky
`check-index.sh` i do `docs/architecture.md`: hradlo tvrdí „části a `index.html`
jsou v souladu", **ne** „nic se neztratilo". Smazání části s následným přestavěním
projde. Příští člověk uvidí zelenou a musí vědět, co přesně znamená.

## Co se vědomě NEŽÁDÁ

**Manifest očekávaných částí.** Zavřel by i scénář smazání, ale smazání je v gitu
hlasité: ubyde soubor a v `index.html` zmizí 157 řádků — to review uvidí. Manifest
by byl třetí věc, kterou je nutné držet v souladu, a sám by se rozcházel.
Rozhodnutí vedení, ne opomenutí.

## Nezměněné

Otisk po kole 2 se přepočítá celý a ověřovací kolo mutuje **jen rozdíl** (přeživší
z minula + nové mutace nad změněnými řádky), ne znovu celou tabulku (D26).
