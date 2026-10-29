import { Link, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { ChevronDown, Menu, UserRound, X } from "lucide-react";
import logo from "@/assets/far7tek-logo.png";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { LANGS, useI18n } from "@/lib/i18n";
import { ThemeToggle } from "@/lib/theme";

export const SLOGAN = "فرحتك تهمّنا ❤️";
export const SLOGAN_LONG = "من دارك لفرحتك، ومن فرحتك لدارك";

export function Brand({ onClick }: { withSlogan?: boolean; onClick?: () => void }) {
  return (
    <Link to="/" className="brand" aria-label="Far7tek" onClick={onClick}>
      <img className="brand-logo" src={logo} alt="Far7tek — فرحتك تهمّنا" width={480} height={437} />
    </Link>
  );
}

export function LangSwitch() {
  const { lang, setLang } = useI18n();
  return (
    <div className="seg" role="group" aria-label="Langue / Language / اللغة">
      {LANGS.map((l) => (
        <button key={l.code} type="button" aria-pressed={lang === l.code} title={l.name} onClick={() => setLang(l.code)}>
          {l.short}
        </button>
      ))}
    </div>
  );
}

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const { t } = useI18n();
  const { data: auth } = useAuth();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const roles = auth?.roles ?? [];
  const close = () => setOpen(false);

  const links = [
    { to: "/" as const, label: t("Accueil", "Home", "الرئيسية") },
    { to: "/vehicules" as const, label: t("Véhicules", "Vehicles", "السيارات") },
    { to: "/reserver" as const, label: t("Réserver", "Book", "احجز") },
    { to: "/devenir-partenaire" as const, label: t("Devenir partenaire", "Become a partner", "كن شريكاً") },
    { to: "/compte" as const, label: t("Mes demandes", "My requests", "طلباتي") },
  ];

  async function signOut() {
    close();
    await qc.cancelQueries();
    qc.clear();
    await supabase.auth.signOut();
    navigate({ to: "/auth", replace: true });
  }

  const spaceLinks = (
    <>
      {roles.includes("admin") && <Link to="/admin" onClick={close} activeProps={{ "data-active": "true" } as never}>{t("Administration", "Admin", "الإدارة")}</Link>}
      {roles.includes("partner") && <Link to="/partenaire" onClick={close} activeProps={{ "data-active": "true" } as never}>{t("Espace partenaire", "Partner area", "فضاء الشريك")}</Link>}
    </>
  );

  return (
    <header className="site-header">
      <div className="site-header-inner">
        <div className="nav-shell">
          <Brand onClick={close} />
          <nav className="desktop-nav" aria-label={t("Navigation principale", "Main navigation", "التنقل الرئيسي")}>
            {links.filter((l) => l.to !== "/reserver" && l.to !== "/compte").map((l) => (
              <Link key={l.to} to={l.to} activeProps={{ "data-active": "true" } as never} activeOptions={{ exact: l.to === "/" }}>
                {l.label}
              </Link>
            ))}
          </nav>
          <div className="nav-tools">
            <LangSwitch />
            <ThemeToggle className="theme" />
            <div className="header-cta action-row">
              {auth?.userId ? (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="outline" className="ref-btn login-btn" aria-label={t("Mon espace", "My account", "حسابي")}><UserRound /><span className="btn-label">{t("Mon espace", "My account", "حسابي")}</span><ChevronDown className="btn-label" /></Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" className="account-menu">
                    <DropdownMenuItem asChild><Link to="/compte">{t("Mes demandes", "My requests", "طلباتي")}</Link></DropdownMenuItem>
                    {roles.includes("partner") && <DropdownMenuItem asChild><Link to="/partenaire">{t("Espace partenaire", "Partner area", "فضاء الشريك")}</Link></DropdownMenuItem>}
                    {roles.includes("admin") && <DropdownMenuItem asChild><Link to="/admin">{t("Administration", "Admin", "الإدارة")}</Link></DropdownMenuItem>}
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onSelect={signOut}>{t("Déconnexion", "Sign out", "خروج")}</DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              ) : (
                <Button asChild variant="outline" className="ref-btn login-btn"><Link to="/auth" aria-label={t("Connexion", "Sign in", "دخول")}><UserRound /><span className="btn-label">{t("Connexion", "Sign in", "دخول")}</span></Link></Button>
              )}
              <Button asChild className="ref-btn"><Link to="/reserver">{t("Réserver", "Book now", "احجز الآن")}</Link></Button>
            </div>
            <button type="button" className="icon-btn mobile-trigger" aria-label="Menu" aria-expanded={open} onClick={() => setOpen(!open)}>
              {open ? <X /> : <Menu />}
            </button>
          </div>
        </div>
      </div>
      {open && (
        <nav className="mobile-nav" aria-label={t("Navigation mobile", "Mobile navigation", "تنقل الهاتف")}>
          {links.map((l) => (
            <Link key={l.to} to={l.to} onClick={close}>{l.label}</Link>
          ))}
          {spaceLinks}
          {auth?.userId ? (
            <button className="link" onClick={signOut}>{t("Déconnexion", "Sign out", "خروج")}</button>
          ) : (
            <Link to="/auth" onClick={close}>{t("Connexion", "Sign in", "دخول")}</Link>
          )}
          <div className="mobile-tools">
            <LangSwitch />
            <ThemeToggle />
          </div>
          <Button asChild className="ref-btn mt-2"><Link to="/reserver" onClick={close}>{t("Réserver une voiture", "Book a car", "احجز سيارة")}</Link></Button>
        </nav>
      )}
    </header>
  );
}

