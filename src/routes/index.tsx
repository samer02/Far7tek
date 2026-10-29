import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Car, Users, Handshake } from "lucide-react";
import { Button } from "@/components/ui/button";
import { heroImage } from "@/lib/platform";
import { fetchCars } from "@/lib/cars";
import { CarCard } from "@/components/car-card";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Cortège & Cérémonie — Mariages et transport privé avec chauffeur" },
      { name: "description", content: "Voitures de mariage, transport familial vers la salle des fêtes et trajets privés avec chauffeur." },
      { property: "og:title", content: "Cortège & Cérémonie — Mariages et transport privé" },
      { property: "og:description", content: "Réservez une voiture avec chauffeur pour votre mariage ou le transport de vos proches." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Home,
});

const services = [
  { icon: Car, title: "Mariages & événements", text: "Voitures décorées ou de prestige pour les mariés et leurs invités.", to: "/reserver" as const, cta: "Réserver une voiture" },
  { icon: Users, title: "Transport familial", text: "Du domicile à la salle des fêtes, puis le retour après la fête, avec chauffeur.", to: "/reserver" as const, cta: "Demander un transport" },
  { icon: Handshake, title: "Devenir partenaire", text: "Vous possédez une belle voiture ? Rejoignez notre réseau de propriétaires.", to: "/devenir-partenaire" as const, cta: "Proposer ma voiture" },
];

function Home() {
  const { data: cars } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  return (
    <>
      <section className="hero-ref">
        <img src={heroImage} alt="Voiture de mariage avec chauffeur" />
        <div className="hero-content container-ref">
          <span className="eyebrow">Mariages · Familles · Trajets privés</span>
          <h1>Arrivez avec <span className="gold-italic">élégance</span>, rentrez en toute sérénité</h1>
          <p>Voitures d’exception avec chauffeur pour les mariés, leurs proches et tous vos trajets privés vers la salle des fêtes.</p>
          <div className="action-row">
            <Button asChild className="ref-btn"><Link to="/reserver">Réserver une voiture</Link></Button>
            <Button asChild variant="outline" className="ref-btn"><Link to="/vehicules">Découvrir les véhicules</Link></Button>
          </div>
        </div>
      </section>
      <div className="container-ref">
        <div className="stats-strip">
          <div><strong>3</strong><span>services principaux</span></div>
          <div><strong>{cars?.length ?? "—"}</strong><span>véhicules disponibles</span></div>
          <div><strong>A/R</strong><span>aller simple ou aller-retour</span></div>
          <div><strong>24 h</strong><span>délai de réponse moyen</span></div>
        </div>
      </div>
      <section className="section-ref">
        <div className="container-ref">
          <div className="section-heading center">
            <span className="eyebrow">Nos services</span>
            <h2>Une voiture et un chauffeur pour chaque moment</h2>
          </div>
          <div className="feature-grid">
            {services.map((s) => (
              <div key={s.title} className="icon-tile">
                <s.icon />
                <h3>{s.title}</h3>
                <p>{s.text}</p>
                <Link to={s.to} className="tile-link">{s.cta} →</Link>
              </div>
            ))}
          </div>
        </div>
      </section>
      <section className="section-ref alt">
        <div className="container-ref">
          <div className="section-heading">
            <span className="eyebrow">La collection</span>
            <h2>Véhicules à l’honneur</h2>
          </div>
          <div className="cars-grid">
            {(cars ?? []).slice(0, 3).map((c) => <CarCard key={c.id} car={c} />)}
          </div>
        </div>
      </section>
      <section className="section-ref">
        <div className="container-ref">
          <div className="four-grid">
            {["Choisissez le service", "Indiquez trajets et horaires", "Un responsable vous contacte", "Votre chauffeur est confirmé"].map((t, i) => (
              <div key={t} className="steps-ref">
                <div className="step-no">0{i + 1}</div>
                <h3>{t}</h3>
              </div>
            ))}
          </div>
          <div className="cta-band mt-10">
            <div>
              <h3>Déjà fait une demande ?</h3>
              <p>Connectez-vous pour suivre son statut en temps réel.</p>
            </div>
            <Button asChild className="ref-btn"><Link to="/compte">Suivre ma demande</Link></Button>
          </div>
        </div>
      </section>
    </>
  );
}
