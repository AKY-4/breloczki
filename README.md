# Strona 3D things

Jednostronicowa strona marki 3D things: breloki 3D z logo firmy i tabliczki NFC do opinii Google. Strona jest statyczna. Powstaje z jednego pliku danych i szablonów, bez instalowania czegokolwiek na Macu.

## Co jest w tym folderze

| Plik lub folder | Do czego służy |
|---|---|
| `dane.yml` | Jedyny plik, w którym zmienia się dane i treści: kontakt, dane sprzedawcy, ceny, pytania i odpowiedzi, galeria, adres formularza. |
| `szablony/` | Układ strony i jej sekcje. |
| `zasoby/` | Style, skrypt, czcionki, obrazy. |
| `buduj.rb` | Generuje stronę z danych i szablonów. |
| `sprawdz.rb` | Sprawdza wygenerowaną stronę (46 testów). |
| `atrapa.rb` | Lokalny podgląd z atrapą formularza. Niczego nie wysyła na zewnątrz. |
| `podglad/` | Wygenerowana wersja podglądowa. Nie nadaje się do publikacji. |
| `publikacja/` | Wersja do wgrania na hosting. Powstaje dopiero po uzupełnieniu danych. |

## Jak obejrzeć stronę

Otwórz Terminal w tym folderze i wpisz:

```bash
ruby buduj.rb
```

```bash
ruby atrapa.rb
```

Potem otwórz w przeglądarce adres `http://localhost:8080`. Serwer zatrzymuje Ctrl+C.

Wersja podglądowa ma żółty pasek u góry, przykładowe wartości w miejscu braków i jest wyłączona z indeksowania. Pokazuje też to, czego nie będzie w wersji do publikacji: projekty czekające na zgodę firm i pytania czekające na odpowiedź.

## Jak uzupełnić dane

Wszystko wpisuje się w `dane.yml`. Pola opisane jako WYMAGANE blokują wersję do publikacji:

1. `strona.url`: adres strony z https, bez ukośnika na końcu.
2. `formularz.adres`: adres wysyłki formularza (patrz niżej).
3. `sprzedawca`: forma prawna (`jdg`, `nierejestrowana` albo `spzoo`) i dane, których ta forma wymaga.
4. `ceny.vat`: `netto`, `brutto` albo `zwolniony`.

Pozostałe pola są opcjonalne. Puste pole oznacza, że zależna od niego treść nie pojawi się na stronie. Dotyczy to dostawy, materiału, kółka do kluczy, szczegółów tabliczki NFC i obietnicy czasu odpowiedzi.

Pytania w sekcji `faq` z `opublikowane: false` czekają na odpowiedź. Wpisz odpowiedź i zmień na `opublikowane: true`.

Pozycje w `galeria` trafiają do wersji do publikacji dopiero po ustawieniu `zgoda: true`, czyli gdy firma zgodziła się na pokazanie projektu z jej logo. Dopóki zgodę mają mniej niż 4 pozycje, cała sekcja „Przykładowe projekty” się nie pojawia.

## Jak wygenerować wersję do publikacji

```bash
ruby buduj.rb produkcja
```

```bash
ruby sprawdz.rb publikacja
```

Jeśli brakuje danych, pierwsze polecenie wypisze listę braków i niczego nie wygeneruje. Gdy oba polecenia przejdą, na hosting wgrywa się **zawartość folderu `publikacja/`** (nie sam folder) do katalogu głównego domeny.

## Jak podłączyć formularz

Formularz ma pola: e-mail (wymagany), telefon (opcjonalny) i opis (wymagany). Telefon staje się wymagany po ustawieniu `formularz.telefon_wymagany: true`.

### Wariant 1: Formspark (zalecany na start)

Formspark to usługa formularzy z Belgii. Dane trzyma w Unii Europejskiej, a umowa powierzenia danych jest częścią regulaminu. Darmowy pakiet to jednorazowo 250 zgłoszeń (spam się nie liczy), kolejne 50 000 kosztuje jednorazowo ok. 25 USD.

1. Załóż konto na formspark.io i utwórz formularz.
2. W ustawieniach formularza, w części Emails → Notifications, ustaw skrzynkę, na którą mają przychodzić zgłoszenia.
3. Skopiuj adres formularza w postaci `https://submit-form.com/IDENTYFIKATOR`.
4. W `dane.yml` wpisz `usluga: "formspark"` i ten adres w polu `adres`.

Adres skrzynki nie występuje w kodzie strony. Strona wysyła też ukryte pole `_append` o wartości `false`, żeby dane z formularza nie trafiały do adresu strony z podziękowaniem.

### Wariant 2: własny adres wysyłki