export function SiteFooter() {
  const { t } = useI18n();
  return (
    <footer className="footer-ref">
      <div className="container-ref">
        <div className="footer-grid">
          <div>
            <Brand withSlogan />
            <p>{t(
              "Voitures de mariage, transport familial vers la salle des fêtes et trajets privés avec chauffeur.",
              "Wedding cars, family transport to the venue and private trips with a chauffeur.",
              "سيارات الأعراس، نقل العائلة إلى قاعة الأفراح، ورحلات خاصة مع سائق.",
            )}</p>
            <span className="footer-slogan">{SLOGAN_LONG}</span>
          </div>
          <div>
            <h4>{t("Services", "Services", "الخدمات")}</h4>
            <Link to="/reserver">{t("Mariage & événement", "Wedding & event", "عرس ومناسبة")}</Link>
            <Link to="/reserver">{t("Transport familial", "Family transport", "نقل العائلة")}</Link>
            <Link to="/reserver">{t("Aller-retour salle des fêtes", "Venue round trip", "ذهاب وإياب للقاعة")}</Link>
          </div>
          <div>
            <h4>{t("Partenaires", "Partners", "الشركاء")}</h4>
            <Link to="/devenir-partenaire">{t("Proposer ma voiture", "List my car", "اعرض سيارتك")}</Link>
            <Link to="/auth">{t("Connexion partenaire", "Partner sign in", "دخول الشريك")}</Link>
          </div>
          <div>
            <h4>{t("Suivi", "Follow-up", "المتابعة")}</h4>
            <Link to="/compte">{t("Suivre ma demande", "Track my request", "تتبع طلبي")}</Link>
            <Link to="/vehicules">{t("Nos véhicules", "Our vehicles", "سياراتنا")}</Link>
          </div>
        </div>
        <div className="footer-bottom">
          <span>© {new Date().getFullYear()} Far7tek — {SLOGAN}</span>
          <span>{t(
            "Paiement et contrat après confirmation par un responsable",
            "Payment and contract after confirmation by a manager",
            "الدفع والعقد بعد تأكيد المسؤول",
          )}</span>
        </div>
      </div>
    </footer>
  );
}

export function StatusPill({ label }: { label?: string | undefined }) {
  return <span className="status-ref">{label ?? ""}</span>;
}
