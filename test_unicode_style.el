;;; test_unicode_style.el --- Automated batch tests for unicode-style.el v0.42.2 -*- lexical-binding: t; -*-

(require 'ert)
(load (expand-file-name "unicode-style.el" default-directory) nil t)

(defun test-ustyle--run (input fn &rest args)
  "Apply FN with ARGS to region covering INPUT and return resulting string."
  (with-temp-buffer
    (insert input)
    (apply fn (point-min) (point-max) args)
    (buffer-string)))

(ert-deftest unicode-style-test-alphabets-and-eu-languages ()
  "Verify font styles and preservation of German, French, Polish, Greek, and Cyrillic."
  (should (equal (test-ustyle--run "Hello 123" #'unicode-style-bold) "𝐇𝐞𝐥𝐥𝐨 𝟏𝟐𝟑"))
  (should (equal (test-ustyle--run "Straße" #'unicode-style-gothic) "𝔖𝔱𝔯𝔞ß𝔢"))
  (should (equal (test-ustyle--run "Café Français" #'unicode-style-bold)
                 (ucs-normalize-NFC-string "𝐂𝐚𝐟𝐞́ 𝐅𝐫𝐚𝐧𝐜̧𝐚𝐢𝐬")))
  (should (equal (test-ustyle--run "Łódź" #'unicode-style-bold)
                 (ucs-normalize-NFC-string "Ł𝐨́𝐝𝐳́")))
  ;; Default is Ukrainian ('uk): Київ -> Kyiv, Гривня -> Hryvnya
  (should (eq unicode-style-cyrillic-transliteration 'uk))
  (should (equal (test-ustyle--run "Київ & Гривня" #'unicode-style-to-strict-ascii)
                 "Kyiv & Hryvnya"))
  ;; Toggle to Bulgarian/Russian ('ru-bg'): България -> Balgariya, Москва -> Moskva
  (unicode-style-toggle-cyrillic-transliteration)
  (should (eq unicode-style-cyrillic-transliteration 'ru-bg))
  (should (equal (test-ustyle--run "Ελλάδα & България & Москва" #'unicode-style-to-strict-ascii)
                 "Ellada & Balgariya & Moskva"))
  ;; Toggle back to default ('uk)
  (unicode-style-toggle-cyrillic-transliteration)
  (should (eq unicode-style-cyrillic-transliteration 'uk)))

(ert-deftest unicode-style-test-enclosed-and-keycaps ()
  "Verify enclosed numbers 10..20 and keycap digits 0..10."
  (should (equal (test-ustyle--run "Abc 12 20" #'unicode-style-bubble) "Ⓐⓑⓒ ⑫ ⑳"))
  (should (equal (test-ustyle--run "Abc 12 20" #'unicode-style-bubble-black) "🅐🅑🅒 ⓬ ⓴"))
  (should (equal (test-ustyle--run "0 5 10" #'unicode-style-keycap) "0️⃣ 5️⃣ 🔟"))
  (should (equal (test-ustyle--run "Ⓐⓑⓒ ⑫ ⑳ ⓬ ⓴ 0️⃣ 🔟" #'unicode-style-to-ascii)
                 "Abc 12 20 12 20 0 10")))

(ert-deftest unicode-style-test-quotes-and-underlines ()
  "Verify locale smart quotes (balanced/unbalanced) and U+035F underline trimming."
  (let ((unicode-style-quote-language "de"))
    (should (equal (test-ustyle--run "\"Hallo\" und \"offen" #'unicode-style-toggle-quotes)
                   "„Hallo“ und \"offen"))
    (should (equal (test-ustyle--run "„Hallo“" #'unicode-style-toggle-quotes)
                   "\"Hallo\"")))
  (let ((unicode-style-quote-language "fr"))
    (should (equal (test-ustyle--run "\"Bonjour\"" #'unicode-style-toggle-quotes)
                   "«\u00A0Bonjour\u00A0»")))
  (should (equal (test-ustyle--run "Hi" #'unicode-style-underline) "H͟i"))
  (should (eq (lookup-key unicode-style-prefix-map (kbd ","))
              #'unicode-style-toggle-smart-quotes-mode)))

(ert-run-tests-batch-and-exit)
;;; test_unicode_style.el ends here
