import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { fetchCars } from "@/lib/cars";
import { partnerServiceLabel } from "@/lib/platform";

export const Route = createFileRoute("/vehicules/$slug")({
  head: () => ({
    meta: [
      { title: "Fiche véhicule — Cortège & Cérémonie" },
      { name: "description", content: "Détails, services et réservation de ce véhicule avec chauffeur." },
      { property: "og:title", content: "Fiche véhicule — Cortège & Cérémonie" },
      { property: "og:description", content: "Détails et réservation de ce véhicule avec chauffeur." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: CarDetail,
});

function CarDetail() {
  const { slug } = Route.useParams();
  const { data, isLoading } = useQuery({ queryKey: ["car", slug], queryFn: () => fetchCars({ slug }) });
  const car = data?.[0];
  if (isLoading) return <div className="container-ref section-ref"><p>Chargement…</p></div>;
  if (!car) return <div className="container-ref section-ref"><h1>Véhicule introuvable</h1><Link to="/vehicules" className="tile-link">← Retour aux véhicules</Link></div>;
  return (
    <section className="container-ref pb-16">
      <div className="breadcrumb-ref"><Link to="/vehicules">Véhicules</Link> / {car.name}</div>
      <div className="detail-title">
        <div>
          <span className="eyebrow">{car.category}</span>
          <h1>{car.name}</h1>
          <p>{car.short_description}</p>
        </div>
        <div className="action-row">
          <Button asChild className="ref-btn"><Link to="/reserver" search={{ car: car.slug }}>Réserver ce véhicule</Link></Button>
        </div>
      </div>
      <div className="detail-gallery">
        <img src={car.images[0]} alt={car.name} />
        <div className="detail-thumbs">
          {car.images.slice(1, 4).map((u) => <img key={u} src={u} alt={car.name} />)}
        </div>
      </div>
      <div className="dossier-grid mt-8">
        <div><small>Année</small>{car.year ?? "—"}</div>
        <div><small>Couleur</small>{car.color ?? "—"}</div>
        <div><small>Places</small>{car.seats ?? "—"}</div>
        <div><small>Ville</small>{car.city ?? "—"}</div>
        <div><small>Disponibilité</small>{car.availability}</div>
        <div><small>Tarif indicatif</small>{car.price_from ? `dès ${car.price_from} €` : "Sur devis"}</div>
        <div className="form-wide"><small>Services</small>{car.services.map(partnerServiceLabel).join(" · ") || "—"}</div>
      </div>
      <p className="mt-8 max-w-3xl">{car.description}</p>
    </section>
  );
}
