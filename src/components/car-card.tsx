import { Link } from "@tanstack/react-router";
import { ArrowRight, ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { CarView } from "@/lib/cars";
import { useI18n } from "@/lib/i18n";
import { fmtPrice, vehicleTypeLabel } from "@/lib/platform";

export function CarCard({ car }: { car: CarView }) {
  const { t, lang, dir } = useI18n();
  const Arrow = dir === "rtl" ? ArrowLeft : ArrowRight;
  return (
    <article className="car-card">
      <div className="car-photo">
        <img src={car.images[0]} alt={car.name} loading="lazy" />
        {car.category && <span className="photo-badge">{vehicleTypeLabel(car.category, lang)}</span>}
      </div>
      <div className="car-body">
        <div className="car-meta"><span>{car.brand}</span><span>{car.city ?? ""}</span></div>
        <h3>{car.name}</h3>
        <p>{car.short_description}</p>
        <div className="car-detail-meta">
          {car.year && <span>{car.year}</span>}
          {car.seats && <span>{car.seats} {t("places", "seats", "مقاعد")}</span>}
          {car.color && <span>{car.color}</span>}
        </div>
        <div className="car-bottom">
          <span className="car-price">
            <small>{t("À partir de", "From", "ابتداءً من")}</small>
            {car.price_from ? fmtPrice(car.price_from, lang) : t("Sur devis", "On quote", "حسب الطلب")}
          </span>
          <Button asChild className="ref-btn">
            <Link to="/vehicules/$slug" params={{ slug: car.slug }}>{t("Voir", "View", "عرض")} <Arrow /></Link>
          </Button>
        </div>
      </div>
    </article>
  );
}
