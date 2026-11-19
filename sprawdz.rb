# encoding: utf-8
# Skrypt kontrolny wygenerowanej strony.
#   ruby sprawdz.rb             -> sprawdza folder podglad/
#   ruby sprawdz.rb publikacja  -> sprawdza wersję do publikacji (dodatkowo: brak noindex i znaczników zastępczych)
require "json"

Encoding.default_external = Encoding::UTF_8
NAZWA = ARGV[0] || "podglad"
FOLDER = File.expand_path(NAZWA, __dir__)
PRODUKCJA = NAZWA == "publikacja"
# Podfolder strony (np. /breloczki na GitHub Pages); musi być taki sam jak przy budowaniu.
BAZA = ENV["SCIEZKA_BAZOWA"].to_s =~ %r{\A(/[\w.-]+)+\z} ? ENV["SCIEZKA_BAZOWA"] : ""
def bez_bazy(p)
  BAZA.empty? ? p : p.sub(/\A#{Regexp.escape(BAZA)}/, "")
end
abort "Brak folderu #{FOLDER}. Najpierw uruchom: ruby buduj.rb#{PRODUKCJA ? ' produkcja' : ''}" unless File.directory?(FOLDER)

$bledy = []
$ok = 0
def test(opis, warunek, szczegol = nil)
  if warunek
    $ok += 1
    puts "  ok   #{opis}"
  else
    $bledy << opis
    puts "  BŁĄD #{opis}#{szczegol ? " -> #{szczegol}" : ''}"
  end
end

def czytaj(wzgl)
  File.read(File.join(FOLDER, wzgl), encoding: "UTF-8")
end

def widoczny_tekst(html)
  t = html.gsub(%r{<(script|style|head)\b.*?</\1>}m, " ").gsub(/<[^>]+>/, " ")
  t.gsub("&nbsp;", " ").gsub(" ", " ").gsub("&#8288;", "").gsub("&#39;", "'").gsub("&quot;", '"').gsub("&lt;", "<").gsub("&gt;", ">").gsub("&amp;", "&").gsub(/\s+/, " ")
end

html = czytaj("index.html")
tekst = widoczny_tekst(html)

puts "Strona główna: znaczniki"
test "dokładnie jeden <title>", html.scan(/<title>/).size == 1
tytul = html[/<title>(.*?)<\/title>/m, 1].to_s
test "tytuł ma do 60 znaków (#{tytul.length})", tytul.length.between?(20, 60)
opisy = html.scan(/<meta name="description" content="([^"]*)"/)
test "dokładnie jeden opis meta", opisy.size == 1
test "opis meta ma 100-160 znaków (#{opisy.flatten.first.to_s.length})", opisy.flatten.first.to_s.length.between?(100, 160)
test "dokładnie jeden <h1>", html.scan(/<h1[\s>]/).size == 1
kanon = html.scan(/<link rel="canonical" href="([^"]*)"/).flatten
test "dokładnie jeden adres kanoniczny", kanon.size == 1
test "adres kanoniczny jest bezwzględny, z https i bez kotwicy", kanon.first.to_s =~ %r{\Ahttps://[^#]+/\z}
test "<html lang=\"pl\">", html =~ /<html lang="pl"/
test "znaczniki header, nav, main, footer", %w[header nav main footer].all? { |z| html =~ /<#{z}[\s>]/ }
test "każda sekcja ma etykietę", html.scan(/<section\b[^>]*>/).all? { |s| s.include?("aria-labelledby") }
poziomy = html.scan(/<h([1-6])[\s>]/).flatten.map(&:to_i)
test "nagłówki nie przeskakują poziomów", poziomy.each_cons(2).all? { |a, b| b <= a + 1 }

puts "Zgodność adresów"
og = html[/<meta property="og:url" content="([^"]*)"/, 1]
test "og:url = adres kanoniczny", og == kanon.first
mapa = czytaj("sitemap.xml")
test "mapa strony zawiera adres kanoniczny", mapa.include?("<loc>#{kanon.first}</loc>")
test "mapa strony nie zawiera /dziekujemy/ ani 404", !mapa.include?("dziekujemy") && !mapa.include?("404")
test "obraz og:image ma adres bezwzględny i istnieje", (o = html[/<meta property="og:image" content="([^"]*)"/, 1]) && o.start_with?("https://") && File.file?(File.join(FOLDER, bez_bazy(o.sub(%r{\Ahttps://[^/]+}, ""))))

puts "Dane strukturalne"
bloki = html.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).flatten
test "jeden blok JSON-LD", bloki.size == 1
ld = begin
  JSON.parse(bloki.first.to_s.gsub("<\\/", "</"))
rescue JSON::ParserError => e
  test "JSON-LD ma poprawną składnię", false, e.message
  nil
