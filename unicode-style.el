;;; unicode-style.el --- Transform regions using Unicode styles and diacritics -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Josef Teske

;; Author: Josef Teske <Josef.Teske@directbox.com>
;; Maintainer: Josef Teske <Josef.Teske@directbox.com>
;; Version: 0.42.4
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, editing, unicode, text
;; URL: https://github.com

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://gnu.org>.

;;; Commentary:

;; Convert selected text in Emacs into Unicode Mathematical Alphanumeric
;; styles, enclosed characters (bubble, square, keycap), superscript/subscript,
;; combining decorations, diacritics, vector arrows, language-specific
;; quotation marks (on region or on the fly), and typographic punctuation.
;;
;; Supported languages (26 total — all 24 official EU languages plus
;; Ukrainian and Russian):
;;   Bulgarian, Croatian, Czech, Danish, Dutch, English, Estonian, Finnish,
;;   French, German, Greek, Hungarian, Irish, Italian, Latvian, Lithuanian,
;;   Maltese, Polish, Portuguese, Romanian, Russian, Slovak, Slovenian,
;;   Spanish, Swedish, and Ukrainian.
;;
;; Quotation mark options:
;;   - `unicode-style-toggle-quotes' (C-c u '): Convert balanced straight
;;     " and ' quotes in a region into locale-specific Unicode quotation marks
;;     (e.g., German „…” / ‚…‘, English “…” / ‘…’, French « … » / ‹ … ›),
;;     leaving any unbalanced trailing quote untouched, or revert back to ASCII.
;;     Use `C-u C-c u '' to pick a target language interactively.
;;   - `unicode-style-smart-quotes-mode' (C-c u ,): Toggle live on-the-fly
;;     conversion of typed " and ' into locale-specific Unicode quotes.
;;   - Configure language via `unicode-style-quote-language' (default `auto')
;;     and `unicode-style-default-quote-language' (default "de").
;;
;; Setup in your init.el:
;;
;;   (require 'unicode-style)
;;   (global-set-key (kbd "C-c u") 'unicode-style-prefix-map)
;;   (global-unicode-style-visual-mode 1)
;;
;; Available commands under `unicode-style-prefix-map':
;;
;;   𝐇𝐞𝐥𝐥𝐨  bold / toggle        (C-c u b)
;;   𝗛𝗲𝗹𝗹𝗼  sans-bold            (C-c u B)
;;   𝐻𝑒𝑙𝑙𝑜  italic               (C-c u i)
;;   𝑯𝒆𝒍𝒍𝒐  bold-italic          (C-c u I)
;;   𝘏𝘦𝘭𝘭𝘰  sans-italic          (C-c u j)
;;   𝙃𝙚𝙡𝙡𝙤  sans-bold-italic     (C-c u J)
;;   𝙷𝚎𝚕𝚕𝚘  monospace            (C-c u m)
;;   ℋℯ𝓁𝓁ℴ  script               (C-c u c)
;;   𝓗𝓮𝓵𝓵𝓸  bold-script          (C-c u C)
;;   ℍ𝕖𝕝𝕝𝕠  double-struck        (C-c u d)
;;   𝔊𝔬𝔱𝔥   gothic               (C-c u g)
;;   𝕲𝖔𝖙𝖍   bold-gothic          (C-c u G)
;;   Ⓐⓑⓒ    bubble / black       (C-c u w / W)
;;   🄰🄱🄲    square / black       (C-c u q / Q)
;;   0️⃣–🔟  keycap digits        (C-c u k)
;;   ˣ² / ₓ₂ superscript / sub    (C-c u ^ / _)
;;   H͟e͟l͟l͟o  underline / double   (C-c u u / U)
;;   H̅e̅l̅l̅o̅  overline             (C-c u o)
;;   H̶e̶l̶l̶o̶  strikethrough        (C-c u s)
;;   äöü    umlaut               (C-c u ")
;;   „…”   region quotes toggle (C-c u ')
;;   „“     live smart quotes    (C-c u ,)
;;   v⃗/v⃖/v⃡  vector arrows        (C-c u > / < / ~)
;;   … ‽ —  fancy / fullwidth    (C-c u P / p)
;;   【】   brackets             (C-c u ()
;;   Plain  revert / strict      (C-c u a / A)
;;   Cyr    toggle uk vs ru/bg   (C-c u r)
;;   Prompt any style / combo    (C-c u RET)

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'ucs-normalize)

(defgroup unicode-style nil
  "Transform selected regions into styled Unicode text."
  :group 'editing
  :prefix "unicode-style-")

(defcustom unicode-style-underline-char #x035F
  "Unicode combining character used by `unicode-style-underline'.
Common choices:
- #x035F (Combining Double Macron Below, default: bridges across letters)
- #x0332 (Combining Low Line: a̲b̲c̲)
- #x0331 (Combining Macron Below: a̱ḇc̱)
- #x0333 (Combining Double Low Line: a̳b̳c̳)"
  :type '(choice (const :tag "Combining Double Macron Below (U+035F)" #x035F)
                 (const :tag "Combining Low Line (U+0332)" #x0332)
                 (const :tag "Combining Macron Below (U+0331)" #x0331)
                 (const :tag "Combining Double Low Line (U+0333)" #x0333)
                 (character :tag "Custom combining character"))
  :group 'unicode-style)

(defcustom unicode-style-trim-trailing-double-underline t
  "When non-nil, omit trailing U+035F on the last character of a run.
This prevents the double-wide macron from overhanging past the final letter.
Single-character selections automatically fall back to U+0332."
  :type 'boolean
  :group 'unicode-style)

(defcustom unicode-style-underline-spaces t
  "When non-nil, apply line decorations to spaces between words."
  :type 'boolean
  :group 'unicode-style)

(defcustom unicode-style-continuous-display t
  "When non-nil, render combining line decorations continuously in Emacs."
  :type 'boolean
  :group 'unicode-style)

(defcustom unicode-style-visual-size-limit-bytes 500000
  "Byte threshold used when `unicode-style-visual-max-buffer-size' is toggled on."
  :type 'integer
  :group 'unicode-style)

(defcustom unicode-style-visual-max-buffer-size nil
  "Optional maximum buffer size in bytes for `global-unicode-style-visual-mode'.
When nil, continuous underline display runs in all buffers regardless of size.
When set to an integer, buffers larger than that limit are skipped."
  :type '(choice (const :tag "No size limit (enable in all buffers)" nil)
                 (integer :tag "Maximum buffer size in bytes"))
  :group 'unicode-style)

(defcustom unicode-style-quote-language 'auto
  "Language for smart quotes (`unicode-style-toggle-quotes').
When set to `auto', detects the language from `ispell-local-dictionary',
`ispell-dictionary', or `current-input-method', falling back to
`unicode-style-default-quote-language'."
  :type '(choice (const :tag "Auto-detect (fallback to default)" auto)
                 (string :tag "ISO language code (e.g. \"de\", \"en\", \"fr\")"))
  :group 'unicode-style)

(defcustom unicode-style-default-quote-language "de"
  "Fallback ISO language code for smart quotes when auto-detection finds none."
  :type 'string
  :group 'unicode-style)

(defcustom unicode-style-cyrillic-transliteration 'uk
  "Transliteration scheme for Cyrillic in `unicode-style-to-strict-ascii'.
- `uk' (default): Ukrainian rules (`И/и' -> `Y/y', `Г/г' -> `H/h').
- `ru-bg': Bulgarian/Russian rules (`И/и' -> `I/i', `Г/г' -> `G/g').
Toggle interactively via `unicode-style-toggle-cyrillic-transliteration'."
  :type '(choice (const :tag "Ukrainian (И->Y, Г->H)" uk)
                 (const :tag "Bulgarian / Russian (И->I, Г->G)" ru-bg))
  :group 'unicode-style)

(defconst unicode-style-quote-styles
  '(("bg" . ("„" "“" "‚" "‘"))   ; Bulgarian
    ("cs" . ("„" "“" "‚" "‘"))   ; Czech
    ("da" . ("»" "«" "›" "‹"))   ; Danish
    ("de" . ("„" "“" "‚" "‘"))   ; German
    ("el" . ("«" "»" "“" "”"))   ; Greek
    ("en" . ("“" "”" "‘" "’"))   ; English
    ("es" . ("«" "»" "“" "”"))   ; Spanish
    ("et" . ("„" "“" "‚" "‘"))   ; Estonian
    ("fi" . ("”" "”" "’" "’"))   ; Finnish
    ("fr" . ("«\u00A0" "\u00A0»" "‹\u00A0" "\u00A0›")) ; French (with NBSP)
    ("ga" . ("“" "”" "‘" "’"))   ; Irish
    ("hr" . ("„" "”" "‚" "’"))   ; Croatian
    ("hu" . ("„" "”" "»" "«"))   ; Hungarian
    ("it" . ("«" "»" "“" "”"))   ; Italian
    ("lt" . ("„" "“" "‚" "‘"))   ; Lithuanian
    ("lv" . ("„" "“" "‚" "‘"))   ; Latvian
    ("mt" . ("“" "”" "‘" "’"))   ; Maltese
    ("nl" . ("“" "”" "‘" "’"))   ; Dutch
    ("pl" . ("„" "”" "‚" "’"))   ; Polish
    ("pt" . ("«" "»" "“" "”"))   ; Portuguese
    ("ro" . ("„" "”" "«" "»"))   ; Romanian
    ("ru" . ("«" "»" "„" "“"))   ; Russian
    ("sk" . ("„" "“" "‚" "‘"))   ; Slovak
    ("sl" . ("„" "“" "‚" "‘"))   ; Slovenian
    ("sv" . ("”" "”" "’" "’"))   ; Swedish
    ("uk" . ("«" "»" "„" "“")))  ; Ukrainian
  "Alist mapping ISO 639-1 language codes to quote-pair lists.")

(defconst unicode-style-quote-dict-aliases
  '(("bulgarian"  . "bg")
    ("czech"      . "cs")
    ("danish"     . "da")
    ("dansk"      . "da")
    ("deutsch"    . "de")
    ("german"     . "de")
    ("greek"      . "el")
    ("english"    . "en")
    ("american"   . "en")
    ("british"    . "en")
    ("spanish"    . "es")
    ("espanol"    . "es")
    ("estonian"   . "et")
    ("finnish"    . "fi")
    ("suomi"      . "fi")
    ("french"     . "fr")
    ("francais"   . "fr")
    ("irish"      . "ga")
    ("gaeilge"    . "ga")
    ("croatian"   . "hr")
    ("hrvatski"   . "hr")
    ("hungarian"  . "hu")
    ("magyar"     . "hu")
    ("italian"    . "it")
    ("italiano"   . "it")
    ("lithuanian" . "lt")
    ("latvian"    . "lv")
    ("maltese"    . "mt")
    ("dutch"      . "nl")
    ("nederlands" . "nl")
    ("polish"     . "pl")
    ("polski"     . "pl")
    ("portuguese" . "pt")
    ("portugues"  . "pt")
    ("romanian"   . "ro")
    ("romana"     . "ro")
    ("russian"    . "ru")
    ("slovak"     . "sk")
    ("slovenian"  . "sl")
    ("slovene"    . "sl")
    ("swedish"    . "sv")
    ("svenska"    . "sv")
    ("ukrainian"  . "uk"))
  "Alist mapping dictionary/input-method prefixes to ISO 639-1 codes.")

(defconst unicode-style-maps
  `((ascii            . "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    (bold             . "𝐀𝐁𝐂𝐃𝐄𝐅𝐆𝐇𝐈𝐉𝐊𝐋𝐌𝐍𝐎𝐏𝐐𝐑𝐒𝐓𝐔𝐕𝐖𝐗𝐘𝐙𝐚𝐛𝐜𝐝𝐞𝐟𝐠𝐡𝐢𝐣𝐤𝐥𝐦𝐧𝐨𝐩𝐪𝐫𝐬𝐭𝐮𝐯𝐰𝐱𝐲𝐳𝟎𝟏𝟐𝟑𝟒𝟓𝟔𝟕𝟖𝟗")
    (sans-bold        . "𝗔𝗕𝗖𝗗𝗘𝗙𝗚𝗛𝗜𝗝𝗞𝗟𝗠𝗡𝗢𝗣𝗤𝗥𝗦𝗧𝗨𝗩𝗪𝗫𝗬𝗭𝗮𝗯𝗰𝗱𝗲𝗳𝗴𝗵𝗶𝗷𝗸𝗹𝗺𝗻𝗼𝗽𝗾𝗿𝘀𝘁𝘂𝘃𝘄𝘅𝘆𝘇𝟬𝟭𝟮𝟯𝟰𝟱𝟲𝟳𝟴𝟵")
    (italic           . "𝐴𝐵𝐶𝐷𝐸𝐹𝐺𝐻𝐼𝐽𝐾𝐿𝑀𝑁𝑂𝑃𝑄𝑅𝑆𝑇𝑈𝑉𝑊𝑋𝑌𝑍𝑎𝑏𝑐𝑑𝑒𝑓𝑔ℎ𝑖𝑗𝑘𝑙𝑚𝑛𝑜𝑝𝑞𝑟𝑠𝑡𝑢𝑣𝑤𝑥𝑦𝑧0123456789")
	 (bold-italic      . "𝑨𝑩𝑪𝑫𝑬𝑭𝑮𝑯𝑰𝑱𝑲𝑳𝑴𝑵𝑶𝑷𝑸𝑹𝑺𝑻𝑼𝑽𝑾𝑿𝒀𝒁𝒂𝒃𝒄𝒅𝒆𝒇𝒈𝒉𝒊𝒋𝒌𝒍𝒎𝒏𝒐𝒑𝒒𝒓𝒔𝒕𝒖𝒗𝒘𝒙𝒚𝒛0123456789")
	 (sans-italic      . "𝘈𝘉𝘊𝘋𝘌𝘍𝘎𝘏𝘐𝘑𝘒𝘓𝘔𝘕𝘖𝘗𝘘𝘙𝘚𝘛𝘜𝘝𝘞𝘟𝘠𝘡𝘢𝘣𝘤𝘥𝘦𝘧𝘨𝘩𝘪𝘫𝘬𝘭𝘮𝘯𝘰𝘱𝘲𝘳𝘴𝘵𝘶𝘷𝘸𝘹𝘺𝘻0123456789")
	 (sans-bold-italic . "𝘼𝘽𝘾𝘿𝙀𝙁𝙂𝙃𝙄𝙅𝙆𝙇𝙈𝙉𝙊𝙋𝙌𝙍𝙎𝙏𝙐𝙑𝙒𝙓𝙔𝙕𝙖𝙗𝙘𝙙𝙚𝙛𝙜𝙝𝙞𝙟𝙠𝙡𝙢𝙣𝙤𝙥𝙦𝙧𝙨𝙩𝙪𝙫𝙬𝙭𝙮𝙯0123456789")
	 (monospace        . "𝙰𝙱𝙲𝙳𝙴𝙵𝙶𝙷𝙸𝙹𝙺𝙻𝙼𝙽𝙾𝙿𝚀𝚁𝚂𝚃𝚄𝚅𝚆𝚇𝚈𝚉𝚊𝚋𝚌𝚍𝚎𝚏𝚐𝚑𝚒𝚓𝚔𝚕𝚖𝚗𝚘𝚙𝚚𝚛𝚜𝚝𝚞𝚟𝚠𝚡𝚢𝚣𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿")
	 (script           . "𝒜ℬ𝒞𝒟ℰℱ𝒢ℋℐ𝒥𝒦ℒℳ𝒩𝒪𝒫𝒬ℛ𝒮𝒯𝒰𝒱𝒲𝒳𝒴𝒵𝒶𝒷𝒸𝒹ℯ𝒻ℊ𝒽𝒾𝒿𝓀𝓁𝓂𝓃ℴ𝓅𝓆𝓇𝓈𝓉𝓊𝓋𝓌𝓍𝓎𝓏0123456789")
	 (bold-script      . "𝓐𝓑𝓒𝓓𝓔𝓕𝓖𝓗𝓘𝓙𝓚𝓛𝓜𝓝𝓞𝓟𝓠𝓡𝓢𝓣𝓤𝓥𝓦𝓧𝓨𝓩𝓪𝓫𝓬𝓭𝓮𝓯𝓰𝓱𝓲𝓳𝓴𝓵𝓶𝓷𝓸𝓹𝓺𝓻𝓼𝓽𝓾𝓿𝔀𝔁𝔂𝔃0123456789")
	 (double-struck    . "𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ𝕒𝕓𝕔𝕕𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡")
	 (gothic           . "𝔄𝔅ℭ𝔇𝔈𝔉𝔊ℌℑ𝔍𝔎𝔏𝔐𝔑𝔒𝔓𝔔ℜ𝔖𝔗𝔘𝔙𝔚𝔛𝔜ℨ𝔞𝔟𝔠𝔡𝔢𝔣𝔤𝔥𝔦𝔧𝔨𝔩𝔪𝔫𝔬𝔭𝔮𝔯𝔰𝔱𝔲𝔳𝔴𝔵𝔶𝔷0123456789")
	 (bold-gothic      . "𝕬𝕭𝕮𝕯𝕰𝕱𝕲𝕳𝕴𝕵𝕶𝕷𝕸𝕹𝕺𝕻𝕼𝕽𝕾𝕿𝖀𝖁𝖂𝖃𝖄𝖅𝖆𝖇𝖈𝖉𝖊𝖋𝖌𝖍𝖎𝖏𝖐𝖑𝖒𝖓𝖔𝖕𝖖𝖗𝖘𝖙𝖚𝖛𝖜𝖝𝖞𝖟0123456789")
	 (bubble           . "ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ⓪①②③④⑤⑥⑦⑧⑨")
	 (bubble-black     . "🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩⓿❶❷❸❹❺❻❼❽❾")
	 (squared          . "🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉⓪①②③④⑤⑥⑦⑧⑨")
	 (square-black     . "🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉🅰🅱🅲🅳🅴🅵🅶🅷🅸🅹🅺🅻🅼🅽🅾🅿🆀🆁🆂🆃🆄🆅🆆🆇🆈🆉⓿❶❷❸❹❺❻❼❽❾"))
  "Alist mapping Unicode base styles to 62-character lookup strings.")

(defconst unicode-style-multi-digit-numbers
  '((?⑩ . "10") (?⑪ . "11") (?⑫ . "12") (?⑬ . "13") (?⑭ . "14")
	 (?⑮ . "15") (?⑯ . "16") (?⑰ . "17") (?⑱ . "18") (?⑲ . "19") (?⑳ . "20")
	 (?⓫ . "11") (?⓬ . "12") (?⓭ . "13") (?⓮ . "14") (?⓯ . "15")
	 (?⓰ . "16") (?⓱ . "17") (?⓲ . "18") (?⓳ . "19") (?⓴ . "20")
	 (?🔟 . "10"))
  "Alist mapping enclosed and keycap multi-digit glyphs to ASCII strings.")

(defconst unicode-style-circled-10-to-20
  '(("10" . "⑩") ("11" . "⑪") ("12" . "⑫") ("13" . "⑬") ("14" . "⑭")
    ("15" . "⑮") ("16" . "⑯") ("17" . "⑰") ("18" . "⑱") ("19" . "⑲") ("20" . "⑳"))
  "Alist mapping standalone ASCII `10'..`20' to circled numbers `⑩'..`⑳'.")

(defconst unicode-style-black-circled-11-to-20
  '(("11" . "⓫") ("12" . "⓬") ("13" . "⓭") ("14" . "⓮") ("15" . "⓯")
    ("16" . "⓰") ("17" . "⓱") ("18" . "⓲") ("19" . "⓳") ("20" . "⓴"))
  "Alist mapping standalone ASCII `11'..`20' to negative circled `⓫'..`⓴'.")

(defconst unicode-style-script-positions
  '((superscript
	  . ((?A . ?ᴬ) (?B . ?ᴮ) (?C . ?ᶜ) (?D . ?ᴰ) (?E . ?ᴱ) (?F . ?ᶠ) (?G . ?ᴳ)
		  (?H . ?ᴴ) (?I . ?ᴵ) (?J . ?ᴶ) (?K . ?ᴷ) (?L . ?ᴸ) (?M . ?ᴹ) (?N . ?ᴺ)
		  (?O . ?ᴼ) (?P . ?ᴾ) (?Q . ?Q)  (?R . ?ᴿ) (?S . ?ˢ) (?T . ?ᵀ) (?U . ?ᵁ)
		  (?V . ?ⱽ) (?W . ?ᵂ) (?X . ?ˣ) (?Y . ?ʸ) (?Z . ?ᶻ)
		  (?a . ?ᵃ) (?b . ?ᵇ) (?c . ?ᶜ) (?d . ?ᵈ) (?e . ?ᵉ) (?f . ?ᶠ) (?g . ?ᵍ)
		  (?h . ?ʰ) (?i . ?ⁱ) (?j . ?ʲ) (?k . ?ᵏ) (?l . ?ˡ) (?m . ?ᵐ) (?n . ?ⁿ)
		  (?o . ?ᵒ) (?p . ?ᵖ) (?q . ?q)  (?r . ?ʳ) (?s . ?ˢ) (?t . ?ᵗ) (?u . ?ᵘ)
		  (?v . ?ᵛ) (?w . ?ʷ) (?x . ?ˣ) (?y . ?ʸ) (?z . ?ᶻ)
		  (?0 . ?⁰) (?1 . ?¹) (?2 . ?²) (?3 . ?³) (?4 . ?⁴)
		  (?5 . ?⁵) (?6 . ?⁶) (?7 . ?⁷) (?8 . ?⁸) (?9 . ?⁹)
		  (?+ . ?⁺) (?- . ?⁻) (?= . ?⁼) (?\( . ?⁽) (?\) . ?⁾)))
	 (subscript
	  . ((?A . ?ₐ) (?B . ?B) (?C . ?C) (?D . ?D) (?E . ?ₑ) (?F . ?F) (?G . ?G)
		  (?H . ?ₕ) (?I . ?ᵢ) (?J . ?ⱼ) (?K . ?ₖ) (?L . ?ₗ) (?M . ?ₘ) (?N . ?ₙ)
		  (?O . ?ₒ) (?P . ?ₚ) (?Q . ?Q) (?R . ?ᵣ) (?S . ?ₛ) (?T . ?ₜ) (?U . ?ᵤ)
		  (?V . ?ᵥ) (?W . ?W) (?X . ?ₓ) (?Y . ?Y) (?Z . ?Z)
		  (?a . ?ₐ) (?b . ?b) (?c . ?c) (?d . ?d) (?e . ?ₑ) (?f . ?f) (?g . ?g)
		  (?h . ?ₕ) (?i . ?ᵢ) (?j . ?ⱼ) (?k . ?ₖ) (?l . ?ₗ) (?m . ?ₘ) (?n . ?ₙ)
		  (?o . ?ₒ) (?p . ?ₚ) (?q . ?q) (?r . ?ᵣ) (?s . ?ₛ) (?t . ?ₜ) (?u . ?ᵤ)
		  (?v . ?ᵥ) (?w . ?w) (?x . ?ₓ) (?y . ?y) (?z . ?z)
		  (?0 . ?₀) (?1 . ?₁) (?2 . ?₂) (?3 . ?₃) (?4 . ?₄)
		  (?5 . ?₅) (?6 . ?₆) (?7 . ?₇) (?8 . ?₈) (?9 . ?₉)
		  (?+ . ?₊) (?- . ?₋) (?= . ?₌) (?\( . ?₍) (?\) . ?₎))))
  "Alist mapping superscript' and subscript' to character conversion tables.")

(defconst unicode-style-fullwidth-punct-map
  '((?.  . ?．) (?,  . ?，) (?!  . ?！) (??  . ?？)
	 (?:  . ?：) (?\; . ?；) (?\( . ?（) (?\) . ?）)
	 (?\[ . ?［) (?\] . ?］) (?\{ . ?｛) (?\} . ?｝)
	 (?/  . ?／) (?\\ . ?＼) (?&  . ?＆) (?@  . ?＠)
	 (?#  . ?＃) (?%  . ?％) (?+  . ?＋) (?=  . ?＝)
	 (?<  . ?＜) (?>  . ?＞) (?~  . ?～) (?|  . ?｜))
  "Alist mapping ASCII punctuation and brackets to Unicode Fullwidth forms.")

(defconst unicode-style-bracket-styles
  '(("fullwidth"   . ((?\( . ?（) (?\) . ?）) (?\[ . ?［) (?\] . ?］) (?\{ . ?｛) (?\} . ?｝)))
    ("lenticular"  . ((?\( . ?【) (?\) . ?】) (?\[ . ?〖) (?\] . ?〗) (?\{ . ?【) (?\} . ?】)))
    ("tortoise"    . ((?\( . ?〔) (?\) . ?〕) (?\[ . ?〘) (?\] . ?〙) (?\{ . ?〔) (?\} . ?〕)))
    ("angle"       . ((?\( . ?〈) (?\) . ?〉) (?\[ . ?《) (?\] . ?》) (?\{ . ?〈) (?\} . ?〉)))
    ("corner"      . ((?\( . ?「) (?\) . ?」) (?\[ . ?『) (?\] . ?』) (?\{ . ?「) (?\} . ?」)))
    ("superscript" . ((?\( . ?⁽) (?\) . ?⁾) (?\[ . ?⁽) (?\] . ?⁾) (?\{ . ?⁽) (?\} . ?⁾)))
    ("subscript"   . ((?\( . ?₍) (?\) . ?₎) (?\[ . ?₍) (?\] . ?₎) (?\{ . ?₍) (?\} . ?₎)))
    ("ascii"       . ((?\( . ?\() (?\) . ?\)) (?\[ . ?\[) (?\] . ?\]) (?\{ . ?\{) (?\} . ?\}))))
  "Alist of decorative and typographic parenthesis and bracket styles.")

(defconst unicode-style-fancy-punct-rules
  '(("\\.\\.\\." . "…")
    ("\\?!\\|!\\?" . "‽")
    ("!!"          . "‼")
    ("\\?\\?"      . "⁇")
    ("--"          . "—"))
  "Multi-character ASCII punctuation replacements for `unicode-style-fancy-punct'.")

(defun unicode-style--combining-marks ()
  "Return alist of combining diacritics."
  `((underline         . ,unicode-style-underline-char)
	 (double-underline  . #x0333)
	 (macron-below      . #x0331)
	 (overline          . #x0305)
	 (strikethrough     . #x0336)
	 (umlaut            . #x0308)
	 (acute             . #x0301)
	 (grave             . #x0300)
	 (circumflex        . #x0302)
	 (tilde             . #x0303)
	 (macron            . #x0304)
	 (breve             . #x0306)
	 (dot-above         . #x0307)
	 (ring              . #x030A)
	 (double-acute      . #x030B)
	 (caron             . #x030C)
	 (comma-below       . #x0326)
	 (cedilla           . #x0327)
	 (ogonek            . #x0328)
	 (right-arrow       . #x20D7)
	 (left-arrow        . #x20D6)
	 (left-right-arrow  . #x20E1)))

(defconst unicode-style-orthographic-marks
  '(#x0300  ; Combining Grave Accent (à, è, ù, ẁ)
	 #x0301  ; Combining Acute Accent (á, é, í, ó, ú, ý, ć, ń, ś, ź, ẃ)
	 #x0302  ; Combining Circumflex Accent (â, ê, î, ô, û)
	 #x0303  ; Combining Tilde (ñ, ã, õ)
	 #x0304  ; Combining Macron (ā, ē, ī, ū)
	 #x0306  ; Combining Breve (ă, й -> и + U+0306)
	 #x0307  ; Combining Dot Above (ż, ė, ċ, ġ)
	 #x0308  ; Combining Diaeresis / Tréma (ä, ë, ï, ö, ü, ÿ, ẅ, ё, ї)
	 #x030A  ; Combining Ring Above (å, ů)
	 #x030B  ; Combining Double Acute Accent (ő, ű)
	 #x030C  ; Combining Caron / Háček (č, ď, ě, ľ, ň, ř, š, ť, ž)
	 #x0326  ; Combining Comma Below (ș, ț, ģ, ķ, ļ, ņ)
	 #x0327  ; Combining Cedilla (ç, Ç)
	 #x0328) ; Combining Ogonek (ą, ę, į, ų)
  "Combining diacritical marks preserved across EU, Ukrainian, and Russian.")

(defconst unicode-style-strict-ascii-char-map
  '((?ß . "ss") (?ẞ . "SS")
	 (?ł . "l")  (?Ł . "L")
	 (?ø . "o")  (?Ø . "O")
	 (?đ . "d")  (?Đ . "D")
	 (?ħ . "h")  (?Ħ . "H")
	 (?ı . "i")
	 (?œ . "oe") (?Œ . "OE")
	 (?æ . "ae") (?Æ . "AE")
	 (?ª . "a")  (?º . "o")
	 ;; Greek uppercase & lowercase
	 (?Α . "A")  (?Β . "B")  (?Γ . "G")  (?Δ . "D")  (?Ε . "E")  (?Ζ . "Z")
	 (?Η . "I")  (?Θ . "Th") (?Ι . "I")  (?Κ . "K")  (?Λ . "L")  (?Μ . "M")
	 (?Ν . "N")  (?Ξ . "X")  (?Ο . "O")  (?Π . "P")  (?Ρ . "R")  (?Σ . "S")
	 (?Τ . "T")  (?Υ . "Y")  (?Φ . "F")  (?Χ . "Ch") (?Ψ . "Ps") (?Ω . "O")
	 (?α . "a")  (?β . "b")  (?γ . "g")  (?δ . "d")  (?ε . "e")  (?ζ . "z")
	 (?η . "i")  (?θ . "th") (?ι . "i")  (?κ . "k")  (?λ . "l")  (?μ . "m")
	 (?ν . "n")  (?ξ . "x")  (?ο . "o")  (?π . "p")  (?ρ . "r")  (?σ . "s")
	 (?ς . "s")  (?τ . "t")  (?υ . "y")  (?φ . "f")  (?χ . "ch") (?ψ . "ps")
	 (?ω . "o")
	 ;; Bulgarian, Ukrainian, & Russian Cyrillic uppercase & lowercase
	 (?А . "A")  (?Б . "B")  (?В . "V")  (?Г . "G")  (?Ґ . "G")  (?Д . "D")
	 (?Е . "E")  (?Ё . "Yo") (?Є . "Ye") (?Ж . "Zh") (?З . "Z")  (?И . "I")
	 (?І . "I")  (?Ї . "Yi") (?Й . "Y")  (?К . "K")  (?Л . "L")  (?М . "M")
	 (?Н . "N")  (?О . "O")  (?П . "P")  (?Р . "R")  (?С . "S")  (?Т . "T")
	 (?У . "U")  (?Ф . "F")  (?Х . "H")  (?Ц . "Ts") (?Ч . "Ch") (?Ш . "Sh")
	 (?Щ . "Sht") (?Ъ . "A") (?Ы . "Y")  (?Ь . "")   (?Э . "E")  (?Ю . "Yu")
	 (?Я . "Ya")
	 (?а . "a")  (?б . "b")  (?в . "v")  (?г . "g")  (?ґ . "g")  (?д . "d")
	 (?е . "e")  (?ё . "yo") (?є . "ye") (?ж . "zh") (?з . "z")  (?и . "i") ; russian, bulgarian
	 ;(?е . "e")  (?ё . "yo") (?є . "ye") (?ж . "zh") (?з . "z")  (?и . "y") ; ukrainian version
	 (?і . "i")  (?ї . "yi") (?й . "y")  (?к . "k")  (?л . "l")  (?м . "m")
	 (?н . "n")  (?о . "o")  (?п . "p")  (?р . "r")  (?с . "s")  (?т . "t")
	 (?у . "u")  (?ф . "f")  (?х . "h")  (?ц . "ts") (?ч . "ch") (?ш . "sh")
	 (?щ . "sht") (?ъ . "a") (?ы . "y")  (?ь . "")   (?э . "e")  (?ю . "yu")
	 (?я . "ya"))
  "Alist mapping non-decomposing EU Latin, Greek, and Cyrillic letters to ASCII.")

(defconst unicode-style-ukrainian-strict-ascii-overrides
  '((?Г . "H") (?г . "h")
    (?И . "Y") (?и . "y"))
  "Ukrainian strict-ASCII overrides when Cyrillic mode is `uk'.")

(defconst unicode-style-line-decorations
  '(underline double-underline macron-below overline strikethrough)
  "Combining marks that apply across letters, digits, spaces, and punctuation.")

(defconst unicode-style-dash-chars
  '(?- #x2010 #x2011 #x2012 #x2013 #x2014 #x2015 #x2212)
  "List of recognized Unicode hyphen, dash, and minus characters.")

;;; Continuous Display Composition (Overlay Renderer)

(defun unicode-style--clear-overlays (start end)
  "Remove all `unicode-style' display overlays between START and END."
  (remove-overlays start end 'unicode-style t))

;;;###autoload
(defun unicode-style-compose-underlines (start end)
  "Render combining lines between START and END continuously in Emacs."
  (interactive "r")
  (unicode-style--clear-overlays start end)
  (save-excursion
	 (goto-char start)
	 (let ((line-re "[^\t\n\r][\u0331\u0332\u0333\u035F\u0305\u0336\u0300-\u030C\u0326-\u0328\u20D6\u20D7\u20E1]+"))
		(while (re-search-forward line-re end t)
		  (let* ((seg-start (match-beginning 0))
					(seg-end   (match-end 0))
					(seg-str   (match-string-no-properties 0))
					(has-single-under (string-match-p "[\u0331\u0332\u035F]" seg-str))
					(has-double-under (string-match-p "\u0333" seg-str))
					(has-overline     (string-match-p "\u0305" seg-str))
					(has-strike       (string-match-p "\u0336" seg-str))
					(had-double-macron (string-match-p "\u035F" seg-str)))
			 (when (or has-single-under has-double-under has-overline has-strike)
				(while (and (< seg-end end)
								(save-excursion
								  (goto-char seg-end)
								  (looking-at line-re)))
				  (setq seg-end (match-end 0))
				  (let ((next-str (match-string-no-properties 0)))
					 (when (string-match-p "\u035F" next-str) (setq had-double-macron t))
					 (when (string-match-p "[\u0331\u0332\u035F]" next-str) (setq has-single-under t))
					 (when (string-match-p "\u0333" next-str) (setq has-double-under t))
					 (when (string-match-p "\u0305" next-str) (setq has-overline t))
					 (when (string-match-p "\u0336" next-str) (setq has-strike t))))
				(when (and had-double-macron
							  (< seg-end end)
							  (save-excursion
								 (goto-char seg-end)
								 (looking-at "[^\s\t\n\r][\u0300-\u030C\u0326-\u0328]*")))
				  (setq seg-end (match-end 0)))
				(let ((face-props
						 (append
						  (cond
							(has-double-under '(:underline (:style double)))
							(has-single-under '(:underline t)))
						  (when has-overline '(:overline t))
						  (when has-strike   '(:strike-through t))))
						(clean-display
						 (replace-regexp-in-string
						  "[\u0331\u0332\u0333\u035F\u0305\u0336]" ""
						  (buffer-substring-no-properties seg-start seg-end)))
						(ov (make-overlay seg-start seg-end nil t nil)))
				  (overlay-put ov 'unicode-style t)
				  (overlay-put ov 'evaporate t)
				  (overlay-put ov 'face face-props)
				  (overlay-put ov 'display (ucs-normalize-NFC-string clean-display)))
				(goto-char seg-end)))))))

;;;###autoload
(defun unicode-style-decompose-underlines (start end)
  "Remove continuous display overlays between START and END."
  (interactive "r")
  (unicode-style--clear-overlays start end))

;;;###autoload
(define-minor-mode unicode-style-visual-mode
  "Minor mode rendering Unicode combining underlines and overlines continuously."
  :lighter " U͟"
  :group 'unicode-style
  (if unicode-style-visual-mode
		(progn
		  (unicode-style-compose-underlines (point-min) (point-max))
		  (add-hook 'after-change-functions #'unicode-style--on-change nil t))
	 (remove-hook 'after-change-functions #'unicode-style--on-change t)
	 (unicode-style--clear-overlays (point-min) (point-max))))

(defun unicode-style--turn-on-visual-mode ()
  "Enable `unicode-style-visual-mode' in non-minibuffer buffers within size limit."
  (unless (or (minibufferp)
				  (and unicode-style-visual-max-buffer-size
						 (> (buffer-size) unicode-style-visual-max-buffer-size)))
	 (unicode-style-visual-mode 1)))

;;;###autoload
(define-globalized-minor-mode global-unicode-style-visual-mode
  unicode-style-visual-mode
  unicode-style--turn-on-visual-mode
  :group 'unicode-style)

;;;###autoload
(defun unicode-style-toggle-visual-size-limit ()
  "Toggle the buffer size limit for `global-unicode-style-visual-mode'."
  (interactive)
  (if unicode-style-visual-max-buffer-size
		(progn
		  (setq unicode-style-visual-max-buffer-size nil)
		  (message "Unicode-style visual size limit disabled (enabled for all buffer sizes)"))
	 (setq unicode-style-visual-max-buffer-size unicode-style-visual-size-limit-bytes)
	 (message "Unicode-style visual size limit enabled (%d bytes)"
				 unicode-style-visual-max-buffer-size)))

(defun unicode-style--on-change (beg end _len)
  "Refresh continuous underline composition around edited region BEG..END."
  (save-excursion
	 (let ((line-beg (progn (goto-char beg) (line-beginning-position)))
			 (line-end (progn (goto-char end) (line-end-position))))
		(unicode-style-compose-underlines line-beg line-end))))

;;; Smart Language-Specific Quotation Marks
(defun unicode-style--normalize-lang-code (lang)
  "Normalize LANG string (e.g. `de_DE', `german', `en-US') to ISO 639-1 code."
  (when (and (stringp lang) (not (string-empty-p lang)))
	 (let* ((lower (downcase lang))
			  (prefix (car (split-string lower "[-_@.]"))))
		(cond
		 ((assoc prefix unicode-style-quote-styles) prefix)
		 ((alist-get prefix unicode-style-quote-dict-aliases nil nil #'string=))
		 (t nil)))))

(defun unicode-style--resolve-quote-language (&optional override-lang)
  "Determine active ISO 639-1 language code, preferring OVERRIDE-LANG."
  (or (unicode-style--normalize-lang-code override-lang)
		(when (stringp unicode-style-quote-language)
		  (unicode-style--normalize-lang-code unicode-style-quote-language))
		(unicode-style--normalize-lang-code (bound-and-true-p ispell-local-dictionary))
		(unicode-style--normalize-lang-code (bound-and-true-p ispell-dictionary))
		(unicode-style--normalize-lang-code (bound-and-true-p current-input-method))
		(unicode-style--normalize-lang-code unicode-style-default-quote-language)
		"de"))

(defun unicode-style--quotes-to-ascii (text)
  "Revert typographic quotes in TEXT back to straight ASCII quotes."
  (let ((res text))
	 (dolist (rule '(("«\u00A0" . "\x22")
						  ("\u00A0»" . "\x22")
						  ("‹\u00A0" . "'")
						  ("\u00A0›" . "'")
						  ("„" . "\x22")
						  ("“" . "\x22")
						  ("”" . "\x22")
						  ("«" . "\x22")
						  ("»" . "\x22")
						  ("‚" . "'")
						  ("‘" . "'")
						  ("’" . "'")
						  ("‹" . "'")
						  ("›" . "'")))
		(setq res (replace-regexp-in-string (regexp-quote (car rule)) (cdr rule) res t t)))
	 res))

(defun unicode-style--apply-language-quotes (text lang)
  "Convert balanced straight quotes in TEXT to typographic quotes for LANG.
Unbalanced trailing quotes are left untouched."
  (let* ((pair-spec (or (alist-get lang unicode-style-quote-styles nil nil #'string=)
								(alist-get "de" unicode-style-quote-styles nil nil #'string=)))
			(open-dbl  (nth 0 pair-spec))
			(close-dbl (nth 1 pair-spec))
			(open-sgl  (nth 2 pair-spec))
			(close-sgl (nth 3 pair-spec))
			(len       (length text))
			(dbl-positions nil)
			(sgl-positions nil))
	 ;; Pass 1: Locate all straight double quotes and pairing-eligible single quotes
	 (dotimes (i len)
		(let ((c (aref text i)))
		  (cond
			((eq c ?\x22)
			 (push i dbl-positions))
			((eq c ?')
			 (let* ((prev-c (and (> i 0) (aref text (1- i))))
					  (next-c (and (< (1+ i) len) (aref text (1+ i))))
					  (prev-word (and prev-c (eq (char-syntax prev-c) ?w)))
					  (next-word (and next-c (eq (char-syntax next-c) ?w))))
				;; Skip internal apostrophes between two word characters (e.g. don't, l'eau)
				(unless (and prev-word next-word)
				  (push i sgl-positions)))))))
	 (setq dbl-positions (nreverse dbl-positions))
	 (setq sgl-positions (nreverse sgl-positions))
	 ;; Drop trailing unpaired quote so an unbalanced quote at the end stays as is
	 (when (cl-oddp (length dbl-positions))
		(setq dbl-positions (butlast dbl-positions)))
	 (when (cl-oddp (length sgl-positions))
		(setq sgl-positions (butlast sgl-positions)))
	 ;; Pass 2: Build lookup table of index -> replacement string
	 (let ((replacements (make-hash-table :test 'eql))
			 (idx 0))
		(dolist (pos dbl-positions)
		  (puthash pos (if (cl-evenp idx) open-dbl close-dbl) replacements)
		  (setq idx (1+ idx)))
		(setq idx 0)
		(dolist (pos sgl-positions)
		  (puthash pos (if (cl-evenp idx) open-sgl close-sgl) replacements)
		  (setq idx (1+ idx)))
		(let (out)
		  (dotimes (i len)
			 (push (or (gethash i replacements) (string (aref text i))) out))
		  (apply #'concat (nreverse out))))))

;;;###autoload
(defun unicode-style-toggle-quotes (start end &optional lang)
  "Toggle quotes between START and END between ASCII and Unicode quotes.
With a prefix argument (or optional LANG), prompt for the target language."
  (interactive
	(list (region-beginning)
			(region-end)
			(when current-prefix-arg
			  (completing-read
				"Quote language: "
				(mapcar #'car unicode-style-quote-styles)
				nil t))))
  (barf-if-buffer-read-only)
  (let* ((text (buffer-substring-no-properties start end))
			(has-unicode-quotes (string-match-p "[„“”‚‘’«»‹›]" text))
			(resolved-lang (unicode-style--resolve-quote-language lang))
			(result (if has-unicode-quotes
							(unicode-style--quotes-to-ascii text)
						 (unicode-style--apply-language-quotes text resolved-lang))))
	 (delete-region start end)
	 (insert result)
	 (unless has-unicode-quotes
		(message "Applied %s quotation marks" resolved-lang))))

;;; Live On-the-Fly Locale-Specific Quotation Marks
(defun unicode-style--smart-quote-char-before ()
  "Return the character immediately before point, or nil at beginning of buffer."
  (unless (bobp)
	 (char-before)))

(defvar unicode-style-smart-quotes-mode)

(defun unicode-style--smart-quote-post-self-insert ()
  "Convert typed ASCII \"' or '' into locale-specific Unicode quotes on the fly."
  (when (and unicode-style-smart-quotes-mode
				 (not buffer-read-only)
				 (memq last-command-event '(?\x22 ?')))
	 (let* ((ev last-command-event)
			  (lang (unicode-style--resolve-quote-language))
			  (pair-spec (or (alist-get lang unicode-style-quote-styles nil nil #'string=)
								  (alist-get "de" unicode-style-quote-styles nil nil #'string=)))
			  (open-dbl  (nth 0 pair-spec))
			  (close-dbl (nth 1 pair-spec))
			  (open-sgl  (nth 2 pair-spec))
			  (close-sgl (nth 3 pair-spec))
			  (prev-before-inserted (save-excursion
											  (backward-char 1)
											  (unicode-style--smart-quote-char-before)))
			  (is-opening (or (null prev-before-inserted)
									(memq (char-syntax prev-before-inserted) '(?\s ?\( ?-))
									(memq prev-before-inserted
											'(?\n ?\t ?\r ?\x22 ?' ?„ ?“ ?‚ ?‘ ?« ?‹))))
			  (replacement
				(cond
				 ((eq ev ?\x22)
				  (if is-opening open-dbl close-dbl))
				 ((eq ev ?')
				  (if is-opening open-sgl close-sgl)))))
		(when replacement
		  (delete-char -1)
		  (insert replacement)))))

;;;###autoload
(define-minor-mode unicode-style-smart-quotes-mode
  "Minor mode converting typed ASCII \"' and '' into locale-specific Unicode quotes."
  :lighter " „“"
  :group 'unicode-style
  (if unicode-style-smart-quotes-mode
		(add-hook 'post-self-insert-hook #'unicode-style--smart-quote-post-self-insert nil t)
	 (remove-hook 'post-self-insert-hook #'unicode-style--smart-quote-post-self-insert t)))

;;;###autoload
(defun unicode-style-toggle-smart-quotes-mode ()
  "Toggle `unicode-style-smart-quotes-mode' for live locale quotes."
  (interactive)
  (unicode-style-smart-quotes-mode (if unicode-style-smart-quotes-mode -1 1))
  (if unicode-style-smart-quotes-mode
		(message "Unicode-style live smart quotes enabled (%s)"
					(unicode-style--resolve-quote-language))
	 (message "Unicode-style live smart quotes disabled")))

;;; Core Conversion Helpers

(defun unicode-style--presets ()
  "Build list of available single and combined Unicode style names."
  (let ((bases (append (mapcar (lambda (s) (if (eq s 'squared) 'square s)) (delq 'ascii (mapcar #'car unicode-style-maps)))
							  '(keycap superscript subscript)))
		  (decs  (mapcar #'car (unicode-style--combining-marks)))
		  presets)
	 (dolist (b bases)
      (push (symbol-name b) presets)
      (dolist (d decs)
		  (push (format "%s-%s" b d) presets)))
	 (dolist (d decs)
      (push (symbol-name d) presets))
	 (push "quotes" presets)
	 (push "fullwidth-punct" presets)
	 (push "fancy-punct" presets)
	 (push "brackets" presets)
	 (push "ascii" presets)
	 (nreverse presets)))

(defun unicode-style--bracket-to-ascii (char)
  "Return the plain ASCII bracket for CHAR, or nil if not a bracket."
  (let (found)
	 (dolist (style unicode-style-bracket-styles found)
      (when-let ((pair (rassoc char (cdr style))))
		  (setq found (car pair))))))

(defun unicode-style--script-to-ascii (char)
  "Return the plain ASCII equivalent of superscript or subscript CHAR, or nil."
  (let (found)
	 (dolist (script unicode-style-script-positions found)
      (when-let ((pair (rassoc char (cdr script))))
		  (unless (eq (car pair) (cdr pair))
			 (setq found (car pair)))))))

(defun unicode-style--char-to-ascii (char)
  "Return the plain ASCII equivalent of CHAR if styled, else CHAR."
  (let ((ascii-str (alist-get 'ascii unicode-style-maps))
		  (fw-ascii  (car (rassoc char unicode-style-fullwidth-punct-map)))
		  (br-ascii  (unicode-style--bracket-to-ascii char))
		  (sc-ascii  (unicode-style--script-to-ascii char))
		  found)
	 (cond
	  (fw-ascii fw-ascii)
	  (br-ascii br-ascii)
	  (sc-ascii sc-ascii)
	  (t
      (dolist (pair unicode-style-maps)
		  (unless (eq (car pair) 'ascii)
			 (when-let ((idx (cl-position char (cdr pair))))
            (setq found (aref ascii-str idx)))))
      (or found char)))))

(defun unicode-style--normalize-enclosed-numbers (text)
  "Expand keycap digits and circled glyphs (10..20) in TEXT to ASCII."
  (let ((res (replace-regexp-in-string "\\([0-9]\\)\uFE0F?\u20E3" "\\1" text t)))
	 (dolist (pair unicode-style-multi-digit-numbers res)
      (setq res (replace-regexp-in-string (regexp-quote (string (car pair)))
                                          (cdr pair) res t t)))))

(defun unicode-style--detect-base-style (text)
  "Detect the dominant non-ASCII base style in TEXT, or return `ascii'."
  (let (detected)
	 (cond
	  ((string-match-p "\\(?:[0-9]\uFE0F?\u20E3\\|🔟\\)" text) 'keycap)
	  ((string-match-p "[⑩-⑳]" text) 'bubble)
	  ((string-match-p "[⓫-⓴]" text) 'bubble-black)
	  (t
      (dolist (pair unicode-style-maps)
		  (unless (or detected (eq (car pair) 'ascii))
			 (when (cl-some (lambda (c) (cl-position c (cdr pair))) text)
            (setq detected (car pair)))))
      (or detected 'ascii)))))

(defun unicode-style--punct-to-ascii (text)
  "Normalize stylistic and inverted Unicode punctuation in TEXT back to ASCII."
  (let ((res (unicode-style--quotes-to-ascii text)))
	 (dolist (rule '(("…" . "...")
						  ("‽" . "!?")
						  ("‼" . "!!")
						  ("⁇" . "??")
						  ("⁈" . "?!")
						  ("⁉" . "!?")
						  ("¡" . "!")
						  ("¿" . "?")
						  ("•" . "*")
						  ("·" . ".")))
      (setq res (replace-regexp-in-string (regexp-quote (car rule)) (cdr rule) res t t)))
	 res))

(defun unicode-style--dash-to-ascii (char)
  "Convert Unicode hyphen or dash CHAR to an ASCII hyphen string."
  (pcase char
	 ((or #x2014 #x2015) "--")
	 ((pred (lambda (c) (memq c unicode-style-dash-chars))) "-")
	 (_ nil)))

(defun unicode-style--orthographic-mark-p (char keep-typography)
  "Return non-nil when CHAR is a preserved orthographic mark under KEEP-TYPOGRAPHY."
  (and keep-typography
		 (memq char unicode-style-orthographic-marks)))

(defun unicode-style--last-underlinable-index (str keep-typography)
  "Return the index in STR of the last character eligible for line decoration.
When KEEP-TYPOGRAPHY is non-nil, trailing orthographic marks are skipped."
  (let ((i (1- (length str)))
		  found)
	 (while (and (>= i 0) (not found))
      (let ((c (aref str i)))
		  (unless (or (memq c '(?\t ?\n ?\r ?\s))
						  (unicode-style--orthographic-mark-p c keep-typography))
			 (setq found i)))
      (setq i (1- i)))
	 found))

(defun unicode-style--underlinable-count (str keep-typography)
  "Count characters in STR eligible for line decoration.
When KEEP-TYPOGRAPHY is non-nil, orthographic marks are not counted separately."
  (let ((count 0)
		  (len (length str))
		  (i 0))
	 (while (< i len)
      (let ((c (aref str i)))
		  (unless (or (memq c '(?\t ?\n ?\r))
						  (and (eq c ?\s) (not unicode-style-underline-spaces))
						  (unicode-style--orthographic-mark-p c keep-typography))
			 (setq count (1+ count))))
      (setq i (1+ i)))
	 count))

(defun unicode-style--apply-multi-digit-number (num-str style)
  "Return enclosed or keycap string for 2-digit NUM-STR under STYLE, or nil."
  (cond
   ((memq style '(bubble square))
	 (alist-get num-str unicode-style-circled-10-to-20 nil nil #'string=))
   ((memq style '(bubble-black square-black))
	 (alist-get num-str unicode-style-black-circled-11-to-20 nil nil #'string=))
   ((and (eq style 'keycap) (string= num-str "10"))
	 "🔟")
   (t nil)))

(defun unicode-style-apply (start end &optional base-style decorations keep-typography punct-mode)
  "Transform region between START and END using BASE-STYLE and DECORATIONS.
When KEEP-TYPOGRAPHY is non-nil, orthographic accents, special letters,
and punctuation across EU, Ukrainian, and Russian are preserved.
PUNCT-MODE can be `fullwidth' or `fancy'."
  (barf-if-buffer-read-only)
  (let* ((style        (if (eq base-style 'square) 'squared (or base-style 'ascii)))
         (all-marks    (unicode-style--combining-marks))
         (target-str   (alist-get style unicode-style-maps))
         (script-map   (alist-get style unicode-style-script-positions))
         (ascii-str    (alist-get 'ascii unicode-style-maps))
         (line-marks   (delq nil (mapcar (lambda (d)
														 (when (memq d unicode-style-line-decorations)
                                             (alist-get d all-marks)))
													  decorations)))
         (accent-marks (delq nil (mapcar (lambda (d)
														 (unless (memq d unicode-style-line-decorations)
                                             (alist-get d all-marks)))
													  decorations)))
         (raw-text     (buffer-substring-no-properties start end))
         (norm-num-text (unicode-style--normalize-enclosed-numbers raw-text))
         (nfd-text     (ucs-normalize-NFD-string norm-num-text))
         (strip-list   (if keep-typography
                           (cl-remove-if (lambda (pair)
														 (memq (cdr pair) unicode-style-orthographic-marks))
													  all-marks)
								 all-marks))
         (strip-re     (regexp-opt (append '("\u0331" "\u0332" "\u0333" "\u035F")
														 (mapcar (lambda (x) (string (cdr x))) strip-list))))
         (clean-text   (replace-regexp-in-string strip-re "" nfd-text))
         (pre-text     (cond
                        ((eq punct-mode 'fancy)
								 (let ((tmp clean-text))
                           (dolist (r unicode-style-fancy-punct-rules tmp)
									  (setq tmp (replace-regexp-in-string (car r) (cdr r) tmp t t)))))
                        ((and (not keep-typography) (eq style 'ascii))
								 (unicode-style--punct-to-ascii clean-text))
                        (t clean-text)))
         (trim-035f    (and unicode-style-trim-trailing-double-underline
									 (memq #x035F line-marks)))
         (last-idx     (when trim-035f
								 (unicode-style--last-underlinable-index pre-text keep-typography)))
         (char-count   (when trim-035f
								 (unicode-style--underlinable-count pre-text keep-typography)))
         (converted
			 (let ((len (length pre-text))
					 (i 0)
					 (out nil))
            (while (< i len)
				  (let* ((curr-idx i)
                     (c (aref pre-text i))
                     (prev-base (and (> i 0)
												 (unicode-style--char-to-ascii (aref pre-text (1- i)))))
                     (next-base (and (< (1+ i) len)
												 (unicode-style--char-to-ascii (aref pre-text (1+ i)))))
                     (after-next-base (and (< (+ i 2) len)
														 (unicode-style--char-to-ascii (aref pre-text (+ i 2)))))
                     (c-base (unicode-style--char-to-ascii c))
                     (two-digit-str (and (memq style '(bubble bubble-black square square-black keycap))
													  (>= c-base ?1) (<= c-base ?2)
													  next-base (>= next-base ?0) (<= next-base ?9)
													  (not (and prev-base (>= prev-base ?0) (<= prev-base ?9)))
													  (not (and after-next-base (>= after-next-base ?0) (<= after-next-base ?9)))
													  (string c-base next-base)))
                     (multi-glyph (and two-digit-str
                                       (unicode-style--apply-multi-digit-number two-digit-str style))))
					 (if multi-glyph
						  (let* ((end-idx (1+ i))
									(skip-line nil)
									(effective-line-marks
									 (cond
									  (skip-line nil)
									  ((and trim-035f (eq end-idx last-idx))
										(if (<= char-count 2)
											 (mapcar (lambda (m) (if (eq m #x035F) #x0332 m)) line-marks)
										  (remq #x035F (copy-sequence line-marks))))
									  (t line-marks))))
							 (push (if (null effective-line-marks)
										  multi-glyph
										(concat multi-glyph (apply #'string effective-line-marks)))
									 out)
							 (setq i (1+ i)))
						(let ((ortho-marks nil))
						  ;; Gather any orthographic diacritics attached to the current base character
						  (while (and (< (1+ i) len)
										  (unicode-style--orthographic-mark-p (aref pre-text (1+ i))
																						  keep-typography))
							 (setq i (1+ i))
							 (push (aref pre-text i) ortho-marks))
						  (setq ortho-marks (nreverse ortho-marks))
						  (let* ((base c-base)
									(idx  (cl-position base ascii-str))
									(is-keycap-digit (and (eq style 'keycap) (>= base ?0) (<= base ?9)))
									(char (cond
											 (script-map (or (alist-get base script-map) c))
											 ((and target-str idx) (aref target-str idx))
											 ((eq punct-mode 'fullwidth)
											  (or (alist-get base unicode-style-fullwidth-punct-map) c))
											 ((and (not keep-typography) (eq style 'ascii)) base)
											 (t c)))
									(strict-str (and (not keep-typography)
														  (eq style 'ascii)
														  (or (and (eq unicode-style-cyrillic-transliteration 'uk)
                                                 (alist-get char unicode-style-ukrainian-strict-ascii-overrides))
                                            (alist-get char unicode-style-strict-ascii-char-map))))
									(is-letter (or (and (>= base ?A) (<= base ?Z))
														(and (>= base ?a) (<= base ?z))
														(alist-get base unicode-style-strict-ascii-char-map)))
									(skip-line (or (memq base '(?\t ?\n ?\r))
														(unicode-style--orthographic-mark-p base keep-typography)
														(and (eq base ?\s)
															  (not unicode-style-underline-spaces))))
									(effective-line-marks
									 (cond
									  (skip-line nil)
									  ((and trim-035f (eq curr-idx last-idx))
										(if (= char-count 1)
											 (mapcar (lambda (m) (if (eq m #x035F) #x0332 m)) line-marks)
										  (remq #x035F (copy-sequence line-marks))))
									  (t line-marks)))
									(applied-marks (append (when is-keycap-digit '(#xFE0F #x20E3))
																  effective-line-marks
																  ortho-marks
																  (when is-letter accent-marks))))
							 (push
							  (cond
								(strict-str strict-str)
								((and (not keep-typography) (eq style 'ascii) (memq char unicode-style-dash-chars))
								 (unicode-style--dash-to-ascii char))
								((null applied-marks) (string char))
								(t (apply #'string char applied-marks)))
							  out)))))
				  (setq i (1+ i)))
				(apply #'concat (nreverse out))))
			(final-text (if (and keep-typography (null line-marks))
								 (ucs-normalize-NFC-string converted)
							  converted)))
	 (unicode-style--clear-overlays start end)
	 (delete-region start end)
	 (let ((ins-start (point)))
		(insert final-text)
		(when (and unicode-style-continuous-display line-marks)
		  (unicode-style-compose-underlines ins-start (point))))))

;;; Compact Interactive Command Generators
;;;###autoload
(defun unicode-style-set-style (style start end)
  "Apply base Unicode STYLE to region between START and END."
  (interactive
	(list (intern (completing-read
						"Base style: "
						(append (mapcar (lambda (x) (symbol-name (if (eq (car x) 'squared) 'square (car x)))) unicode-style-maps)
								  '("keycap" "superscript" "subscript"))
						nil t))
			(region-beginning)
			(region-end)))
  (unicode-style-apply start end style nil t))

;;;###autoload
(defun unicode-style-decorate (decoration start end)
  "Apply combining DECORATION to region between START and END."
  (interactive
	(list (intern (completing-read
						"Decoration: "
						(mapcar (lambda (x) (symbol-name (car x))) (unicode-style--combining-marks))
						nil t))
			(region-beginning)
			(region-end)))
  (let* ((text (buffer-substring-no-properties start end))
			(current-style (unicode-style--detect-base-style text)))
	 (unicode-style-apply start end current-style (list decoration) t)))

(defmacro unicode-style--define-styler (name style doc)
  "Define interactive command NAME applying base STYLE with docstring DOC."
  `(defun ,name (start end)
	  ,doc
	  (interactive "r")
	  (unicode-style-set-style ',style start end)))

(defmacro unicode-style--define-decorator (name decoration doc)
  "Define interactive command NAME applying DECORATION with docstring DOC."
  `(defun ,name (start end)
	  ,doc
	  (interactive "r")
	  (unicode-style-decorate ',decoration start end)))
;; Base Font, Enclosed, & Script Commands
(unicode-style--define-styler unicode-style-to-ascii         ascii            "Revert styled text between START and END to plain text.")
(unicode-style--define-styler unicode-style-bold             bold             "Convert region between START and END to Mathematical Bold.")
(unicode-style--define-styler unicode-style-sans-bold        sans-bold        "Convert region between START and END to Sans-Serif Bold.")
(unicode-style--define-styler unicode-style-italic           italic           "Convert region between START and END to Mathematical Italic.")
(unicode-style--define-styler unicode-style-bold-italic      bold-italic      "Convert region between START and END to Mathematical Bold Italic.")
(unicode-style--define-styler unicode-style-sans-italic      sans-italic      "Convert region between START and END to Sans-Serif Italic.")
(unicode-style--define-styler unicode-style-sans-bold-italic sans-bold-italic "Convert region between START and END to Sans-Serif Bold Italic.")
(unicode-style--define-styler unicode-style-monospace        monospace        "Convert region between START and END to Mathematical Monospace.")
(unicode-style--define-styler unicode-style-script           script           "Convert region between START and END to Mathematical Script.")
(unicode-style--define-styler unicode-style-bold-script      bold-script      "Convert region between START and END to Mathematical Bold Script.")
(unicode-style--define-styler unicode-style-double-struck    double-struck    "Convert region between START and END to Double-Struck.")
(unicode-style--define-styler unicode-style-gothic           gothic           "Convert region between START and END to Gothic (Fraktur).")
(unicode-style--define-styler unicode-style-bold-gothic      bold-gothic      "Convert region between START and END to Bold Gothic.")
(unicode-style--define-styler unicode-style-bubble           bubble           "Convert region between START and END to Circled Bubble characters (0-20).")
(unicode-style--define-styler unicode-style-bubble-black     bubble-black     "Convert region between START and END to Negative Circled characters (0-20).")
(unicode-style--define-styler unicode-style-square           square           "Convert region between START and END to Squared characters (0-20).")
(unicode-style--define-styler unicode-style-square-black     square-black     "Convert region between START and END to Negative Squared characters (0-20).")
(unicode-style--define-styler unicode-style-keycap           keycap           "Convert digits 0-10 between START and END to Emoji Keycap symbols.")
(unicode-style--define-styler unicode-style-superscript      superscript      "Convert region between START and END to Superscript characters.")
(unicode-style--define-styler unicode-style-subscript        subscript        "Convert region between START and END to Subscript characters.")
;; Combining Line & Arrow Commands
(unicode-style--define-decorator unicode-style-underline        underline        "Underline region between START and END.")
(unicode-style--define-decorator unicode-style-double-underline double-underline "Double-underline region between START and END.")
(unicode-style--define-decorator unicode-style-overline         overline         "Overline region between START and END.")
(unicode-style--define-decorator unicode-style-strikethrough    strikethrough    "Strikethrough region between START and END.")
(unicode-style--define-decorator unicode-style-right-arrow      right-arrow      "Apply right arrow above (U+20D7) to letters between START and END.")
(unicode-style--define-decorator unicode-style-left-arrow       left-arrow       "Apply left arrow above (U+20D6) to letters between START and END.")
(unicode-style--define-decorator unicode-style-left-right-arrow left-right-arrow "Apply left-right arrow above (U+20E1) to letters between START and END.")

;;; Specialized Interactive Commands
;;;###autoload
(defun unicode-style-to-strict-ascii (start end)
  "Convert region between START and END to pure 7-bit ASCII."
  (interactive "r")
  (unicode-style-apply start end 'ascii nil nil))

;;;###autoload
(defun unicode-style-toggle-cyrillic-transliteration ()
  "Toggle Cyrillic strict-ASCII transliteration between `uk' and `ru-bg'."
  (interactive)
  (setq unicode-style-cyrillic-transliteration
        (if (eq unicode-style-cyrillic-transliteration 'uk) 'ru-bg 'uk))
  (message "Cyrillic strict-ASCII transliteration: %s"
           (if (eq unicode-style-cyrillic-transliteration 'uk)
               "Ukrainian (И->Y, Г->H)"
             "Bulgarian/Russian (И->I, Г->G)")))

;;;###autoload
(defun unicode-style-toggle-bold (start end)
  "Toggle region between START and END between plain text and Mathematical Bold."
  (interactive "r")
  (let* ((text (buffer-substring-no-properties start end))
			(bold-str (alist-get 'bold unicode-style-maps))
			(is-bold (cl-some (lambda (c) (cl-position c bold-str)) text)))
	 (unicode-style-apply start end (if is-bold 'ascii 'bold) nil t)))

;;;###autoload
(defun unicode-style-umlaut (start end)
  "Apply combining diaeresis (U+0308) to letters between START and END."
  (interactive "r")
  (unicode-style-apply start end 'ascii '(umlaut) nil))

;;;###autoload
(defun unicode-style-fullwidth-punct (start end)
  "Convert ASCII punctuation between START and END to Unicode Fullwidth forms."
  (interactive "r")
  (unicode-style-apply start end 'ascii nil t 'fullwidth))

;;;###autoload
(defun unicode-style-fancy-punct (start end)
  "Convert ASCII punctuation sequences between START and END to stylistic glyphs."
  (interactive "r")
  (unicode-style-apply start end 'ascii nil t 'fancy))

;;;###autoload
(defun unicode-style-brackets (start end)
  "Prompt for a Unicode bracket style and apply it between START and END."
  (interactive "r")
  (barf-if-buffer-read-only)
  (let* ((choices (mapcar #'car unicode-style-bracket-styles))
			(choice  (completing-read "Bracket style: " choices nil t))
			(bmap    (alist-get choice unicode-style-bracket-styles nil nil #'string=))
			(text    (buffer-substring-no-properties start end))
			(converted
			 (mapconcat
			  (lambda (c)
				 (let* ((ascii-b (or (unicode-style--bracket-to-ascii c) c))
						  (mapped  (alist-get ascii-b bmap)))
					(string (or mapped c))))
			  text "")))
	 (delete-region start end)
	 (insert converted)))

;;;###autoload
(defun unicode-style-region (start end)
  "Prompt for any Unicode style or combination and apply it between START and END."
  (interactive "r")
  (let* ((choice (completing-read "Unicode style: " (unicode-style--presets) nil t))
			(decorations nil)
			(punct-mode nil)
			(base choice))
	 (cond
	  ((string= base "quotes")
		(call-interactively #'unicode-style-toggle-quotes))
	  ((string= base "brackets")
		(call-interactively #'unicode-style-brackets))
	  ((string= base "fullwidth-punct")
		(unicode-style-apply start end 'ascii nil t 'fullwidth))
	  ((string= base "fancy-punct")
		(unicode-style-apply start end 'ascii nil t 'fancy))
	  (t
		(dolist (mark-pair (unicode-style--combining-marks))
		  (let* ((sym    (car mark-pair))
					(suffix (concat "-" (symbol-name sym))))
			 (when (string-suffix-p suffix base)
				(push sym decorations)
				(setq base (string-remove-suffix suffix base)))))
		(when (alist-get (intern base) (unicode-style--combining-marks))
		  (push (intern base) decorations)
		  (setq base "ascii"))
		(unicode-style-apply start end (intern base) decorations (not (string= choice "ascii")) punct-mode)))))

;;; Prefix Keymap
;;;###autoload
(defvar unicode-style-prefix-map
  (let ((map (make-sparse-keymap)))
	 (define-key map (kbd "RET")  #'unicode-style-region)
	 (define-key map (kbd "SPC")  #'unicode-style-region)
	 (define-key map (kbd "a")    #'unicode-style-to-ascii)
	 (define-key map (kbd "A")    #'unicode-style-to-strict-ascii)
    (define-key map (kbd "r")    #'unicode-style-toggle-cyrillic-transliteration)
	 (define-key map (kbd "b")    #'unicode-style-toggle-bold)
	 (define-key map (kbd "B")    #'unicode-style-sans-bold)
	 (define-key map (kbd "i")    #'unicode-style-italic)
	 (define-key map (kbd "I")    #'unicode-style-bold-italic)
	 (define-key map (kbd "j")    #'unicode-style-sans-italic)
	 (define-key map (kbd "J")    #'unicode-style-sans-bold-italic)
	 (define-key map (kbd "m")    #'unicode-style-monospace)
	 (define-key map (kbd "c")    #'unicode-style-script)
	 (define-key map (kbd "C")    #'unicode-style-bold-script)
	 (define-key map (kbd "d")    #'unicode-style-double-struck)
	 (define-key map (kbd "g")    #'unicode-style-gothic)
	 (define-key map (kbd "G")    #'unicode-style-bold-gothic)
	 (define-key map (kbd "w")    #'unicode-style-bubble)
	 (define-key map (kbd "W")    #'unicode-style-bubble-black)
	 (define-key map (kbd "q")    #'unicode-style-square)
	 (define-key map (kbd "Q")    #'unicode-style-square-black)
	 (define-key map (kbd "k")    #'unicode-style-keycap)
	 (define-key map (kbd "^")    #'unicode-style-superscript)
	 (define-key map (kbd "_")    #'unicode-style-subscript)
	 (define-key map (kbd "u")    #'unicode-style-underline)
	 (define-key map (kbd "U")    #'unicode-style-double-underline)
	 (define-key map (kbd "o")    #'unicode-style-overline)
	 (define-key map (kbd "s")    #'unicode-style-strikethrough)
	 (define-key map (kbd "\"")   #'unicode-style-umlaut)
	 (define-key map (kbd "'")    #'unicode-style-toggle-quotes)
	 (define-key map (kbd ",")    #'unicode-style-toggle-smart-quotes-mode)
    (define-key map (kbd "`")    #'unicode-style-toggle-smart-quotes-mode)
	 (define-key map (kbd ">")    #'unicode-style-right-arrow)
	 (define-key map (kbd "<")    #'unicode-style-left-arrow)
	 (define-key map (kbd "~")    #'unicode-style-left-right-arrow)
	 (define-key map (kbd "p")    #'unicode-style-fullwidth-punct)
	 (define-key map (kbd "P")    #'unicode-style-fancy-punct)
	 (define-key map (kbd "(")    #'unicode-style-brackets)
	 (define-key map (kbd "=")    #'unicode-style-compose-underlines)
	 (define-key map (kbd "+")    #'unicode-style-decompose-underlines)
	 (define-key map (kbd "v")    #'global-unicode-style-visual-mode)
	 (define-key map (kbd "V")    #'unicode-style-toggle-visual-size-limit)
	 map)
  "Prefix keymap for Unicode text styling commands.")
(fset 'unicode-style-prefix-map unicode-style-prefix-map)
(declare-function which-key-add-key-based-replacements "which-key" (key-sequence replacement &rest more))
(when (fboundp 'which-key-add-key-based-replacements)
  (which-key-add-key-based-replacements "C-c u" "unicode-style"))
(provide 'unicode-style)

;;; unicode-style.el ends here
