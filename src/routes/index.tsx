import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Car, Users, Handshake, CalendarCheck, ShieldCheck, Check, ArrowRight, ArrowLeft, Clock } from "lucide-react";
import { Button } from "@/components/ui/button";
import { heroImage } from "@/lib/platform";
import { fetchCars } from "@/lib/cars";
import { CarCard } from "@/components/car-card";
import { SLOGAN, SLOGAN_LONG } from "@/components/site-chrome";
import { useI18n } from "@/lib/i18n";
import familyImage from "@/assets/far7tek-family.jpg";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Far7tek — Voitures de mariage et transport familial avec chauffeur" },
      { name: "description", content: "Far7tek فرحتك تهمّنا : voitures de mariage décorées, transport familial vers la salle des fêtes et trajets privés avec chauffeur." },
      { property: "og:title", content: "Far7tek — فرحتك تهمّنا ❤️" },
      { property: "og:description", content: "من دارك لفرحتك، ومن فرحتك لدارك — voitures de mariage et transport familial avec chauffeur." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Home,
});

function Home() {
  const { t, dir } = useI18n();
  const Arrow = dir === "rtl" ? ArrowLeft : ArrowRight;
  const { data: cars } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });

  const services = [
    {
      icon: Car,
      title: t("Mariages & événements", "Weddings & events", "الأعراس والمناسبات"),
      text: t("Voitures décorées ou de prestige pour les mariés et leurs invités.", "Decorated or luxury cars for the couple and their guests.", "سيارات مزيّنة أو فاخرة للعروسين وضيوفهم."),
      to: "/reserver" as const,
      cta: t("Réserver une voiture", "Book a car", "احجز سيارة"),
    },
    {
      icon: Users,
      title: t("Transport familial", "Family transport", "نقل العائلة"),
      text: t("Du domicile à la salle des fêtes, puis le retour après la fête, avec chauffeur.", "From home to the venue and back after the party, with a chauffeur.", "من الدار إلى قاعة الأفراح والعودة بعد الحفل، مع سائق."),
      to: "/reserver" as const,
      cta: t("Demander un transport", "Request a ride", "اطلب نقلاً"),
    },
    {
      icon: Handshake,
      title: t("Devenir partenaire", "Become a partner", "كن شريكاً"),
      text: t("Vous possédez une belle voiture ? Rejoignez notre réseau de propriétaires.", "Own a beautiful car? Join our network of owners.", "عندك سيارة جميلة؟ انضم إلى شبكة الملاك لدينا."),
      to: "/devenir-partenaire" as const,
      cta: t("Proposer ma voiture", "List my car", "اعرض سيارتك"),
    },
  ];

  const steps = [
    [t("Choisissez le service", "Choose the service", "اختر الخدمة"), t("Mariage, famille ou trajet privé.", "Wedding, family or private trip.", "عرس، عائلة أو رحلة خاصة.")],
    [t("Indiquez trajets et horaires", "Add trips and times", "حدّد المسار والمواعيد"), t("Aller simple ou aller-retour.", "One way or round trip.", "ذهاب فقط أو ذهاب وإياب.")],
    [t("Un responsable vous contacte", "A manager calls you", "يتصل بك مسؤول"), t("Sous 24 heures maximum.", "Within 24 hours.", "خلال 24 ساعة كحد أقصى.")],
    [t("Votre chauffeur est confirmé", "Your driver is confirmed", "يتم تأكيد السائق"), t("Suivez tout depuis votre espace.", "Track everything from your account.", "تابع كل شيء من حسابك.")],
  ];

  return (
    <>
      <section className="hero">
        <div className="container-ref hero-grid">
          <div>
            <span className="hero-chip fade-up"><span className="tag">Far7tek</span><span className="ar-text">{SLOGAN}</span></span>
            <h1 className="fade-up d1">
              {t("Votre fête commence ", "Your celebration starts ", "فرحتك تبدأ ")}
              <span className="grad-text">{t("dès le départ", "at your doorstep", "من باب دارك")}</span>
            </h1>
            <p className="hero-slogan fade-up d2"><span className="ar-text">{SLOGAN_LONG}</span></p>
            <p className="hero-lead fade-up d2">
              {t(
                "Voitures de mariage décorées, transport familial vers la salle des fêtes et trajets privés — avec chauffeur, à l’heure, en toute sérénité.",
                "Decorated wedding cars, family transport to the venue and private trips — with a chauffeur, on time, stress-free.",
                "سيارات أعراس مزيّنة، نقل العائلة إلى قاعة الأفراح ورحلات خاصة — مع سائق، في الموعد وبكل راحة بال.",
              )}
            </p>
            <div className="action-row fade-up d3">
              <Button asChild className="ref-btn"><Link to="/reserver">{t("Réserver une voiture", "Book a car", "احجز سيارة")} <Arrow /></Link></Button>
              <Button asChild variant="outline" className="ref-btn"><Link to="/vehicules">{t("Découvrir les véhicules", "Explore vehicles", "اكتشف السيارات")}</Link></Button>
            </div>
            <div className="hero-trust fade-up d3">
              <div className="avatars" aria-hidden><span>A</span><span>S</span><span>❤</span></div>
              <span><strong>{t("Réponse sous 24 h", "Reply within 24h", "رد خلال 24 ساعة")}</strong> · {t("chauffeurs vérifiés", "verified drivers", "سائقون موثوقون")}</span>
            </div>
          </div>
          <div className="hero-visual fade-up d2">
            <img className="main" src={heroImage} alt={t("Voiture de mariage décorée de fleurs", "Wedding car decorated with flowers", "سيارة عرس مزيّنة بالورود")} width={1280} height={1536} />
            <div className="hero-floats">
              <div className="float-card a">
                <span className="ic"><CalendarCheck /></span>
                <span><strong>{t("Confirmation rapide", "Fast confirmation", "تأكيد سريع")}</strong>{t("Un responsable vous rappelle", "A manager calls you back", "مسؤول يعاود الاتصال بك")}</span>
              </div>
              <div className="float-card b">
                <span className="ic"><ShieldCheck /></span>
                <span><strong>{t("Véhicules validés", "Approved vehicles", "سيارات معتمدة")}</strong>{t("Contrôlés par notre équipe", "Checked by our team", "يفحصها فريقنا")}</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <div className="container-ref">
        <div className="stats-strip">
          <div><strong>3</strong><span>{t("services principaux", "core services", "خدمات رئيسية")}</span></div>
          <div><strong>{cars?.length ?? "—"}</strong><span>{t("véhicules disponibles", "vehicles available", "سيارات متاحة")}</span></div>
          <div><strong><bdi>A/R</bdi></strong><span>{t("aller simple ou aller-retour", "one way or round trip", "ذهاب أو ذهاب وإياب")}</span></div>
          <div><strong><bdi>24 h</bdi></strong><span>{t("délai de réponse maximum", "maximum reply time", "أقصى مدة للرد")}</span></div>
        </div>
      </div>

      <section className="section-ref">
        <div className="container-ref">
          <div className="section-heading center">
            <span className="eyebrow">{t("Nos services", "Our services", "خدماتنا")}</span>
            <h2>{t("Une voiture et un chauffeur pour chaque moment", "A car and a driver for every moment", "سيارة وسائق لكل لحظة")}</h2>
          </div>
          <div className="feature-grid">
            {services.map((s) => (
              <div key={s.title} className="icon-tile">
                <s.icon />
                <h3>{s.title}</h3>
                <p>{s.text}</p>
                <Link to={s.to} className="tile-link">{s.cta} <Arrow className="h-4 w-4" /></Link>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section-ref alt">
        <div className="container-ref split">
          <div className="split-photo">
            <img src={familyImage} alt={t("Chauffeur accueillant une famille", "Chauffeur welcoming a family", "سائق يستقبل عائلة")} loading="lazy" width={1280} height={960} />
            <div className="float-card">
              <span className="ic"><Clock /></span>
              <span><strong>{t("Aller & retour", "There & back", "ذهاب وإياب")}</strong>{t("On vous attend après la fête", "We wait for you after the party", "ننتظرك بعد الحفل")}</span>
            </div>
          </div>
          <div>
            <span className="eyebrow">{t("Transport familial", "Family transport", "نقل العائلة")}</span>
            <h2 className="mt-4">{t("Vos proches arrivent ensemble, et rentrent sereins", "Your loved ones arrive together and get home safely", "أحبّتك يصلون معاً ويعودون بأمان")}</h2>
            <ul className="check-list">
              {[
                t("Prise en charge au domicile, à l’heure convenue", "Pick-up at home at the agreed time", "الاستقبال من الدار في الموعد المتفق عليه"),
                t("Véhicules adaptés au nombre de passagers", "Vehicles sized to your group", "سيارات تناسب عدد الركاب"),
                t("Retour après la fête, même tard le soir", "Ride home after the party, even late", "العودة بعد الحفل، حتى في وقت متأخر"),
              ].map((x) => <li key={x}><Check /><span>{x}</span></li>)}
            </ul>
            <div className="quote-ar"><span className="ar-text">{SLOGAN_LONG}</span></div>
          </div>
        </div>
      </section>

      <section className="section-ref">
        <div className="container-ref">
          <div className="registry-toolbar">
            <div className="section-heading !mb-0">
              <span className="eyebrow">{t("La collection", "The collection", "المجموعة")}</span>
              <h2>{t("Véhicules à l’honneur", "Featured vehicles", "سيارات مميّزة")}</h2>
            </div>
            <Button asChild variant="outline" className="ref-btn"><Link to="/vehicules">{t("Tout voir", "See all", "عرض الكل")} <Arrow /></Link></Button>
          </div>
          <div className="cars-grid mt-6">
            {(cars ?? []).slice(0, 3).map((c) => <CarCard key={c.id} car={c} />)}
          </div>
        </div>
      </section>

      <section className="section-ref alt">
        <div className="container-ref">
          <div className="section-heading center">
            <span className="eyebrow">{t("Comment ça marche", "How it works", "كيف تعمل الخدمة")}</span>
            <h2>{t("Quatre étapes, zéro stress", "Four steps, zero stress", "أربع خطوات، بدون توتر")}</h2>
          </div>
          <div className="four-grid">
            {steps.map(([title, text], i) => (
              <div key={title} className="steps-ref">
                <div className="step-no">0{i + 1}</div>
                <h3>{title}</h3>
                <p>{text}</p>
              </div>
            ))}
          </div>
          <div className="cta-band mt-12">
            <div>
              <h3>{t("Déjà fait une demande ?", "Already sent a request?", "أرسلت طلباً من قبل؟")}</h3>
              <p>{t("Connectez-vous pour suivre son statut en temps réel.", "Sign in to follow its status in real time.", "سجّل الدخول لمتابعة حالته مباشرة.")}</p>
            </div>
            <Button asChild variant="secondary" className="ref-btn"><Link to="/compte">{t("Suivre ma demande", "Track my request", "تتبع طلبي")}</Link></Button>
          </div>
        </div>
      </section>
    </>
  );
}
