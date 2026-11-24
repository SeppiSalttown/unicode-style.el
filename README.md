# unicode-style.el (v0.42.2)

[![Version](https://shields.io)](https://github.com)
[![MELPA](https://melpa.org)](https://melpa.org)
[![License: GPL v3](https://shields.io)](https://gnu.org)

> **Documentation Version:** `0.42.2`

Transform selected text regions in Emacs into Unicode Mathematical Alphanumeric styles, enclosed characters (bubble, square, keycap), superscripts/subscripts, combining underlines/overlines/strikethroughs, diacritics, vector arrows, language-specific quotation marks, and typographic/fullwidth punctuation—ready to copy-paste anywhere plain text is supported (such as Signal, Slack, Discord, or social media).

## Features

- **16 Base & Enclosed Alphabet Styles:** Bold, Sans-Serif Bold, Italic, Bold Italic, Sans-Serif Italic, Sans-Serif Bold Italic, Monospace, Script, Bold Script, Double-Struck, Gothic (Fraktur), Bold Gothic, Bubble (`Ⓐⓑⓒ`), Black Bubble (`🅐🅑🅒`), Square (`🄰🄱🄲`), and Black Square (`🅰🅱🅲`).
- **Enclosed Multi-Digit Numbers (`10`–`20`) & Emoji Keycaps (`0`–`10`):** Standalone numbers `10`–`20` convert automatically to `⑩`–`⑳` (in `bubble` / `square`) and `⓫`–`⓴` (`11`–`20` in `bubble-black` / `square-black`). Dedicated `keycap` mode (`C-c u k`) turns `0`–`10` into `0️⃣`–`🔟`.
- **Language-Specific Quotation Marks (Region Toggle & On-the-Fly Mode):**
  - **Region Toggle (`C-c u '`):** Converts balanced straight `"` and `'` quotes in a region into locale-specific Unicode quotation marks (e.g., German `„…”` / `‚…‘`, English `“…”` / `‘…’`, French `« … »` / `‹ … ›`, Polish `„…”` / `‚…’`, Russian/Ukrainian `«…»` / `„…“`), leaving any unbalanced trailing quote untouched, or toggles them back to straight ASCII quotes. Use `C-u C-c u '` to pick a target language interactively.
  - **Live Smart Quotes Mode (`C-c u ,`):** Toggles `unicode-style-smart-quotes-mode` so typed `"` and `'` automatically insert locale-specific opening and closing Unicode quotation marks on the fly.
- **Superscript & Subscript:** Maps letters, digits, `+`, `-`, `=`, `(`, and `)` into Unicode superscript (`⁽ˣ⁺²⁾²`) and subscript (`H₂O`) positions.
- **Smooth Underlines & Continuous Display:** Uses `U+035F` (*Combining Double Macron Below*) by default to bridge cleanly across characters in external apps, automatically trims the trailing `U+035F` so the final character doesn't overhang, and includes `global-unicode-style-visual-mode` to render unbroken continuous lines inside Emacs.
- **Full Multilingual Typography (26 Languages):** Preserves native accents, diacritics, ligatures, special letters, and punctuation across **all 24 official EU languages plus Ukrainian and Russian** when styling or reverting to plain text (`C-c u a`), alongside a dedicated 7-bit ASCII transliteration command (`C-c u A`).
- **Combinable Styles:** Stack any base style with any line decoration, accent, or vector arrow via `C-c u RET` (e.g., `bold-underline`, `italic-right-arrow`, `gothic-overline`).

## Supported Languages (26 Total)

`unicode-style.el` preserves native spelling, diacritics, non-decomposing letters, and punctuation during styling/reversion, selects locale-appropriate quotation marks, and provides full transliteration in strict ASCII mode (`C-c u A`) for:

- **All 24 Official EU Languages:** Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish, French, German, Greek, Hungarian, Irish, Italian, Latvian, Lithuanian, Maltese, Polish, Portuguese, Romanian, Slovak, Slovenian, Spanish, and Swedish.
- **Additional Languages:** Ukrainian and Russian.

## Installation

### From MELPA (once published)

```elisp
(use-package unicode-style
  :ensure t
  :bind-keymap ("C-c u" . unicode-style-prefix-map)
  :config
  (global-unicode-style-visual-mode 1))
```

### Manual Installation

1. Save `unicode-style.el` to a directory in your Emacs `load-path` (e.g., `~/.emacs.d/lisp/`).
2. Add the following to your `init.el`:

```elisp
(add-to-list 'load-path "~/.emacs.d/lisp")
(require 'unicode-style)
(global-set-key (kbd "C-c u") 'unicode-style-prefix-map)
(global-unicode-style-visual-mode 1)
```

### Using `use-package` (Local File)

```elisp
(use-package unicode-style
  :load-path "~/.emacs.d/lisp"
  :bind-keymap ("C-c u" . unicode-style-prefix-map)
  :custom
  (unicode-style-underline-char #x035F)
  (unicode-style-trim-trailing-double-underline t)
  (unicode-style-underline-spaces t)
  (unicode-style-continuous-display t)
  (unicode-style-quote-language 'auto)
  (unicode-style-default-quote-language "de")
  :config
  (global-unicode-style-visual-mode 1))
```

## Usage & Keybindings

Highlight a region of text and press `C-c u <key>` (or toggle live modes directly):

### Alphabet & Font Styles

| Key | Command | Input | Output |
| :--- | :--- | :--- | :--- |
| `C-c u b` | `unicode-style-toggle-bold` | `Hello 123` | `𝐇𝐞𝐥𝐥𝐨 𝟏𝟐𝟑` *(toggles)* |
| `C-c u B` | `unicode-style-sans-bold` | `Hello 123` | `𝗛𝗲𝗹𝗹𝗼 𝟭𝟮𝟯` |
| `C-c u i` | `unicode-style-italic` | `Hello` | `𝐻𝑒𝑙𝑙𝑜` |
| `C-c u I` | `unicode-style-bold-italic` | `Hello` | `𝑯𝒆𝒍𝒍𝒐` |
| `C-c u j` | `unicode-style-sans-italic` | `Hello` | `𝘏𝘦𝘭𝘭𝘰` |
| `C-c u J` | `unicode-style-sans-bold-italic` | `Hello` | `𝙃𝙚𝙡𝙡𝙤` |
| `C-c u m` | `unicode-style-monospace` | `Hello 123` | `𝙷𝚎𝚕𝚕𝚘 𝟷𝟸𝟹` |
| `C-c u c` | `unicode-style-script` | `Hello` | `ℋℯ𝓁𝓁ℴ` |
| `C-c u C` | `unicode-style-bold-script` | `Hello` | `𝓗𝓮𝓵𝓵𝓸` |
| `C-c u d` | `unicode-style-double-struck` | `Hello 123` | `ℍ𝕖𝕝𝕝𝕠 𝟙𝟚𝟛` |
| `C-c u g` | `unicode-style-gothic` | `Straße` | `𝔖𝔱𝔯𝔞ß𝔢` |
| `C-c u G` | `unicode-style-bold-gothic` | `Straße` | `𝕾𝖙𝖗𝖆ß𝖊` |

### Enclosed Styles (Bubble, Square & Keycap)

| Key | Command | Input | Output |
| :--- | :--- | :--- | :--- |
| `C-c u w` | `unicode-style-bubble` | `Abc 12 20` | `Ⓐⓑⓒ ⑫ ⑳` |
| `C-c u W` | `unicode-style-bubble-black` | `Abc 12 20` | `🅐🅑🅒 ⓬ ⓴` |
| `C-c u q` | `unicode-style-square` | `Abc 12 20` | `🄰🄱🄲 ⑫ ⑳` |
| `C-c u Q` | `unicode-style-square-black` | `Abc 12 20` | `🅰🅱🅲 ⓬ ⓴` |
| `C-c u k` | `unicode-style-keycap` | `0 5 10` | `0️⃣ 5️⃣ 🔟` |

### Superscript & Subscript

| Key | Command | Input | Output |
| :--- | :--- | :--- | :--- |
| `C-c u ^` | `unicode-style-superscript` | `(x+2)^2` | `⁽ˣ⁺²⁾²` |
| `C-c u _` | `unicode-style-subscript` | `H2O + x(i)` | `H₂O + ₓ₍ᵢ₎` |

### Quotation Marks (Region Toggle & On-the-Fly Mode)

| Key | Command | Description |
| :--- | :--- | :--- |
| `C-c u '` | `unicode-style-toggle-quotes` | Toggle balanced `"` and `'` in region to locale Unicode quotes (`„…”`, `“…”`, `« … »`, etc.) and back; unbalanced trailing quotes stay unchanged. Prefix `C-u` prompts for language. |
| `C-c u ,` | `unicode-style-toggle-smart-quotes-mode` | Toggle buffer-local `unicode-style-smart-quotes-mode` to convert typed `"` and `'` into locale Unicode quotes on the fly. |

### Lines, Underlines & Visual Mode

| Key | Command | Input | Output |
| :--- | :--- | :--- | :--- |
| `C-c u u` | `unicode-style-underline` | `Hello World` | `H͟e͟l͟l͟o͟ ͟W͟o͟r͟l͟d` |
| `C-c u U` | `unicode-style-double-underline` | `Hello` | `H̳e̳l̳l̳o̳` |
| `C-c u o` | `unicode-style-overline` | `Hello` | `H̅e̅l̅l̅o̅` |
| `C-c u s` | `unicode-style-strikethrough` | `Hello` | `H̶e̶l̶l̶o̶` |
| `C-c u v` | `global-unicode-style-visual-mode` | — | Toggle continuous line overlays globally |
| `C-c u V` | `unicode-style-toggle-visual-size-limit` | — | Toggle optional 500 KB buffer size cap |
| `C-c u =` | `unicode-style-compose-underlines` | — | Compose continuous line overlays in region |
| `C-c u +` | `unicode-style-decompose-underlines` | — | Remove overlays to inspect raw glyphs |

### Diacritics & Vector Arrows

| Key | Command | Input | Output |
| :--- | :--- | :--- | :--- |
| `C-c u "` | `unicode-style-umlaut` | `aou` | `äöü` |
| `C-c u >` | `unicode-style-right-arrow` | `AB` / `v` | `A⃗B⃗` / `v⃗` |
| `C-c u <` | `unicode-style-left-arrow` | `AB` / `v` | `A⃖B⃖` / `v⃖` |
| `C-c u ~` | `unicode-style-left-right-arrow` | `AB` / `v` | `A⃡B⃡` / `v⃡` |

Additional diacritics (`acute`, `grave`, `circumflex`, `tilde`, `macron`, `breve`, `dot-above`, `ring`, `double-acute`, `caron`, `comma-below`, `cedilla`, `ogonek`) are available via `C-c u RET`.

### Punctuation, Brackets & Reversion

| Key | Command | Description |
| :--- | :--- | :--- |
| `C-c u p` | `unicode-style-fullwidth-punct` | Convert ASCII punctuation to Fullwidth (`！？，．`) |
| `C-c u P` | `unicode-style-fancy-punct` | Convert `...` → `…`, `!?` → `‽`, `!!` → `‼`, `??` → `⁇`, `--` → `—` |
| `C-c u (` | `unicode-style-brackets` | Convert brackets to `【】`, `〖〗`, `〔〕`, `〈〉`, `「」`, `⁽⁾`, or `₍₎` |
| `C-c u RET` | `unicode-style-region` | Prompt with completion for any style, quotes, or combination (`bold-underline`, etc.) |
| `C-c u a` | `unicode-style-to-ascii` | Revert styled text to plain text (preserves native orthography across all 26 languages) |
| `C-c u A` | `unicode-style-to-strict-ascii` | Transliterate all Latin, Greek, and Cyrillic letters, quotes, and punctuation to pure 7-bit ASCII |
| `C-c u r` | `unicode-style-toggle-cyrillic-transliteration` | Toggle strict-ASCII Cyrillic rules between Ukrainian (`'uk`, default) and Bulgarian/Russian (`'ru-bg`) |

### Customization

| Variable | Default | Description |
| :--- | :--- | :--- |
| `unicode-style-underline-char` | `#x035F` | Combining mark for `C-c u u` (`#x035F`, `#x0332`, `#x0331`, or `#x0333`) |
| `unicode-style-trim-trailing-double-underline` | `t` | Omit `U+035F` on the final character so the line stops flush |
| `unicode-style-underline-spaces` | `t` | Apply line decorations to spaces between words |
| `unicode-style-continuous-display` | `t` | Render continuous lines via non-intrusive Emacs overlays |
| `unicode-style-visual-max-buffer-size` | `nil` | Optional byte limit for visual mode (`nil` = unlimited) |
| `unicode-style-visual-size-limit-bytes` | `500000` | Byte threshold used when toggling size limit on via `C-c u V` |
| `unicode-style-quote-language` | `'auto` | Language for smart quotes (`'auto` detects dictionary/input method, or ISO code like `"de"`, `"en"`, `"fr"`) |
| `unicode-style-default-quote-language` | `"de"` | Fallback ISO language code for smart quotes when auto-detection finds none |
| `unicode-style-cyrillic-transliteration` | `'uk` | Cyrillic strict-ASCII scheme: `'uk` (Ukrainian, default: `И->Y, Г->H`) or `'ru-bg` (Bulgarian/Russian: `И->I, Г->G`) |

## License

This project is licensed under the GNU General Public License v3.0 or later — see the [LICENSE](LICENSE) file for details.
