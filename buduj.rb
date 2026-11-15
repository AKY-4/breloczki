# encoding: utf-8
# Generator strony 3D things. Działa na systemowym Ruby z macOS, bez instalowania czegokolwiek.
#   ruby buduj.rb            -> podgląd w folderze podglad/ (braki zastąpione przykładami, noindex)
#   ruby buduj.rb produkcja  -> wersja do publikacji w folderze publikacja/ (przerywa, gdy brakuje danych)
require "erb"
require "yaml"
require "json"
require "fileutils"
require "digest"

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

KATALOG = File.expand_path(__dir__)
TRYB = ARGV[0] == "produkcja" ? :produkcja : :podglad
WYJSCIE = File.join(KATALOG, TRYB == :produkcja ? "publikacja" : "podglad")
ZNACZNIK_URL = "https://domena-do-uzupelnienia.example"
ZNACZNIK = "do uzupełnienia"

def wczytaj(sciezka)
  File.read(File.join(KATALOG, sciezka), encoding: "UTF-8")
end

DANE = YAML.load(wczytaj("dane.yml"))

def puste?(v)
  v.nil? || v.to_s.strip.empty?
end

# ---------- kontrola danych wymaganych do publikacji ----------
def braki(d)
  b = []
  b << "strona.url: pełny adres strony z https, bez ukośnika na końcu" unless d["strona"]["url"].to_s =~ %r{\Ahttps://[^/\s]+\z}
  b << "formularz.adres: adres wysyłki formularza" unless d["formularz"]["adres"].to_s =~ %r{\A(https://|/)\S+\z}
  b << "formularz.usluga: formspark albo wlasny" unless %w[formspark wlasny].include?(d["formularz"]["usluga"])
  s = d["sprzedawca"]
  wymagane = { "jdg" => %w[nazwa adres nip], "nierejestrowana" => %w[imie_nazwisko adres],
               "spzoo" => %w[nazwa adres nip krs sad_rejestrowy kapital_zakladowy] }
  if wymagane.key?(s["forma_prawna"])
    wymagane[s["forma_prawna"]].each { |k| b << "sprzedawca.#{k}" if puste?(s[k]) }
  else
    b << "sprzedawca.forma_prawna: jdg, nierejestrowana albo spzoo"
  end
  b << "ceny.vat: netto, brutto albo zwolniony" unless %w[netto brutto zwolniony].include?(d["ceny"]["vat"])
  b << "kontakt.telefon" if puste?(d["kontakt"]["telefon"])
  b << "kontakt.email" if puste?(d["kontakt"]["email"])
  b << "rodo.okres_przechowywania" if puste?(d["rodo"]["okres_przechowywania"])
  b
end

if TRYB == :produkcja
  lista = braki(DANE)
  unless lista.empty?
    warn "Nie można wygenerować wersji do publikacji. Uzupełnij w pliku dane.yml:"
    lista.each { |x| warn "  - #{x}" }
    exit 1
  end
end

# ---------- kontekst szablonów ----------
class Kontekst
  attr_reader :d, :strona_biezaca
  attr_accessor :tresc

  def initialize(dane, zasoby)
    @d = dane
    @zasoby = zasoby
  end

  def podglad?
    TRYB == :podglad
  end

  def h(tekst)
    ERB::Util.html_escape(tekst.to_s)
  end

  def render(nazwa)
    ERB.new(wczytaj("szablony/#{nazwa}.erb"), nil, "-").result(binding)
  end

  def ustaw_strone(s)
    @strona_biezaca = s
  end

  def zasob(sciezka)
    @zasoby.fetch(sciezka) { raise "Brak zasobu: #{sciezka}" }
  end

  def adres_strony
    puste?(d["strona"]["url"]) ? ZNACZNIK_URL : d["strona"]["url"]
  end

  def bezwzgledny(sciezka)
    adres_strony + sciezka
  end

  def tytul
    strona_biezaca["tytul"] || d["strona"]["tytul"]
  end

  def opis
    strona_biezaca["opis"] || d["strona"]["opis"]
  end

  def indeksowana?
    !podglad? && strona_biezaca["indeksowana"]
  end

  def glowna?
    strona_biezaca["sciezka"] == "/"
  end

  # odsyłacz do sekcji strony głównej, działa także z podstron
  def kotwica(id)
    glowna? ? "##{id}" : "/##{id}"
  end

  def telefon
    d["kontakt"]["telefon"]
  end

  def telefon_href
    "tel:+48" + telefon.gsub(/\D/, "")
  end

  def telefon_miedzynarodowy
    "+48" + telefon.gsub(/\D/, "")
  end

  def email
    d["kontakt"]["email"]
  end

  def progi
    d["ceny"]["progi"]
  end

  def cena_min
    progi.map { |p| p["cena"] }.min
  end

  def vat_etykieta
    case d["ceny"]["vat"]
    when "netto" then "Ceny netto, do ceny doliczany jest VAT."
    when "brutto" then "Ceny brutto, zawierają VAT."
    when "zwolniony" then "Ceny końcowe: sprzedawca jest zwolniony z VAT, podatek nie jest doliczany."
    else "[#{ZNACZNIK}: ceny netto, brutto albo zwolnienie z VAT]"
    end
  end

  def administrator
    s = d["sprzedawca"]
    nazwa = s["forma_prawna"] == "nierejestrowana" ? s["imie_nazwisko"] : s["nazwa"]
    return "[#{ZNACZNIK}: nazwa albo imię i nazwisko, adres]" if puste?(nazwa) || puste?(s["adres"])
    "#{nazwa}, #{s['adres']}"
  end

  def sprzedawca_stopka
    s = d["sprzedawca"]
    case s["forma_prawna"]
    when "jdg" then "#{s['nazwa']}, #{s['adres']}, NIP #{s['nip']}"
    when "nierejestrowana" then "#{s['imie_nazwisko']}, #{s['adres']}, e-mail: #{email}"
    when "spzoo" then "#{s['nazwa']}, #{s['adres']}, #{s['sad_rejestrowy']}, KRS #{s['krs']}, NIP #{s['nip']}, kapitał zakładowy #{s['kapital_zakladowy']}"
    else "[#{ZNACZNIK}: dane sprzedawcy zależne od formy prawnej]"
    end
  end

  def formularz_adres
    puste?(d["formularz"]["adres"]) ? "/api/formularz" : d["formularz"]["adres"]
  end

  def formularz_usluga
    puste?(d["formularz"]["adres"]) ? "wlasny" : d["formularz"]["usluga"]
  end

  def wartosci_faq
    { c1: progi[0]["cena"], c2: progi[1]["cena"], c3: progi[2]["cena"] }
  end

  def faq_opublikowane
    d["faq"].select { |f| f["opublikowane"] && !puste?(f["odpowiedz"]) }
            .map { |f| f.merge("odpowiedz" => format(f["odpowiedz"], wartosci_faq)) }
  end

  def faq_czekajace
    d["faq"].reject { |f| f["opublikowane"] && !puste?(f["odpowiedz"]) }
  end

  def galeria
    ze_zgoda = d["galeria"].select { |g| g["zgoda"] }
    return d["galeria"] if podglad?
    ze_zgoda.size >= 4 ? ze_zgoda : []
  end

  def oferta(klucz)
    v = d["oferta"][klucz]
    puste?(v) || v == false ? nil : v
  end

  DEKO = {
    "kolo" => %q{<circle cx="10" cy="10" r="10"/>},
    "pierscien" => %q{<circle cx="10" cy="10" r="8" fill="none" stroke="currentColor" stroke-width="3.400"/>},
    "paski" => %q{<rect x="2" y="2" width="16" height="2.800" rx="1.400"/><rect x="0" y="8.600" width="20" height="2.800" rx="1.400"/><rect x="2" y="15.200" width="16" height="2.800" rx="1.400"/>},
    "gwiazdka" => %q{<path d="M10 0l2.900 6.300 6.900.800-5.100 4.700 1.400 6.800L10 15.200 3.900 18.600l1.400-6.800L.200 7.100l6.900-.800z"/>},
    "kropki" => %q{<circle cx="3" cy="3" r="2.600"/><circle cx="13" cy="3" r="2.600"/><circle cx="3" cy="13" r="2.600"/><circle cx="13" cy="13" r="2.600"/><circle cx="3" cy="23" r="2.600"/><circle cx="13" cy="23" r="2.600"/>},
    "falka" => %q{<path d="M2 8q5-8 10 0t10 0t10 0" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>}
  }
  DEKO_POLE = { "kropki" => "0 0 16 26", "falka" => "0 0 34 16" }

  def deko(ksztalt, kolor, klasa)
    %(<svg class="deko #{klasa}" viewBox="#{DEKO_POLE[ksztalt] || "0 0 20 20"}" aria-hidden="true" focusable="false" style="color:#{kolor}" fill="currentColor">#{DEKO[ksztalt]}</svg>)
  end

  def jsonld
    url = adres_strony
    org = { "@type" => "Organization", "@id" => "#{url}/#organizacja", "name" => d["strona"]["nazwa"], "url" => "#{url}/",
            "logo" => bezwzgledny("/ikona-192.png"), "image" => bezwzgledny("/3dthings-breloki-z-logo.png"),
            "description" => d["strona"]["opis"], "telephone" => telefon_miedzynarodowy, "email" => email,
            "sameAs" => [d["kontakt"]["instagram_url"]],
            "founder" => { "@type" => "Person", "name" => d["wlasciciel"]["imie"] },
            "areaServed" => { "@type" => "Country", "name" => "Polska" } }
    s = d["sprzedawca"]
    unless podglad?
      org["legalName"] = s["forma_prawna"] == "nierejestrowana" ? s["imie_nazwisko"] : s["nazwa"]
      org["vatID"] = s["nip"] unless puste?(s["nip"])
    end
    oferty = progi.map do |p|
      ilosc = { "@type" => "QuantitativeValue", "minValue" => p["od"], "unitText" => "szt." }
      ilosc["maxValue"] = p["do"] if p["do"]
      { "@type" => "Offer", "name" => "Breloki z logo, #{p['etykieta']}", "price" => p["cena"], "priceCurrency" => d["ceny"]["waluta"],
        "eligibleQuantity" => ilosc }
    end
    graf = [
      org,
      { "@type" => "WebSite", "@id" => "#{url}/#witryna", "name" => d["strona"]["nazwa"], "url" => "#{url}/", "inLanguage" => "pl-PL",
        "publisher" => { "@id" => "#{url}/#organizacja" } },
      { "@type" => "WebPage", "@id" => "#{url}/#strona", "url" => "#{url}/", "name" => d["strona"]["tytul"],
        "description" => d["strona"]["opis"], "inLanguage" => "pl-PL", "dateModified" => d["strona"]["data_zmiany"],
        "isPartOf" => { "@id" => "#{url}/#witryna" }, "about" => { "@id" => "#{url}/#organizacja" } },
      { "@type" => "Service", "@id" => "#{url}/#breloki", "name" => "Breloki 3D z logo firmy", "serviceType" => "Projektowanie i druk 3D breloków z logo firmy",
        "provider" => { "@id" => "#{url}/#organizacja" }, "areaServed" => { "@type" => "Country", "name" => "Polska" },
        "hasOfferCatalog" => { "@type" => "OfferCatalog", "name" => "Cennik breloków z logo", "itemListElement" => oferty } },
      { "@type" => "Service", "@id" => "#{url}/#tabliczki-nfc", "name" => "Tabliczka NFC do opinii Google z logo firmy",
        "serviceType" => "Projektowanie i druk 3D tabliczek NFC z logo firmy",
        "provider" => { "@id" => "#{url}/#organizacja" }, "areaServed" => { "@type" => "Country", "name" => "Polska" } },
      { "@type" => "FAQPage", "@id" => "#{url}/#pytania",
        "mainEntity" => faq_opublikowane.map { |f|
          { "@type" => "Question", "name" => f["pytanie"], "acceptedAnswer" => { "@type" => "Answer", "text" => f["odpowiedz"] } } } }
    ]
    JSON.pretty_generate("@context" => "https://schema.org", "@graph" => graf).gsub("</", "<\\/")
  end
end

# ---------- polska typografia w tekście widocznym ----------
def typografia_tekst(t)
  t = t.gsub(/(?<![[:alnum:]])([aiouwzAIOUWZ]) (?=\S)/) { "#{$1}&nbsp;" }
  t = t.gsub(/(\d) (zł|szt\.|sztuk|sztukach|mm|px|dni|dniach|kolory|miesięcy)/) { "#{$1}&nbsp;#{$2}" }
  t = t.gsub(/\b(ok\.|np\.|art\.|ust\.|lit\.|ul\.) (?=\S)/) { "#{$1}&nbsp;" }
  t
end

def typografia(html)
  czesci = html.split(%r{(<script\b.*?</script>|<style\b.*?</style>|<textarea\b.*?</textarea>|<title>.*?</title>)}m)
  czesci.map.with_index do |cz, i|
    next cz if i.odd?
    cz.gsub(/>([^<]+)</) { ">" + typografia_tekst($1) + "<" }
  end.join
end

# ---------- zasoby ze skrótem treści w nazwie ----------
FileUtils.rm_rf(WYJSCIE)
FileUtils.mkdir_p(File.join(WYJSCIE, "assets"))
zasoby = {}
W_KATALOGU_GLOWNYM = { "img/favicon.ico" => "favicon.ico", "img/apple-touch-icon.png" => "apple-touch-icon.png",
                       "img/ikona-192.png" => "ikona-192.png", "img/3dthings-breloki-z-logo.png" => "3dthings-breloki-z-logo.png" }
Dir.glob(File.join(KATALOG, "zasoby", "**", "*")).sort.each do |plik|
  next if File.directory?(plik)
  wzgl = plik.sub(File.join(KATALOG, "zasoby") + "/", "")
  next if wzgl.start_with?("css/")
  if W_KATALOGU_GLOWNYM.key?(wzgl)
    FileUtils.cp(plik, File.join(WYJSCIE, W_KATALOGU_GLOWNYM[wzgl]))
    zasoby[wzgl] = "/" + W_KATALOGU_GLOWNYM[wzgl]
    next
  end
  if wzgl.end_with?("OFL.txt")
    FileUtils.mkdir_p(File.join(WYJSCIE, "assets", "czcionki"))
    FileUtils.cp(plik, File.join(WYJSCIE, "assets", "czcionki", "OFL.txt"))
    next
  end
  skrot = Digest::MD5.file(plik).hexdigest[0, 8]
  roz = File.extname(wzgl)
  cel = wzgl.sub(/#{Regexp.escape(roz)}\z/, ".#{skrot}#{roz}")
  FileUtils.mkdir_p(File.dirname(File.join(WYJSCIE, "assets", cel)))
  FileUtils.cp(plik, File.join(WYJSCIE, "assets", cel))
  zasoby[wzgl] = "/assets/" + cel
end

css = wczytaj("zasoby/css/styl.css")
css = css.gsub(/zasob\(([^)]+)\)/) { zasoby.fetch($1.strip) }
css = css.gsub(%r{/\*.*?\*/}m, "").gsub(/\s+/, " ").gsub(/\s*([{};:,>])\s*/, '\1').gsub(";}", "}").strip
zasoby["css"] = css

# ---------- strony ----------
kontekst = Kontekst.new(DANE, zasoby)
DANE["strony"].each do |s|
  kontekst.ustaw_strone(s)
  kontekst.tresc = kontekst.render(s["szablon"])
  html = typografia(kontekst.render("uklad"))
  cel = s["sciezka"].end_with?("/") ? File.join(WYJSCIE, s["sciezka"], "index.html") : File.join(WYJSCIE, s["sciezka"])
  FileUtils.mkdir_p(File.dirname(cel))
  File.write(cel, html)
end

# ---------- robots.txt i mapa strony ----------
url = kontekst.adres_strony
if TRYB == :produkcja
  File.write(File.join(WYJSCIE, "robots.txt"), "User-agent: *\nAllow: /\n\nSitemap: #{url}/sitemap.xml\n")
else
  File.write(File.join(WYJSCIE, "robots.txt"), "# Wersja podglądowa: nie do indeksowania\nUser-agent: *\nDisallow: /\n")
end
wpisy = DANE["strony"].select { |s| s["w_mapie"] }.map do |s|
  "  <url>\n    <loc>#{url}#{s['sciezka']}</loc>\n    <lastmod>#{DANE['strona']['data_zmiany']}</lastmod>\n  </url>"
end
File.write(File.join(WYJSCIE, "sitemap.xml"),
           "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n#{wpisy.join("\n")}\n</urlset>\n")

# ---------- ostatnia kontrola wersji do publikacji ----------
if TRYB == :produkcja
  zle = Dir.glob(File.join(WYJSCIE, "**", "*.{html,txt,xml}")).reject { |p| p.end_with?("OFL.txt") }.select do |p|
    t = File.read(p, encoding: "UTF-8")
    t.include?(ZNACZNIK) || t.include?("do-uzupelnienia") || t.include?("czeka na")
  end
  unless zle.empty?
    warn "W wersji do publikacji zostały znaczniki zastępcze: #{zle.join(', ')}"
    exit 1
  end
end

puts "Gotowe (#{TRYB}): #{WYJSCIE}"
puts "Uwaga: to wersja podglądowa z noindex. Braki do publikacji:\n  - " + braki(DANE).join("\n  - ") if TRYB == :podglad && !braki(DANE).empty?
