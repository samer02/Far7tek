import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { fetchCars } from "@/lib/cars";
import { CarCard } from "@/components/car-card";
import { useI18n } from "@/lib/i18n";
import { vehicleTypeLabel } from "@/lib/platform";

export const Route = createFileRoute("/vehicules/")({
  head: () => ({
    meta: [
      { title: "Nos véhicules avec chauffeur — Far7tek" },
      { name: "description", content: "Berlines de prestige, voitures de collection et vans pour mariages et transport familial avec Far7tek." },
      { property: "og:title", content: "Nos véhicules — Far7tek" },
      { property: "og:description", content: "Découvrez la collection de voitures avec chauffeur Far7tek." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Vehicles,
});

function Vehicles() {
  const { t, lang } = useI18n();
  const { data: cars, isLoading } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const [cat, setCat] = useState("");
  const cats = ["", ...new Set((cars ?? []).map((c) => c.category).filter(Boolean))];
  const shown = (cars ?? []).filter((c) => !cat || c.category === cat);
  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading">
          <span className="eyebrow">{t("La collection", "The collection", "المجموعة")}</span>
          <h1>{t("Découvrir les véhicules", "Explore our vehicles", "اكتشف سياراتنا")}</h1>
          <p>{t("Chaque voiture est conduite par un chauffeur et validée par notre équipe.", "Every car comes with a driver and is approved by our team.", "كل سيارة مع سائق ومعتمدة من فريقنا.")}</p>
        </div>
        <div className="filter-row">
          {cats.map((c) => (
            <Button key={c || "all"} variant={c === cat ? "default" : "outline"} className="filter-btn" onClick={() => setCat(c)}>
              {c ? vehicleTypeLabel(c, lang) : t("Tous", "All", "الكل")}
            </Button>
          ))}
        </div>
        {isLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : (
          <div className="cars-grid">{shown.map((c) => <CarCard key={c.id} car={c} />)}</div>
        )}
      </div>
    </section>
  );
}