Gdy hosting będzie wybrany, obsługę formularza można napisać samemu (PHP z uwierzytelnionym SMTP albo funkcja na Cloudflare lub Netlify). W `dane.yml` ustaw wtedy `usluga: "wlasny"` i adres. Obsługa ma spełniać ten kontrakt:

- przyjmuje POST z polami `email`, `phone`, `message`, `zrodlo` i `_honeypot`, jako JSON albo zwykły formularz;
- gdy żądanie ma nagłówek `Accept: application/json`, odpowiada: `200` z `{"ok": true}`, `422` z `{"errors": {"email": "komunikat"}}`, `429` albo `5xx`;
- bez tego nagłówka przekierowuje kodem `303` na `/dziekujemy/`;
- gdy pole `_honeypot` jest wypełnione, udaje sukces i niczego nie wysyła.

Plik `atrapa.rb` jest działającym przykładem tego kontraktu.

## Strona na GitHub Pages

Plik `.github/workflows/pages.yml` sprawia, że GitHub sam generuje i wystawia stronę po każdej wysyłce na gałąź `main`. Adres: `https://aky-4.github.io/breloczki/`.

Jednorazowo trzeba to włączyć w repozytorium: **Settings → Pages → Build and deployment → Source: GitHub Actions**. Przebieg każdej publikacji widać w zakładce **Actions**.

- Dopóki w `dane.yml` brakuje danych wymaganych, pod tym adresem jest wersja podglądowa (żółty pasek, wyłączona z indeksowania w Google).
- GitHub Pages dla prywatnego repozytorium wymaga płatnego planu GitHuba. Na darmowym planie repozytorium musiałoby być publiczne, a wtedy każdy widzi jego pliki i historię.
- Strona stoi tam w podfolderze `/breloczki`. Generator dostaje jego nazwę w zmiennej `SCIEZKA_BAZOWA` i dopisuje ją do wszystkich adresów. Lokalnie: `SCIEZKA_BAZOWA=/breloczki ruby buduj.rb`, a testy tak samo: `SCIEZKA_BAZOWA=/breloczki ruby sprawdz.rb`.
- Po podpięciu własnej domeny (Settings → Pages → Custom domain) podfolder znika i nic nie trzeba zmieniać w plikach poza `strona.url` w `dane.yml`.
- GitHub Pages nie obsługuje formularzy. Formularz zacznie działać po wpisaniu adresu Formspark w `dane.yml` (rozdział o formularzu wyżej).

## Przed publikacją

- [ ] Uzupełnić cztery wymagane dane w `dane.yml`.
- [ ] Potwierdzić dane z ulotki: telefon 600 818 517, e-mail, Instagram, imię i opis właściciela w sekcji „O mnie”.
- [ ] Potwierdzić okres przechowywania danych (wpisano 12 miesięcy).
- [ ] Zdobyć zgody firm na pokazanie projektów z ich logo i ustawić `zgoda: true`.
- [ ] Uzupełnić odpowiedzi na pytania czekające na dane.
- [ ] Założyć konto w usłudze formularza i wpisać adres wysyłki.
- [ ] Dać politykę prywatności do przejrzenia właścicielowi albo prawnikowi i zdecydować, czy dodać krótki regulamin.
- [ ] Uruchomić `ruby buduj.rb produkcja` i `ruby sprawdz.rb publikacja`.

## Po publikacji

- [ ] Ustawić na hostingu przekierowanie z http na https i jedną wersję adresu (z www albo bez).
- [ ] Włączyć kompresję i długie przechowywanie w pamięci podręcznej dla folderu `assets/` (pliki mają skrót treści w nazwie).
- [ ] Sprawdzić, że nieistniejący adres zwraca kod 404 i pokazuje plik `404.html`.
- [ ] Zweryfikować stronę w Google Search Console (kod można wpisać w `strona.google_site_verification`) i zgłosić `sitemap.xml`.
- [ ] Dodać stronę do Bing Webmaster Tools.
- [ ] Sprawdzić stronę w PageSpeed Insights i w teście wyników rozszerzonych Google.
- [ ] Wysłać prawdziwe zgłoszenie z formularza, z JavaScriptem i bez. Sprawdzić, że wiadomość trafia do skrzynki odbiorczej, a nie do spamu, i że odpowiedź idzie do klienta.
- [ ] Dodać nadawcę zgłoszeń do bezpiecznych nadawców w skrzynce.
- [ ] Założyć Profil Firmy w Google.
- [ ] Zrobić prawdziwe zdjęcia breloków i dodać je do galerii jako pozycje z `typ: zdjecie`.

## Zmiany na stronie

Po każdej zmianie w `dane.yml`, szablonach albo stylach uruchom `ruby buduj.rb` i `ruby sprawdz.rb`. Nową podstronę dodaje się jako wpis na liście `strony` w `dane.yml` i jako szablon w `szablony/`.