end
if ld
  test "JSON-LD ma poprawną składnię", true
  graf = ld["@graph"] || []
  typy = graf.map { |g| g["@type"] }
  test "typy: Organization, WebSite, WebPage, 2x Service, FAQPage", %w[Organization WebSite WebPage FAQPage].all? { |t| typy.include?(t) } && typy.count("Service") == 2
  test "bez Review, AggregateRating, Product, SearchAction", bloki.first !~ /"(Review|AggregateRating|Product|SearchAction)"/
  org = graf.find { |g| g["@type"] == "Organization" } || {}
  strona = graf.find { |g| g["@type"] == "WebPage" } || {}
  test "adres w JSON-LD = adres kanoniczny", strona["url"] == kanon.first && org["url"] == kanon.first
  cyfry = org["telephone"].to_s.gsub(/\D/, "").sub(/\A48/, "")
  test "telefon z JSON-LD jest w widocznej treści", !cyfry.empty? && tekst.gsub(/\s/, "").include?(cyfry)
  test "e-mail z JSON-LD jest w widocznej treści", tekst.include?(org["email"].to_s)
  ceny = graf.select { |g| g["@type"] == "Service" }.flat_map { |s| ((s["hasOfferCatalog"] || {})["itemListElement"] || []).map { |o| o["price"] } }
  test "ceny z JSON-LD (#{ceny.join(', ')}) są w widocznej treści", !ceny.empty? && ceny.all? { |c| tekst =~ /\b#{c} zł/ }
  faq = graf.find { |g| g["@type"] == "FAQPage" } || {}
  pytania = (faq["mainEntity"] || [])
  test "każde pytanie i odpowiedź z FAQPage są w widocznej treści (#{pytania.size})", !pytania.empty? && pytania.all? { |q|
    tekst.include?(q["name"]) && tekst.include?(q["acceptedAnswer"]["text"]) }
end

puts "Obrazy, kotwice, zasoby"
obrazy = html.scan(/<img\b[^>]*>/)
test "każdy obraz ma alt, width i height (#{obrazy.size})", obrazy.all? { |i| i =~ /\balt="/ && i =~ /\bwidth="\d+"/ && i =~ /\bheight="\d+"/ }
lokalne = html.scan(/(?:src|srcset|href)="(\/[^"#?]*)"/).flatten.uniq.reject { |p| p.end_with?("/") }
brak = lokalne.reject { |p| File.file?(File.join(FOLDER, bez_bazy(p))) }
test "wszystkie lokalne pliki istnieją (#{lokalne.size})", brak.empty?, brak.join(", ")
ids = html.scan(/\bid="([^"]+)"/).flatten
test "identyfikatory są unikalne", ids.uniq.size == ids.size, ids.select { |i| ids.count(i) > 1 }.uniq.join(", ")
kotwice = html.scan(/href="#([^"]+)"/).flatten.uniq
test "każda kotwica prowadzi do istniejącej sekcji (#{kotwice.size})", (kotwice - ids).empty?, (kotwice - ids).join(", ")
wszystkie_html = Dir.glob(File.join(FOLDER, "**", "*.html"))
obce = wszystkie_html.flat_map do |p|
  t = File.read(p, encoding: "UTF-8")
  t.scan(/<(?:script|img|source|iframe|video|audio|embed)\b[^>]*\b(?:src|srcset)="(https?:\/\/[^"]+)"/).flatten +
    t.scan(/<link\b[^>]*\brel="(?:stylesheet|preload|icon|apple-touch-icon)"[^>]*\bhref="(https?:\/\/[^"]+)"/).flatten +
    t.scan(/url\((https?:\/\/[^)]+)\)/).flatten + t.scan(/@import[^;]+/)
end
test "brak zasobów ładowanych z obcych domen", obce.empty?, obce.uniq.join(", ")
test "czcionki WOFF2 hostowane lokalnie z licencją", Dir.glob(File.join(FOLDER, "assets", "czcionki", "*.woff2")).size == 2 && File.file?(File.join(FOLDER, "assets", "czcionki", "OFL.txt"))
test "favicon.ico, ikona PNG i apple-touch-icon", %w[favicon.ico ikona-192.png apple-touch-icon.png].all? { |f| File.file?(File.join(FOLDER, f)) }

puts "Formularz"
form = html[/<form\b.*?<\/form>/m].to_s
test "formularz: method post i adres wysyłki", form =~ /method="post"/ && form =~ /action="[^"]+"/
test "pola email, phone, message z etykietami", %w[f-email f-telefon f-opis].all? { |i| form.include?(%(for="#{i}")) && form.include?(%(id="#{i}")) }
test "autocomplete email i tel", form.include?('autocomplete="email"') && form.include?('autocomplete="tel"')
test "pole pułapka", form.include?('name="_honeypot"')
test "link do polityki prywatności przy formularzu", form.include?(%(href="#{BAZA}/polityka-prywatnosci/"))
test "brak pól wyboru ze zgodami", form !~ /type="checkbox"/

