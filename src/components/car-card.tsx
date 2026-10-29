import { Link } from "@tanstack/react-router";
import { Button } from "@/components/ui/button";
import type { CarView } from "@/lib/cars";

export function CarCard({ car }: { car: CarView }) {
  return (
    <article className="car-card">
      <div className="car-photo">
        <img src={car.images[0]} alt={car.name} loading="lazy" />
        <span className="photo-badge">{car.category}</span>
      </div>
      <div className="car-body">
        <div className="car-meta"><span>{car.brand}</span><span>{car.city ?? ""}</span></div>
        <h3>{car.name}</h3>
        <p>{car.short_description}</p>
        <div className="car-detail-meta">
          {car.year && <span>{car.year}</span>}
          {car.seats && <span>{car.seats} places</span>}
          {car.color && <span>{car.color}</span>}
        </div>
        <div className="car-bottom">
          <Button asChild className="ref-btn"><Link to="/vehicules/$slug" params={{ slug: car.slug }}>Voir la fiche</Link></Button>
          {car.price_from && <span className="text-primary">dès {car.price_from} €</span>}
        </div>
      </div>
    </article>
  );
}
