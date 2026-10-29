import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { fetchCars } from "@/lib/cars";
import { fmtPrice, partnerServiceLabel, vehicleTypeLabel } from "@/lib/platform";
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
  const { t, lang } = useI18n();
  const { slug } = Route.useParams();
  const { data, isLoading } = useQuery({ queryKey: ["car", slug], queryFn: () => fetchCars({ slug }) });
  const car = data?.[0];
  if (isLoading) return <div className="container-ref section-ref"><p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p></div>;
  if (!car)
    return (
      <div className="container-ref section-ref">
        <h1>{t("Véhicule introuvable", "Vehicle not found", "السيارة غير موجودة")}</h1>
        <Link to="/vehicules" className="tile-link">{t("Retour aux véhicules", "Back to vehicles", "العودة إلى السيارات")}</Link>
      </div>
    );

  const extraImages = (car.images ?? []).slice(1, 4);

  return (
    <section className="container-ref pb-16">
      <div className="breadcrumb-ref"><Link to="/vehicules">{t("Véhicules", "Vehicles", "السيارات")}</Link> / {car.name}</div>
      <div className="detail-title">
        <div>
          {car.category && <span className="eyebrow">{vehicleTypeLabel(car.category, lang)}</span>}
          <h1>{car.name}</h1>
          <p>{car.short_description}</p>
        </div>
        <div className="action-row">
          <Button asChild className="ref-btn"><Link to="/reserver" search={{ car: car.slug }}>{t("Réserver ce véhicule", "Book this vehicle", "احجز هذه السيارة")}</Link></Button>
        </div>
      </div>
      <div className={`detail-gallery ${extraImages.length ? "" : "single-photo"}`}>
        <img src={car.images[0]} alt={car.name} />
        {extraImages.length > 0 && (
          <div className="detail-thumbs">
            {extraImages.map((u) => <img key={u} src={u} alt={car.name} loading="lazy" />)}
          </div>
        )}
      </div>
      <div className="dossier-grid mt-8">
        <div><small>{t("Année", "Year", "السنة")}</small>{car.year ?? "—"}</div>
        <div><small>{t("Couleur", "Colour", "اللون")}</small>{car.color ?? "—"}</div>
        <div><small>{t("Places", "Seats", "المقاعد")}</small>{car.seats ?? "—"}</div>
        <div><small>{t("Ville", "City", "المدينة")}</small>{car.city ?? "—"}</div>
        <div><small>{t("Disponibilité", "Availability", "التوفر")}</small>{car.availability}</div>
        <div><small>{t("Tarif indicatif", "Indicative price", "السعر التقريبي")}</small>{car.price_from ? `${t("dès", "from", "ابتداءً من")} ${fmtPrice(car.price_from, lang)}` : t("Sur devis", "On quote", "حسب الطلب")}</div>
        <div className="form-wide"><small>{t("Services", "Services", "الخدمات")}</small>{car.services.map((s) => partnerServiceLabel(s, lang)).join(" · ") || "—"}</div>
      </div>
      <p className="mt-8 max-w-3xl">{car.description}</p>
    </section>
  );
}
