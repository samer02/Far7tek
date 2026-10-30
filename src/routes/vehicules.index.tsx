import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Heart, Users } from "lucide-react";
import { Button } from "@/components/ui/button";
import { fetchCars } from "@/lib/cars";
import { CarCard } from "@/components/car-card";
import { useI18n } from "@/lib/i18n";
import { CAR_CATEGORIES, carInCategory, type CarCategory } from "@/lib/platform";

export const Route = createFileRoute("/vehicules/")({
  validateSearch: (s: Record<string, unknown>): { type?: CarCategory } =>
    s["type"] === "wedding" || s["type"] === "family" ? { type: s["type"] } : {},
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

function Vehicles() {
  const { t, p } = useI18n();
  const { type } = Route.useSearch();
  const { data: cars, isLoading } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const all = cars ?? [];
  const groups = CAR_CATEGORIES.filter((c) => !type || c.value === type).map((c) => ({ ...c, cars: all.filter((car) => carInCategory(car.services, c.value)) }));

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading">
          <span className="eyebrow">{t("La collection", "The collection", "المجموعة")}</span>
          <h1>{t("Découvrir les véhicules", "Explore our vehicles", "اكتشف سياراتنا")}</h1>
          <p>{t("Chaque voiture est conduite par un chauffeur et validée par notre équipe.", "Every car comes with a driver and is approved by our team.", "كل سيارة مع سائق ومعتمدة من فريقنا.")}</p>
        </div>
        <div className="filter-row">
          <Button asChild variant={!type ? "default" : "outline"} className="filter-btn">
            <Link to="/vehicules" search={{}}>{t("Tous", "All", "الكل")}</Link>
          </Button>
          {CAR_CATEGORIES.map((c) => {
            const Icon = ICONS[c.value];
            return (
              <Button key={c.value} asChild variant={type === c.value ? "default" : "outline"} className="filter-btn">
                <Link to="/vehicules" search={{ type: c.value }}><Icon className="h-4 w-4" />{p(c.label)}</Link>
              </Button>
            );
          })}
        </div>
        {isLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : (
          <div className="grid gap-14">
            {groups.map((g) => {
              const Icon = ICONS[g.value];
              return (
                <div key={g.value}>
                  <h2 className="mb-6 flex items-center gap-3 text-2xl"><Icon className="h-6 w-6 text-primary" />{p(g.label)}</h2>
                  {g.cars.length ? (
                    <div className="cars-grid">{g.cars.map((c) => <CarCard key={c.id} car={c} />)}</div>
                  ) : (
                    <p>{t("Aucun véhicule dans cette catégorie pour le moment.", "No vehicles in this category yet.", "لا توجد سيارات في هذه الفئة حالياً.")}</p>
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