puts "Podstrony i pliki dla robotów"
polityka = czytaj("polityka-prywatnosci/index.html")
dziekuje = czytaj("dziekujemy/index.html")
blad404 = czytaj("404.html")
tytuly = [html, polityka, dziekuje, blad404].map { |t| t[/<title>(.*?)<\/title>/m, 1] }
test "podstrony mają różne tytuły", tytuly.uniq.size == 4
test "/dziekujemy/ i 404 mają noindex", dziekuje.include?('content="noindex"') && blad404.include?('content="noindex"')
robots = czytaj("robots.txt")
if PRODUKCJA
  test "strona główna i polityka bez noindex", !html.include?("noindex") && !polityka.include?("noindex")
  test "strona główna bez nosnippet i max-snippet", html !~ /nosnippet|max-snippet/
  test "robots.txt pozwala na wszystko i wskazuje mapę strony", robots.include?("Allow: /") && robots =~ %r{Sitemap: https://\S+/sitemap\.xml} && robots !~ /Disallow: \/\s*$/
  zastepcze = (wszystkie_html + [File.join(FOLDER, "sitemap.xml"), File.join(FOLDER, "robots.txt")]).select do |p|
    t = File.read(p, encoding: "UTF-8")
    t.include?("do uzupełnienia") || t.include?("do-uzupelnienia") || t.include?(".example") || t.include?("czeka na")
  end
  test "brak znaczników zastępczych", zastepcze.empty?, zastepcze.join(", ")
else
  test "podgląd: strona główna ma noindex, robots.txt blokuje indeksowanie", html.include?('content="noindex"') && robots.include?("Disallow: /")
end

puts "Treść"
slowa = tekst.split.size
test "pierwsze 100 słów mówi kto, co, dla kogo i gdzie", (p100 = tekst.split.first(110).join(" ")) && p100.include?("3D things") && p100.include?("Grodziska Mazowieckiego") && p100 =~ /breloki/i
test "nie ma zakazanych sformułowań", tekst !~ /bryloczk|najtańsz|najlepsz|nr 1|★★★★★|zaufali nam|nasi klienci|z nadrukiem logo/i, tekst.scan(/bryloczk\w*|najtańsz\w*|najlepsz\w*|nr 1|zaufali nam|nasi klienci/i).uniq.join(", ")
test "frazy kluczowe w treści", ["breloki 3D z logo", "na zamówienie", "druk 3D", "od 20 sztuk", "tabliczka NFC do opinii Google", "Grodzisk"].all? { |f| tekst.downcase.include?(f.downcase) }
puts "  info liczba słów widocznej treści strony głównej: #{slowa}"

puts "Waga"
kb = ->(p) { (File.size(p) / 1024.0).round(1) }
html_kb = kb.(File.join(FOLDER, "index.html"))
test "HTML strony głównej poniżej 100 KB (#{html_kb} KB)", html_kb < 100
js = Dir.glob(File.join(FOLDER, "assets", "js", "*.js"))
js_kb = js.map { |p| kb.(p) }.sum.round(1)
test "JavaScript poniżej 15 KB (#{js_kb} KB)", js_kb < 15
# W <picture> przeglądarka pobiera pierwsze źródło (AVIF), a nie zapasowy obraz z <img>.
html_pierwsze = html.gsub(/<picture>\s*<source\b[^>]*srcset="([^"]+)"[^>]*>\s*<img\b([^>]*?)src="[^"]+"([^>]*)>\s*<\/picture>/m) { %(<img#{$2}src="#{$1}"#{$3}>) }
leniwe = html_pierwsze.scan(/<img\b[^>]*loading="lazy"[^>]*>/).map { |i| i[/src="([^"]+)"/, 1] }
pierwsze = (html_pierwsze.scan(/<img\b[^>]*src="(\/[^"]+)"/).flatten - leniwe).uniq
czcionki = Dir.glob(File.join(FOLDER, "assets", "czcionki", "*.woff2"))
suma = html_kb + js_kb + czcionki.map { |p| kb.(p) }.sum + pierwsze.map { |p| kb.(File.join(FOLDER, bez_bazy(p))) }.sum
test "pierwsze wczytanie poniżej 300 KB (#{suma.round(1)} KB bez kompresji)", suma < 300

puts
if $bledy.empty?
  puts "Wszystkie testy przeszły (#{$ok})."
else
  puts "Nie przeszło #{$bledy.size} z #{$ok + $bledy.size} testów:"
  $bledy.each { |b| puts "  - #{b}" }
  exit 1
end
