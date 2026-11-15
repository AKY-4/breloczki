# encoding: utf-8
# Lokalny serwer podglądu z atrapą adresu formularza. Niczego nie wysyła na zewnątrz.
#   ruby atrapa.rb            -> http://localhost:8080 (serwuje folder podglad/)
#   ruby atrapa.rb 8090 publikacja
# Scenariusze odpowiedzi formularza ustawia się adresem:
#   http://localhost:8080/api/scenariusz?tryb=ok       (domyślnie: sukces)
#   .../api/scenariusz?tryb=pole     (błąd pola, kod 422)
#   .../api/scenariusz?tryb=serwer   (błąd serwera, kod 500)
#   .../api/scenariusz?tryb=limit    (za dużo zgłoszeń, kod 429)
#   .../api/scenariusz?tryb=wolno    (odpowiedź po 15 sekundach)
require "webrick"
require "json"

Encoding.default_external = Encoding::UTF_8
PORT = (ARGV[0] || 8080).to_i
FOLDER = File.expand_path(ARGV[1] || "podglad", __dir__)
abort "Brak folderu #{FOLDER}. Najpierw uruchom: ruby buduj.rb" unless File.directory?(FOLDER)

TYPY = WEBrick::HTTPUtils::DefaultMimeTypes.merge(
  "avif" => "image/avif", "woff2" => "font/woff2", "svg" => "image/svg+xml", "ico" => "image/x-icon",
  "xml" => "application/xml", "txt" => "text/plain; charset=utf-8", "html" => "text/html; charset=utf-8",
  "js" => "text/javascript; charset=utf-8"
)
$scenariusz = "ok"

class Pliki < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    sciezka = File.expand_path(File.join(FOLDER, req.path))
    sciezka = FOLDER unless sciezka.start_with?(FOLDER)
    sciezka = File.join(sciezka, "index.html") if File.directory?(sciezka)
    if File.file?(sciezka)
      res.status = 200
    else
      sciezka = File.join(FOLDER, "404.html")
      res.status = 404
    end
    res["Content-Type"] = TYPY[File.extname(sciezka).delete(".")] || "application/octet-stream"
    res["Cache-Control"] = "no-cache"
    res.body = File.binread(sciezka)
  end
  alias do_HEAD do_GET
end

class Formularz < WEBrick::HTTPServlet::AbstractServlet
  def do_POST(req, res)
    json = req["Accept"].to_s.include?("application/json")
    dane = if req.content_type.to_s.include?("application/json")
             JSON.parse(req.body.to_s) rescue {}
           else
             req.query.each_with_object({}) { |(k, v), h| h[k] = v.to_s.force_encoding("UTF-8") }
           end
    puts "\n--- zgłoszenie (scenariusz: #{$scenariusz}) ---"
    dane.each { |k, v| puts "  #{k}: #{v}" }

    bledy = {}
    bledy["email"] = "Podaj adres e-mail, np. jan@firma.pl." unless dane["email"].to_s =~ /\A[^\s@]+@[^\s@]+\.[^\s@]{2,}\z/
    bledy["message"] = "Napisz w 1–2 zdaniach, czego potrzebujesz." if dane["message"].to_s.strip.empty?
    bledy["email"] = "Ten adres e-mail został odrzucony przez serwer (scenariusz testowy)." if $scenariusz == "pole"

    sleep 15 if $scenariusz == "wolno"
    kod, tresc = if !dane["_honeypot"].to_s.empty? then [200, { "ok" => true }]
                 elsif $scenariusz == "serwer" then [500, { "ok" => false }]
                 elsif $scenariusz == "limit" then [429, { "ok" => false }]
                 elsif !bledy.empty? then [422, { "ok" => false, "errors" => bledy }]
                 else [200, { "ok" => true }]
                 end
    if json
      res.status = kod
      res["Content-Type"] = "application/json; charset=utf-8"
      res.body = JSON.generate(tresc)
    elsif kod == 200
      res.status = 303
      res["Location"] = "/dziekujemy/"
    else
      res.status = kod
      res["Content-Type"] = "text/plain; charset=utf-8"
      res.body = "Nie udało się wysłać formularza (kod #{kod}). Wróć i spróbuj ponownie."
    end
  end
end

class Scenariusz < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(req, res)
    tryb = req.query["tryb"].to_s
    $scenariusz = tryb if %w[ok pole serwer limit wolno].include?(tryb)
    res["Content-Type"] = "text/plain; charset=utf-8"
    res.body = "scenariusz: #{$scenariusz}\n"
  end
end

serwer = WEBrick::HTTPServer.new(Port: PORT, BindAddress: "127.0.0.1", AccessLog: [], Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN))
serwer.mount("/api/formularz", Formularz)
serwer.mount("/api/scenariusz", Scenariusz)
serwer.mount("/", Pliki)
trap("INT") { serwer.shutdown }
trap("TERM") { serwer.shutdown }
puts "Podgląd: http://localhost:#{PORT}  (folder: #{FOLDER}). Zatrzymanie: Ctrl+C"
serwer.start
