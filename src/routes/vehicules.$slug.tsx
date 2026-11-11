import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Check, Sparkles, Star } from "lucide-react";
import { Button } from "@/components/ui/button";
import { fetchCars } from "@/lib/cars";
import { CAR_CATEGORIES, carColorLabel, carInCategory, equipmentLabel, fmtPrice, fuelLabel, primaryCategory, transmissionLabel, vehicleTypeLabel } from "@/lib/platform";
import { ColorDot } from "@/components/form-inputs";
import { useI18n } from "@/lib/i18n";

export const Route = createFileRoute("/vehicules/$slug")({
  head: () => ({
    meta: [
      { title: "Fiche véhicule — Far7tek" },
      { name: "description", content: "Détails, services et réservation de ce véhicule avec chauffeur Far7tek." },
      { property: "og:title", content: "Fiche véhicule — Far7tek" },
      { property: "og:description", content: "Détails et réservation de ce véhicule avec chauffeur." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: CarDetail,
});

function CarDetail() {
  const { t, p, lang } = useI18n();
  const { slug } = Route.useParams();
  const { data, isLoading } = useQuery({ queryKey: ["car", slug], queryFn: () => fetchCars({ slug }) });
  const [shown, setShown] = useState(0);
  const car = data?.[0];
  if (isLoading) return <div className="container-ref section-ref"><p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p></div>;
  if (!car)
    return (
      <div className="container-ref section-ref">
        <h1>{t("Véhicule introuvable", "Vehicle not found", "السيارة غير موجودة")}</h1>
        <Link to="/vehicules" className="tile-link">{t("Retour aux véhicules", "Back to vehicles", "العودة إلى السيارات")}</Link>
      </div>
    );

  const images = car.images ?? [];
  const main = images[Math.min(shown, images.length - 1)];
  const cats = CAR_CATEGORIES.filter((c) => carInCategory(car.services, c.value));
  const cat = primaryCategory(car.services);
  const dash = "—";

  return (
    <section className="container-ref pb-16">
      <div className="breadcrumb-ref"><Link to="/vehicules">{t("Véhicules", "Vehicles", "السيارات")}</Link> / {car.name}</div>
      <div className="detail-title">
        <div>
          <div className="flex flex-wrap gap-2">
            {cats.map((c) => <span key={c.value} className="eyebrow">{p(c.label)}</span>)}
            {car.featured && <span className="car-flag is-featured static"><Star />{t("Coup de cœur", "Featured", "مميزة")}</span>}
            {car.is_new_arrival && <span className="car-flag is-new static"><Sparkles />{t("Nouveauté", "New arrival", "وصل حديثاً")}</span>}
          </div>
          <h1>{car.name}</h1>
          <p>{car.short_description}</p>
        </div>
        <div className="action-row">
          <Button asChild className="ref-btn bg-primary">
            <Link to="/reserver" search={{ car: car.slug, ...(cat ? { type: cat } : {}) }}>{t("Demander ce véhicule", "Request this vehicle", "اطلب هذه السيارة")}</Link>
          </Button>
        </div>
      </div>
      <div className="gallery">
        {main && <img className="gallery-main" src={main} alt={car.name} />}
        {images.length > 1 && (
          <div className="gallery-thumbs" role="tablist" aria-label={t("Photos", "Photos", "الصور")}>
            {images.map((u, i) => (
              <button key={u} type="button" role="tab" aria-selected={i === shown} onClick={() => setShown(i)}>
                <img src={u} alt={`${car.name} ${i + 1}`} loading="lazy" />
              </button>
            ))}
          </div>
        )}
      </div>
      <div className="detail-layout">
        <div>
          <h2 className="text-2xl mb-4">{t("Caractéristiques", "Specifications", "المواصفات")}</h2>
          <div className="spec-grid">
            <div><small>{t("Marque", "Brand", "الماركة")}</small>{car.brand || dash}</div>
            <div><small>{t("Modèle", "Model", "الطراز")}</small>{car.model || dash}</div>
            <div><small>{t("Année", "Year", "السنة")}</small>{car.year ?? dash}</div>
            <div><small>{t("Type", "Type", "النوع")}</small>{car.category ? vehicleTypeLabel(car.category, lang) : dash}</div>
            <div><small>{t("Places", "Seats", "المقاعد")}</small>{car.seats ?? dash}</div>
            <div><small>{t("Boîte", "Transmission", "ناقل الحركة")}</small>{car.transmission ? transmissionLabel(car.transmission, lang) : dash}</div>
            <div><small>{t("Carburant", "Fuel", "الوقود")}</small>{car.fuel_type ? fuelLabel(car.fuel_type, lang) : dash}</div>
            <div><small>{t("Couleur", "Colour", "اللون")}</small>{car.color ? <><ColorDot color={car.color} />{carColorLabel(car.color, lang)}</> : dash}</div>
            <div><small>{t("Ville", "City", "المدينة")}</small>{car.city ?? dash}</div>
          </div>
          {(car.equipment ?? []).length > 0 && (
            <>
              <h3 className="mt-8 mb-3">{t("Équipements", "Equipment", "التجهيزات")}</h3>
              <ul className="equip-list">{car.equipment!.map((e) => <li key={e}><Check />{equipmentLabel(e, lang)}</li>)}</ul>
            </>
          )}
          {car.description && <p className="mt-8 max-w-3xl whitespace-pre-line">{car.description}</p>}
        </div>
        <aside className="price-card">
          <small>{t("Tarif indicatif", "Indicative price", "السعر التقريبي")}</small>
          <strong>{car.price_from ? `${t("dès", "from", "ابتداءً من")} ${fmtPrice(car.price_from, lang)}` : t("Sur devis", "On quote", "حسب الطلب")}</strong>
          {car.availability && <p>{car.availability}</p>}
          <p>{t("Votre demande est étudiée par notre équipe, qui confirme la disponibilité avec le propriétaire avant toute réservation.", "Our team reviews your request and confirms availability with the owner before anything is booked.", "يراجع فريقنا طلبك ويؤكد التوفر مع المالك قبل أي حجز.")}</p>
          <Button asChild className="ref-btn bg-primary w-full">
            <Link to="/reserver" search={{ car: car.slug, ...(cat ? { type: cat } : {}) }}>{t("Faire une demande", "Send a request", "إرسال طلب")}</Link>
          </Button>
        </aside>
      </div>
    </section>
  );
}
