/* Skrypt strony 3D things. Tylko ulepsza: cała treść i formularz działają bez niego. */
(function () {
  "use strict";
  var start = Date.now();

  /* Jedno miejsce na zdarzenia do statystyk. Dziś nic nie robi; po wyborze narzędzia podepnij je tutaj.
     Nie przekazuj tu danych osobowych. */
  function zdarzenie(nazwa, dane) {
    void nazwa; void dane;
  }

  /* ---------- menu na telefonie ---------- */
  var menu = document.querySelector("[data-menu]");
  var nawigacja = document.getElementById("nawigacja");
  if (menu && nawigacja) {
    menu.addEventListener("click", function () {
      var otwarte = nawigacja.classList.toggle("otwarta");
      menu.setAttribute("aria-expanded", otwarte ? "true" : "false");
    });
    nawigacja.addEventListener("click", function (e) {
      if (e.target.closest("a")) {
        nawigacja.classList.remove("otwarta");
        menu.setAttribute("aria-expanded", "false");
      }
    });
  }

  /* ---------- źródło zgłoszenia i zdarzenia kliknięć ---------- */
  var poleZrodla = document.querySelector("[data-zrodlo-pole]");
  document.addEventListener("click", function (e) {
    var cta = e.target.closest("a[data-zrodlo]");
    if (cta) {
      if (poleZrodla) poleZrodla.value = cta.getAttribute("data-zrodlo");
      zdarzenie("klik_do_formularza", { miejsce: cta.getAttribute("data-zrodlo") });
    }
    var kontakt = e.target.closest("a[data-zdarzenie]");
    if (kontakt) zdarzenie("klik_kontakt", { rodzaj: kontakt.getAttribute("data-zdarzenie") });
  });

  /* ---------- pasek z przyciskiem na telefonie ---------- */
  var pasek = document.querySelector("[data-pasek-cta]");
  var sekcjaWyceny = document.getElementById("wycena");
  if (pasek && sekcjaWyceny && "IntersectionObserver" in window) {
    new IntersectionObserver(function (wpisy) {
      pasek.classList.toggle("ukryty", wpisy[0].isIntersecting);
    }, { threshold: 0.05 }).observe(sekcjaWyceny);
  }

  /* ---------- kalkulator ---------- */
  var kalk = document.querySelector("[data-kalkulator]");
  var poleOpisu = document.getElementById("f-opis");
  if (kalk) {
    var progi = JSON.parse(kalk.getAttribute("data-progi"));
    var ile = kalk.querySelector("input");
    var elCena = kalk.querySelector("[data-kalk-cena]");
    var elSuma = kalk.querySelector("[data-kalk-suma]");
    var elPodp = kalk.querySelector("[data-kalk-podpowiedz]");
    var elCta = kalk.querySelector("[data-kalk-cta]");
    var suwak = kalk.querySelector("[data-kalk-suwak]");
    var kafleProgow = document.querySelectorAll("[data-prog-od]");
    var minimum = progi[0].od;
    var uzyty = false;

    var cenaDla = function (n) {
      var c = progi[0].cena;
      progi.forEach(function (p) { if (n >= p.od) c = p.cena; });
      return c;
    };
    var zl = function (n) { return n.toLocaleString("pl-PL") + " zł"; };

    var przelicz = function () {
      var n = parseInt(ile.value, 10);
      if (isNaN(n) || n < minimum) n = minimum;
      if (n > 5000) n = 5000;
      var cena = cenaDla(n);
      var suma = n * cena;
      elCena.textContent = zl(cena);
      elSuma.textContent = zl(suma);
      var lepszy = null;
      progi.forEach(function (p) {
        if (p.od > n && p.od * p.cena < suma && !lepszy) lepszy = p;
      });
      if (lepszy) {
        elPodp.textContent = lepszy.od + " szt. kosztuje " + zl(lepszy.od * lepszy.cena) + ", czyli mniej niż " + n + " szt. (" + zl(suma) + ").";
        elPodp.hidden = false;
      } else {
        elPodp.hidden = true;
      }
      elCta.textContent = "Zapytaj o wycenę " + n + " szt.";
      elCta.setAttribute("data-ile", String(n));
      if (suwak) suwak.value = String(Math.min(n, parseInt(suwak.max, 10)));
      var progOd = progi[0].od;
      progi.forEach(function (p) { if (n >= p.od) progOd = p.od; });
      Array.prototype.forEach.call(kafleProgow, function (el) {
        el.classList.toggle("prog--aktywny", parseInt(el.getAttribute("data-prog-od"), 10) === progOd);
      });
      return n;
    };
    var ustaw = function (n) {
      ile.value = String(Math.max(minimum, Math.min(5000, n)));
      przelicz();
      if (!uzyty) { uzyty = true; zdarzenie("kalkulator"); }
    };

    kalk.hidden = false;
    przelicz();
    ile.addEventListener("input", function () { przelicz(); if (!uzyty) { uzyty = true; zdarzenie("kalkulator"); } });
    ile.addEventListener("change", function () { ustaw(parseInt(ile.value, 10) || minimum); });
    if (suwak) suwak.addEventListener("input", function () { ustaw(parseInt(suwak.value, 10)); });
    kalk.addEventListener("click", function (e) {
      var b = e.target.closest("button");
      if (!b) return;
      if (b.hasAttribute("data-krok")) ustaw((parseInt(ile.value, 10) || minimum) + parseInt(b.getAttribute("data-krok"), 10));
      if (b.hasAttribute("data-ile")) ustaw(parseInt(b.getAttribute("data-ile"), 10));
    });
    elCta.addEventListener("click", function () {
      if (!poleOpisu) return;
      var zdanie = "Proszę o wycenę: " + elCta.getAttribute("data-ile") + " szt. breloków z logo.";
      var obecny = poleOpisu.value.replace(/Proszę o wycenę: \d+ szt\. breloków z logo\.\s*/, "");
      poleOpisu.value = zdanie + (obecny ? " " + obecny : " ");
    });
  }

  /* ---------- efekt druku 3D przy przewijaniu ----------
     Elementy poniżej pierwszego ekranu są ukrywane i „drukują się" warstwami, gdy wejdą w pole widzenia.
     Formularz nie bierze w tym udziału, żeby nigdy nie został ukryty. */
  var bezRuchu = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (!bezRuchu && "IntersectionObserver" in window) {
    var doDruku = document.querySelectorAll(".karta:not(.wycena__formularz), .kafel, .prog, .wiersz-nfc, .krok, .pytanie, .o-mnie, .kontakt, .pole-ilustracji, .czeka-na-dane");
    var obserwator = new IntersectionObserver(function (wpisy) {
      wpisy.forEach(function (w) {
        var el = w.target;
        if (w.isIntersecting) {
          if (el.classList.contains("druk-czeka")) {
            el.classList.remove("druk-czeka");
            el.classList.add("druk-start");
            el.addEventListener("animationend", function () { el.classList.remove("druk-start"); }, { once: true });
          }
          obserwator.unobserve(el);
        } else if (!el.classList.contains("druk-czeka")) {
          el.classList.add("druk-czeka");
        }
      });
    }, { rootMargin: "0px 0px -6% 0px", threshold: 0.1 });
    Array.prototype.forEach.call(doDruku, function (el) {
      var nr = Array.prototype.indexOf.call(el.parentNode.children, el);
      el.style.setProperty("--i", String(Math.min(nr, 5)));
      obserwator.observe(el);
    });
  }

  /* ---------- nagranie z druku: gra tylko wtedy, gdy je widać ---------- */
  var film = document.querySelector("[data-nagranie]");
  if (film && !bezRuchu && "IntersectionObserver" in window) {
    new IntersectionObserver(function (wpisy) {
      if (wpisy[wpisy.length - 1].intersectionRatio >= 0.5) {
        var proba = film.play();
        if (proba && proba.catch) proba.catch(function () {});
      } else {
        film.pause();
      }
    }, { threshold: [0, 0.5] }).observe(film);
  }

  /* ---------- obracane breloki: nazwa firmy na breloku ---------- */
  var ramka = document.querySelector("[data-breloki-ramka]");
  var poleNazwy = document.querySelector("[data-breloki-nazwa]");
  if (ramka && poleNazwy) {
    document.querySelector("[data-breloki-pole]").hidden = false;
    var dopasuj = function () {
      try {
        var scena = ramka.contentDocument.getElementById("scena");
        var w = scena ? scena.offsetHeight : 0;
        if (w > 100) ramka.style.height = (w + 8) + "px";
      } catch (e) {}
    };
    ramka.addEventListener("load", dopasuj);
    window.addEventListener("resize", dopasuj);
    var czekaj = null;
    poleNazwy.addEventListener("input", function () {
      clearTimeout(czekaj);
      czekaj = setTimeout(function () {
        var nazwa = poleNazwy.value.trim() || "Twoja firma";
        try { ramka.contentWindow.postMessage({ napis: nazwa }, location.origin); } catch (e) {}
      }, 250);
    });
    document.querySelector("[data-breloki-cta]").addEventListener("click", function () {
      var nazwa = poleNazwy.value.trim();
      var opis = document.getElementById("f-opis");
      if (nazwa && opis && !opis.value.trim()) opis.value = "Proszę o wycenę breloków dla firmy " + nazwa + ". ";
    });
  }

  /* ---------- formularz ---------- */
  var form = document.querySelector("[data-formularz]");
  if (!form) return;
  var przycisk = form.querySelector("[data-wyslij]");
  var blad = form.querySelector("[data-blad]");
  var sukces = document.querySelector("[data-sukces]");
  var tekstPrzycisku = przycisk.textContent;
  var wToku = false;
  var zaczety = false;
  form.setAttribute("novalidate", "");

  var reguly = {
    email: function (v) {
      if (!v) return "Podaj adres e-mail, np. jan@firma.pl.";
      if (v.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v)) return "Ten adres e-mail wygląda na niepełny. Wpisz go w postaci jan@firma.pl.";
      return "";
    },
    phone: function (v, pole) {
      if (!v) return pole.required ? "Podaj numer telefonu: 9 cyfr, np. 600 700 800." : "";
      var cyfry = v.replace(/[\s().-]/g, "").replace(/^00/, "+");
      if (/^(\+?48)?[1-9]\d{8}$/.test(cyfry) || /^\+\d{8,15}$/.test(cyfry)) return "";
      return "Podaj numer telefonu: 9 cyfr, np. 600 700 800.";
    },
    message: function (v) {
      return v ? "" : "Napisz w 1–2 zdaniach, czego potrzebujesz, np. ile breloków i na kiedy.";
    }
  };

  function sprawdz(pole) {
    var regula = reguly[pole.name];
    if (!regula) return true;
    var komunikat = regula(pole.value.trim(), pole);
    var el = document.getElementById(pole.id + "-blad");
    if (komunikat) {
      pole.setAttribute("aria-invalid", "true");
      el.textContent = komunikat;
      el.hidden = false;
      return false;
    }
    pole.removeAttribute("aria-invalid");
    el.hidden = true;
    el.textContent = "";
    return true;
  }

  var pola = Array.prototype.slice.call(form.querySelectorAll("input[name], textarea[name]")).filter(function (p) { return reguly[p.name]; });
  pola.forEach(function (p) {
    p.addEventListener("blur", function () { if (p.value.trim() || p.getAttribute("aria-invalid")) sprawdz(p); });
    p.addEventListener("input", function () {
      if (!zaczety) { zaczety = true; zdarzenie("formularz_start"); }
      if (p.getAttribute("aria-invalid")) sprawdz(p);
    });
  });

  function pokazBlad(tekst) {
    blad.textContent = tekst;
    blad.hidden = false;
  }
  var bladOgolny = "Nie udało się wysłać formularza. Spróbuj ponownie albo zadzwoń: " +
    (document.querySelector(".kontakt__tel a") ? document.querySelector(".kontakt__tel a").textContent : "") + ".";

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    if (wToku) return;
    blad.hidden = true;
    var pierwszy = null;
    pola.forEach(function (p) { if (!sprawdz(p) && !pierwszy) pierwszy = p; });
    if (pierwszy) { pierwszy.focus(); zdarzenie("formularz_blad", { pole: pierwszy.name }); return; }

    var pulapka = form.querySelector('[name="_honeypot"]');
    if (pulapka && pulapka.value) { pokazSukces(); return; }
    if (Date.now() - start < 3000) { pokazBlad("Formularz został wysłany zbyt szybko. Odczekaj chwilę i spróbuj ponownie."); return; }

    var dane = {};
    Array.prototype.forEach.call(form.elements, function (el) {
      if (!el.name || el.name === "_honeypot" || el.name === "_redirect" || el.name === "_append") return;
      dane[el.name] = el.value.trim();
    });

    wToku = true;
    przycisk.disabled = true;
    przycisk.setAttribute("aria-busy", "true");
    przycisk.textContent = "Wysyłanie…";

    var kontroler = "AbortController" in window ? new AbortController() : null;
    var limit = setTimeout(function () { if (kontroler) kontroler.abort(); }, 12000);

    fetch(form.action, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify(dane),
      signal: kontroler ? kontroler.signal : undefined
    }).then(function (odp) {
      if (odp.ok) { pokazSukces(); zdarzenie("formularz_wyslany", { zrodlo: dane.zrodlo, telefon: dane.phone ? "tak" : "nie" }); return null; }
      if (odp.status === 422) {
        return odp.json().then(function (j) {
          var pierwszeZle = null;
          Object.keys((j && j.errors) || {}).forEach(function (nazwa) {
            var pole = form.querySelector('[name="' + nazwa + '"]');
            var el = pole && document.getElementById(pole.id + "-blad");
            if (!el) return;
            pole.setAttribute("aria-invalid", "true");
            el.textContent = j.errors[nazwa];
            el.hidden = false;
            if (!pierwszeZle) pierwszeZle = pole;
          });
          if (pierwszeZle) pierwszeZle.focus(); else pokazBlad(bladOgolny);
        });
      }
      pokazBlad(bladOgolny);
      zdarzenie("formularz_blad", { kod: odp.status });
      return null;
    }).catch(function () {
      pokazBlad(bladOgolny);
      zdarzenie("formularz_blad", { kod: "siec" });
    }).then(function () {
      clearTimeout(limit);
      wToku = false;
      przycisk.disabled = false;
      przycisk.removeAttribute("aria-busy");
      przycisk.textContent = tekstPrzycisku;
    });
  });

  function pokazSukces() {
    form.hidden = true;
    sukces.hidden = false;
    sukces.focus();
  }
})();
