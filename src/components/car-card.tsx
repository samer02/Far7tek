import { Link } from "@tanstack/react-router";
import { ArrowRight, ArrowLeft, Sparkles, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import type { CarView } from "@/lib/cars";
import { useI18n } from "@/lib/i18n";
import { CAR_CATEGORIES, carColorLabel, carInCategory, fmtPrice, fuelLabel, primaryCategory, transmissionLabel } from "@/lib/platform";
import { ColorDot } from "@/components/form-inputs";

export function CarCard({ car }: { car: CarView }) {
  const { t, p, lang, dir } = useI18n();
  const Arrow = dir === "rtl" ? ArrowLeft : ArrowRight;
  const cats = CAR_CATEGORIES.filter((c) => carInCategory(car.services, c.value));
  return (
    <article className="car-card" data-cat={primaryCategory(car.services) ?? undefined}>
      <div className="car-photo">
        <img src={car.images[0]} alt={car.name} loading="lazy" />
        {cats.length > 0 && <span className="photo-badge">{cats.map((c) => p(c.short)).join(" · ")}</span>}
        <div className="car-flags">
          {car.featured && <span className="car-flag is-featured"><Star />{t("Coup de cœur", "Featured", "مميزة")}</span>}
          {car.is_new_arrival && <span className="car-flag is-new"><Sparkles />{t("Nouveauté", "New arrival", "وصل حديثاً")}</span>}
        </div>
      </div>
      <div className="car-body">
        <div className="car-meta"><span>{car.brand}{car.model ? ` · ${car.model}` : ""}</span><span>{car.city ?? ""}</span></div>
        <h3>{car.name}</h3>
        <p>{car.short_description}</p>
        <div className="car-detail-meta">
          {car.year && <span>{car.year}</span>}
          {car.seats && <span>{car.seats} {t("places", "seats", "مقاعد")}</span>}
          {car.transmission && <span>{transmissionLabel(car.transmission, lang)}</span>}
          {car.fuel_type && <span>{fuelLabel(car.fuel_type, lang)}</span>}
          {car.color && <span><ColorDot color={car.color} />{carColorLabel(car.color, lang)}</span>}
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
