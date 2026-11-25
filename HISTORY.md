# Revision History & Milestones (`unicode-style.el`)

> **History Version:** `0.42.4`  
> **Last Updated:** `2026-11-25 09:19 CET`

## v0.42.x Series — MELPA Compliance, Linter Hardening & Usability
- **v0.42.4 (2026-11-25 00:44 CET) — MELPA Compliance & `package-lint` Hardening:** Shortened summary line to `<= 60` characters, renamed internal `square` alist key to `squared`, replaced macro calls with function checks, and synchronized all project documentation.
- **v0.42.3 (2026-11-24 23:45 CET) — `checkdoc` Compliance:** Updated function docstrings to use imperative verbs and documented optional parameters.
- **v0.42.2 (2026-11-24 21:55 CET) — Zero-Warning Byte-Compilation:** Added required subr-x library features and wrapped docstrings to `<= 80` characters.
- **v0.42.1 (2026-11-24 21:39 CET) — Ergonomic Live Smart-Quotes Shortcut (`C-c u ,`):** Bound smart quotes toggle to `C-c u ,` with legacy alias support.
- **v0.42.0 (2026-11-24 19:03 CET) — Switchable Cyrillic Strict-ASCII Transliteration (`C-c u r`):** Added Ukrainian/Russian transliteration modes with interactive toggling.

## v0.40.0 – v0.41.0 — Full Multilingual Support, Smart Quotes & Automated Testing
- **v0.41.0 (2026-11-24 17:57 CET) — Locale-Specific Quotation Marks & Automated ERT Suite:** Introduced region quote conversions for 26 languages and automated ERT tests (`test_unicode_style.el`).
- **v0.40.0 (November 2026) — 26-Language Typography, Multi-Digit Enclosed Numbers & Keycaps:** Added NFD/NFC normalization, ASCII transliteration, multi-digit circled numbers, and emoji keycap mode (`C-c u k`).

## v0.30.0 – v0.39.x (October – November 2026) — Continuous Visual Display & Smart Underlines
- **v0.36.0 – v0.39.x — Continuous Underline Overlays (`global-unicode-style-visual-mode`):** Added non-intrusive overlay composition/decomposition with incremental refreshes.
- **v0.33.0 – v0.35.x — Smooth External Underlines (`U+035F`) & Trailing Overhang Trimming:** Updated default underline marks and added automatic trailing trim logic.
- **v0.30.0 – v0.32.x — Combinable Style Engine & Interactive Completion (`C-c u RET`):** Unified base alphabets, line decorations, and diacritics under `unicode-style-apply`.

## v0.20.0 – v0.29.x (September – October 2026) — Superscript/Subscript, Diacritics & Vectors
- **v0.26.0 – v0.29.x — Decorative Brackets & Typographic Punctuation:** Added 8 bracket styles and fullwidth/fancy punctuation commands.
- **v0.23.0 – v0.25.x — Combining Diacritics & Vector Arrows:** Added umlauts, 13 combining diacritics, and directional vector arrow decorators.
- **v0.20.0 – v0.22.x — Superscript, Subscript & Combining Line Decorations:** Added Unicode superscript, subscript, and combining line decorators.

## v0.1.0 – v0.19.x (August – September 2026) — Core Mathematical Alphanumeric Engine
- **v0.15.0 – v0.19.x — Enclosed Alphabets, Bold Toggle & Prefix Keymap:** Added bubble and square enclosed variants, smart bold toggling, and prefix keymap integration (`C-c u`).
- **v0.10.0 – v0.14.x — Complete 12-Font Mathematical Alphanumeric Suite & Reversion:** Expanded lookup tables across all 12 font variants and added plain-text ASCII reversion (`C-c u a`).
- **v0.1.0 — Initial Prototype:** Created initial Emacs region transformation commands for mathematical bold and italic Unicode codepoints.
