import { Link, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { Menu, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";

const links = [
  { to: "/", label: "Accueil" },
  { to: "/vehicules", label: "Découvrir les véhicules" },
  { to: "/reserver", label: "Réserver une voiture" },
  { to: "/devenir-partenaire", label: "Devenir partenaire" },
  { to: "/compte", label: "Suivre ma demande" },
] as const;

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const { data: auth } = useAuth();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const roles = auth?.roles ?? [];

  async function signOut() {
    await qc.cancelQueries();
    qc.clear();
    await supabase.auth.signOut();
    navigate({ to: "/auth", replace: true });
  }

  const spaceLinks = (
    <>
      {roles.includes("admin") && <Link to="/admin" onClick={() => setOpen(false)}>Administration</Link>}
      {roles.includes("partner") && <Link to="/partenaire" onClick={() => setOpen(false)}>Espace partenaire</Link>}
    </>
  );

  return (
    <header className="site-header">
      <div className="site-header-inner">
        <Link to="/" className="brand">
          Cortège & Cérémonie<small>Voitures avec chauffeur</small>
        </Link>
        <nav className="desktop-nav" aria-label="Navigation principale">
          {links.map((l) => (
            <Link key={l.to} to={l.to} activeProps={{ "data-active": true } as any} activeOptions={{ exact: l.to === "/" }}>
              {l.label}
            </Link>
          ))}
          {spaceLinks}
        </nav>
        <div className="header-cta action-row">
          {auth?.userId ? (
            <Button variant="outline" className="ref-btn" onClick={signOut}>Se déconnecter</Button>
          ) : (
            <Button asChild variant="outline" className="ref-btn"><Link to="/auth">Connexion</Link></Button>
          )}
          <Button asChild className="ref-btn"><Link to="/reserver">Réserver</Link></Button>
        </div>
        <Button variant="ghost" size="icon" className="mobile-trigger" aria-label="Menu" onClick={() => setOpen(!open)}>
          {open ? <X /> : <Menu />}
        </Button>
      </div>
      {open && (
        <nav className="mobile-nav" aria-label="Navigation mobile">
          {links.map((l) => (
            <Link key={l.to} to={l.to} onClick={() => setOpen(false)}>{l.label}</Link>
          ))}
          {spaceLinks}
          {auth?.userId ? (
            <button className="text-left" onClick={signOut}>Se déconnecter</button>
          ) : (
            <Link to="/auth" onClick={() => setOpen(false)}>Connexion</Link>
          )}
        </nav>
      )}
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="footer-ref">
      <div className="container-ref">
        <div className="footer-grid">
          <div>
            <span className="brand">Cortège & Cérémonie</span>
            <p>Voitures d’exception pour les mariages, transport familial et trajets privés avec chauffeur.</p>
          </div>
          <div>
            <h4>Services</h4>
            <Link to="/reserver">Mariage & événement</Link>
            <Link to="/reserver">Transport familial</Link>
            <Link to="/reserver">Aller-retour salle des fêtes</Link>
          </div>
          <div>
            <h4>Partenaires</h4>
            <Link to="/devenir-partenaire">Proposer ma voiture</Link>
            <Link to="/auth">Connexion partenaire</Link>
          </div>
          <div>
            <h4>Suivi</h4>
            <Link to="/compte">Suivre ma demande</Link>
            <Link to="/vehicules">Nos véhicules</Link>
          </div>
        </div>
        <div className="footer-bottom">
          <span>© {new Date().getFullYear()} Cortège & Cérémonie</span>
          <span>Paiement et contrat après confirmation par un responsable</span>
        </div>
      </div>
    </footer>
  );
}

export function StatusPill({ label }: { label: string }) {
  return <span className="status-ref">{label}</span>;
}
