# Strona 3D things: wskazówki dla Claude

Statyczna strona one page (breloki 3D z logo firmy, tabliczki NFC do opinii Google). Cel: widoczność w Google i wysłany formularz wyceny.

## Polecenia

- `ruby buduj.rb` generuje podgląd do `podglad/`; `ruby buduj.rb produkcja` generuje `publikacja/` i przerywa, gdy brakuje danych wymaganych.
- `ruby sprawdz.rb` (albo `ruby sprawdz.rb publikacja`) uruchamia testy wygenerowanej strony. Uruchamiaj po każdej zmianie.
- `ruby atrapa.rb` serwuje `podglad/` na `http://localhost:8080` z atrapą formularza; scenariusze: `/api/scenariusz?tryb=ok|pole|serwer|limit|wolno`.

## Środowisko

Na tym Macu nie ma Node.js, Pythona, PHP ani Gita. Niczego nie instaluj bez pytania. Nie wywołuj `python3` ani `git`: to atrapy, które otwierają okno instalatora. Działa systemowy Ruby 2.6 (bez `filter_map`, `tally` i składni z nowszych wersji), `sips`, `qlmanage`, `perl`, `curl`. Skrypty Ruby z polskimi znakami wymagają `# encoding: utf-8`; `ruby -e` z polskimi znakami nie działa.

## Gdzie co jest

- `dane.yml`: jedyne źródło danych i treści zmiennych (kontakt, sprzedawca, ceny, FAQ, galeria, formularz, lista stron). Tych samych wartości nie wpisuj ręcznie w szablonach.
- `szablony/uklad.erb`: wspólny układ; `szablony/sekcje/*.erb`: sekcje strony głównej, nagłówek i stopka.
- `zasoby/css/styl.css` trafia w całości do `<head>`; odwołania do plików zapisuj jako `zasob(sciezka)`.
- `buduj.rb` dodaje skrót treści do nazw plików, twarde spacje w tekście i JSON-LD.
- Materiały marki są w `../3D things - paczka/` i są tylko do odczytu. Wzorzec wyglądu to `07 Pliki zrodlowe (generatory)/ulotka_3dthings.html`.

## Zasady treści

- Nie wymyślaj danych firmy, cen, terminów ani opinii. Brak danej oznacza, że zależna treść się nie pojawia.
- Opinie w Google: nie obiecuj pięciu gwiazdek, liczby opinii ani pozycji w Mapach; nie proponuj nagród za opinie. Pisz, że tabliczka skraca drogę do formularza opinii, a o ocenie decyduje klient.
- NFC: „zbliż telefon i dotknij powiadomienia”; działa na iPhone'ach XS i nowszych oraz na Androidzie z włączonym NFC. O kodzie QR pisz tylko wtedy, gdy `oferta.tabliczka_qr` jest `true`.
- Bez logo Google i litery „G”. Bez „najlepsze”, „najtańsze”, „nr 1”. Bez zmyślonych liczników i logotypów klientów.
- Galeria: podpisy mówią o branży, etykieta to „wizualizacja projektu”; nie pisz „klienci” ani „realizacje”. Pozycja bez `zgoda: true` nie trafia do publikacji.
- Słowo podstawowe to „breloki”; nie „bryloczki” i nie „brelok z nadrukiem”.
- Strona nie ładuje zasobów z obcych serwerów, nie używa plików cookie i nie ma banera cookies.

## Wygląd

Kolory, krój Jost i kształty są zdefiniowane na początku `zasoby/css/styl.css`. Bez gradientów, rozmytych cieni, kursywy w nagłówkach i ciemnego motywu. Animacje (na życzenie właściciela): ilustracje w sekcji startowej odsłaniają się płynnie od dołu z fioletową linią „dyszy”, karty przy przewijaniu płynnie się pojawiają (przezroczystość i lekkie przesunięcie), plus krótkie przejścia na przyciskach, menu i pytaniach. Nie używaj `steps()` ani skokowych animacji: właściciel odebrał je jako zacinanie się strony. Wszystko wyłącza się przy `prefers-reduced-motion`. Stan oczekiwania elementu to `opacity:0`, nie `clip-path`, bo przycięty element nie zgłasza się w IntersectionObserver. Formularz nie jest animowany. Pomarańcz, żółty, mięta i róż służą tylko do dekoracji, nie do tekstu.
