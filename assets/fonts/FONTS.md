# Fonts

Both families shipped with Open Rhythm are licensed under the **SIL Open Font
License, Version 1.1**. The OFL allows bundling and redistribution inside a
project like this one, including commercial use, as long as the licence travels
with the fonts.

| File | Family | Author | Licence |
|---|---|---|---|
| `Orbitron-Variable.ttf` | Orbitron | Matt McInerney | OFL 1.1 |
| `Rajdhani-Bold.ttf`, `Rajdhani-SemiBold.ttf` | Rajdhani | Indian Type Foundry | OFL 1.1 |
| `Exo2-Variable.ttf` | Exo 2 | The Exo 2 Project Authors | OFL 1.1 |
| `ORFallback-Subset.ttf` | cut from Noto Sans SC and Noto Sans Symbols 2 | Google | OFL 1.1 |

## Why there are four

Rajdhani writes the game and Orbitron writes the logo, and between them they
have not one Cyrillic letter, no Chinese, no arrows and no eighth note. On a
desktop or a phone that never showed: the engine quietly borrows a system font
for anything its own cannot draw. A browser has nothing to lend, and the web
build printed the Russian translation as boxes with hex codes inside them.

So Exo 2 rides along for Cyrillic, and `ORFallback-Subset.ttf` for the rest.
That last one is not a font anybody published - it is cut by
`tools/gen_fontpack.py` down to the six hundred characters the game's own text
actually uses, out of the thirty thousand a CJK face carries. 157 KB instead of
18 MB, on a download that is 21 MB in total.

**Rerun `tools/gen_fontpack.py` after adding UI text in Chinese, or any new
symbol.** CoreTest fails if the fallback has fallen behind the text, and says
so by name.

## Licences

`OFL-Exo2.txt`, `OFL-NotoSansSC.txt` and `OFL-NotoSansSymbols2.txt` are here,
taken from those families' own releases. **Orbitron and Rajdhani are still
missing theirs** — the OFL requires the full text to travel with the fonts, so
before the next release drop their canonical `OFL.txt` in as well:

* Orbitron — <https://github.com/theleagueof/orbitron>
* Rajdhani — <https://github.com/itfoundry/rajdhani>

The canonical licence text is also published at
<https://openfontlicense.org/open-font-license-official-text/>.

Reserved Font Names must not be changed: if you modify a font file, rename it
before redistributing it.
