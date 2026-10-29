import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { fetchCars } from "@/lib/cars";
import { CarCard } from "@/components/car-card";

export const Route = createFileRoute("/vehicules/")({
  head: () => ({
    meta: [
      { title: "Nos véhicules avec chauffeur — Cortège & Cérémonie" },
      { name: "description", content: "Berlines de prestige, voitures de collection et vans pour mariages et transport familial." },
      { property: "og:title", content: "Nos véhicules — Cortège & Cérémonie" },
      { property: "og:description", content: "Découvrez la collection de voitures avec chauffeur." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Vehicles,
});

function Vehicles() {
  const { data: cars, isLoading } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const [cat, setCat] = useState("Tous");
  const cats = ["Tous", ...new Set((cars ?? []).map((c) => c.category))];
  const shown = (cars ?? []).filter((c) => cat === "Tous" || c.category === cat);
  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading">
          <span className="eyebrow">La collection</span>
          <h1>Découvrir les véhicules</h1>
          <p>Chaque voiture est conduite par un chauffeur et validée par notre équipe.</p>
        </div>
        <div className="filter-row">
          {cats.map((c) => (
            <Button key={c} variant={c === cat ? "default" : "outline"} className="filter-btn" onClick={() => setCat(c)}>{c}</Button>
          ))}
        </div>
        {isLoading ? <p>Chargement…</p> : (
          <div className="cars-grid">{shown.map((c) => <CarCard key={c.id} car={c} />)}</div>
        )}
      </div>
    </section>
  );
}
