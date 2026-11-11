import { useState } from "react";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Heart, Search, Sparkles, Star, Users } from "lucide-react";
import { Button } from "@/components/ui/button";
import { fetchCars, type CarView } from "@/lib/cars";
import { CarCard } from "@/components/car-card";
import { useI18n } from "@/lib/i18n";
import { CAR_CATEGORIES, carInCategory, type CarCategory } from "@/lib/platform";

type Search = { type?: CarCategory; q?: string };
const searchOf = (type: CarCategory | undefined, q: string | undefined): Search => ({ ...(type ? { type } : {}), ...(q ? { q } : {}) });

export const Route = createFileRoute("/vehicules/")({
  validateSearch: (s: Record<string, unknown>): Search => ({
    ...(s["type"] === "wedding" || s["type"] === "family" ? { type: s["type"] } : {}),
    ...(typeof s["q"] === "string" && s["q"].trim() ? { q: s["q"].trim().slice(0, 80) } : {}),
  }),
  head: () => ({
    meta: [
      { title: "Nos véhicules avec chauffeur — Far7tek" },
      { name: "description", content: "Voitures des mariés et véhicules de transport familial avec chauffeur, partout en Tunisie avec Far7tek." },
      { property: "og:title", content: "Nos véhicules — Far7tek" },
      { property: "og:description", content: "Voitures des mariés et transport familial avec chauffeur Far7tek." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Vehicles,
});

const ICONS = { wedding: Heart, family: Users } as const;

const matches = (car: CarView, q: string) => {
  const needle = q.toLocaleLowerCase();
  return [car.name, car.brand, car.model, car.city, car.color, String(car.year ?? "")].some((v) => (v ?? "").toLocaleLowerCase().includes(needle));
};
const isNewArrival = (car: CarView) => car.is_new_arrival === true;

function Vehicles() {
  const { t, p } = useI18n();
  const { type, q } = Route.useSearch();
  const navigate = useNavigate({ from: "/vehicules/" });
  const [draft, setDraft] = useState(q ?? "");
  const { data: cars, isLoading } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const all = (cars ?? []).filter((c) => !q || matches(c, q));
  const browsing = !type && !q;
  const featured = browsing ? all.filter((c) => c.featured) : [];
  const fresh = browsing ? all.filter(isNewArrival).slice(0, 6) : [];
  const groups = CAR_CATEGORIES.filter((c) => !type || c.value === type).map((c) => ({ ...c, cars: all.filter((car) => carInCategory(car.services, c.value)) }));

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading">
          <span className="eyebrow">{t("La collection", "The collection", "المجموعة")}</span>
          <h1>{t("Découvrir les véhicules", "Explore our vehicles", "اكتشف سياراتنا")}</h1>
          <p>{t("Chaque voiture est conduite par un chauffeur et validée par notre équipe.", "Every car comes with a driver and is approved by our team.", "كل سيارة مع سائق ومعتمدة من فريقنا.")}</p>
        </div>
        <div className="catalog-bar">
          <form className="catalog-search" role="search" onSubmit={(e) => { e.preventDefault(); void navigate({ search: searchOf(type, draft.trim() || undefined) }); }}>
            <Search />
            <input value={draft} onChange={(e) => setDraft(e.target.value)} placeholder={t("Marque, modèle, ville…", "Brand, model, city…", "الماركة، الطراز، المدينة…")} aria-label={t("Rechercher", "Search", "بحث")} />
            <Button className="ref-btn">{t("Rechercher", "Search", "بحث")}</Button>
          </form>
          <div className="filter-row !mb-0">
            <Button asChild variant={!type ? "default" : "outline"} className="filter-btn">
              <Link to="/vehicules" search={searchOf(undefined, q)}>{t("Tous", "All", "الكل")}</Link>
            </Button>
            {CAR_CATEGORIES.map((c) => {
              const Icon = ICONS[c.value];
              return (
                <Button key={c.value} asChild variant={type === c.value ? "default" : "outline"} className="filter-btn">
                  <Link to="/vehicules" search={searchOf(c.value, q)}><Icon className="h-4 w-4" />{p(c.label)}</Link>
                </Button>
              );
            })}
          </div>
        </div>
        {q && (
          <p className="mb-6">
            {all.length} {t("résultat(s) pour", "result(s) for", "نتيجة لـ")} « {q} » ·{" "}
            <Link to="/vehicules" search={searchOf(type, undefined)} className="tile-link !mt-0" onClick={() => setDraft("")}>{t("Effacer", "Clear", "مسح")}</Link>
          </p>
        )}
        {isLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : (
          <div className="grid gap-14">
            {featured.length > 0 && (
              <div className="catalog-band is-featured">
                <h2 className="mb-6 flex items-center gap-3 text-2xl"><Star className="h-6 w-6 text-primary" />{t("Nos coups de cœur", "Featured", "سيارات مميزة")}</h2>
                <div className="cars-grid">{featured.map((c) => <CarCard key={c.id} car={c} />)}</div>
              </div>
            )}
            {fresh.length > 0 && (
              <div>
                <h2 className="mb-6 flex items-center gap-3 text-2xl"><Sparkles className="h-6 w-6 text-primary" />{t("Nouveautés", "New arrivals", "وصل حديثاً")}</h2>
                <div className="cars-grid">{fresh.map((c) => <CarCard key={c.id} car={c} />)}</div>
              </div>
            )}
            {groups.map((g) => {
              const Icon = ICONS[g.value];
              return (
                <div key={g.value} className="catalog-band" data-cat={g.value}>
                  <h2 className="mb-6 flex items-center gap-3 text-2xl"><Icon className="h-6 w-6 text-primary" />{p(g.label)}</h2>
                  {g.cars.length ? (
                    <div className="cars-grid">{g.cars.map((c) => <CarCard key={c.id} car={c} />)}</div>
                  ) : (
                    <p>{q ? t("Aucun véhicule ne correspond à votre recherche.", "No vehicle matches your search.", "لا توجد سيارة تطابق بحثك.") : t("Aucun véhicule dans cette catégorie pour le moment.", "No vehicles in this category yet.", "لا توجد سيارات في هذه الفئة حالياً.")}</p>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </section>
  );
}
