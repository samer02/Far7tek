import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { fetchCars } from "@/lib/cars";
import { ASSIGNMENT_STATUS, BOOKING_STATUS, PARTNER_TRIP_TRANSITIONS, fmtDate, serviceLabel } from "@/lib/platform";
import { addCarPhoto, respondAssignment, updateCarAvailability, updateTripStatus } from "@/lib/partner.functions";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";

export const Route = createFileRoute("/_authenticated/partenaire")({
  head: () => ({ meta: [{ title: "Espace partenaire — Cortège & Cérémonie" }, { name: "robots", content: "noindex" }] }),
  component: PartnerDashboard,
});

const TABS = ["Tableau de bord", "Demandes", "Historique", "Mon véhicule", "Profil", "Notifications"] as const;

function PartnerDashboard() {
  const { data: auth, isLoading } = useAuth();
  const [tab, setTab] = useState<(typeof TABS)[number]>("Tableau de bord");
  const qc = useQueryClient();
  const respond = useServerFn(respondAssignment);
  const moveTrip = useServerFn(updateTripStatus);

  const uid = auth?.userId;
  const { data: items = [] } = useQuery({
    queryKey: ["partner-assignments", uid],
    enabled: !!uid,
    queryFn: async () => {
      const { data: as } = await supabase.from("trip_assignments").select("*").eq("partner_id", uid!).order("created_at", { ascending: false });
      const ids = (as ?? []).map((a) => a.booking_request_id);
      const { data: bs } = ids.length ? await supabase.from("booking_requests").select("*").in("id", ids) : { data: [] };
      return (as ?? []).map((a) => ({ a, b: (bs ?? []).find((b) => b.id === a.booking_request_id) })).filter((x) => x.b);
    },
  });

  if (isLoading) return <div className="container-ref section-ref">Chargement…</div>;
  if (!auth?.roles.includes("partner"))
    return (
      <div className="auth-panel">
        <h1>Espace partenaire</h1>
        <p>Cet espace est réservé aux propriétaires dont le dossier a été accepté.</p>
        <Button asChild className="ref-btn"><Link to="/devenir-partenaire">Proposer ma voiture</Link></Button>
      </div>
    );

  const refresh = () => qc.invalidateQueries({ queryKey: ["partner-assignments"] });
  async function act(fn: () => Promise<unknown>, msg: string) {
    try { await fn(); toast.success(msg); refresh(); } catch (e) { toast.error((e as Error).message); }
  }

  const active = items.filter((x) => x.a.status !== "rejected");
  const today = new Date().toISOString().slice(0, 10);
  const kpis = [
    ["Demandes reçues", items.length],
    ["Nouvelles", items.filter((x) => x.a.status === "proposed").length],
    ["En attente de réponse", items.filter((x) => x.a.status === "proposed").length],
    ["Acceptées", active.filter((x) => x.a.status === "accepted").length],
    ["Refusées / annulées", items.filter((x) => x.a.status === "rejected" || x.b!.status === "cancelled").length],
    ["Prochains trajets", active.filter((x) => x.a.status === "accepted" && x.b!.wedding_date >= today && ["accepted", "confirmed"].includes(x.b!.status)).length],
  ] as const;

  const list = (rows: typeof items) =>
    !rows.length ? <p className="admin-empty">Aucune demande.</p> : (
      <div className="admin-list-grid">
        {rows.map(({ a, b }) => (
          <div key={a.id} className="admin-list-card">
            <div className="car-meta"><span>Réf. {b!.reference}</span><StatusPill label={a.status === "accepted" ? BOOKING_STATUS[b!.status] : ASSIGNMENT_STATUS[a.status]} /></div>
            <h3>{b!.first_name} {b!.last_name}</h3>
            <p>
              {serviceLabel(b!.service_type)} · {b!.trip_type === "round_trip" ? "Aller-retour" : "Aller simple"}<br />
              {fmtDate(b!.wedding_date)} · {b!.wedding_time.slice(0, 5)}{b!.return_time ? ` → retour ${b!.return_time.slice(0, 5)}` : ""}<br />
              {b!.pickup_address} → {b!.venue} ({b!.city})<br />
              {b!.passengers} passager(s){b!.message ? ` · ${b!.message}` : ""}<br />
              {a.status === "accepted" ? <>Tél. client : <a href={`tel:${b!.phone}`} className="text-primary">{b!.phone}</a></> : "Téléphone visible après acceptation"}
            </p>
            {a.rejection_reason && <p className="form-error">Motif : {a.rejection_reason}</p>}
            <div className="action-row">
              {a.status === "proposed" && (
                <>
                  <Button className="ref-btn" onClick={() => act(() => respond({ data: { id: a.id, accept: true, reason: "" } }), "Demande acceptée")}>Accepter</Button>
                  <Button variant="outline" className="ref-btn" onClick={() => {
                    const reason = window.prompt("Motif du refus ?")?.trim();
                    if (reason) act(() => respond({ data: { id: a.id, accept: false, reason } }), "Demande refusée");
                  }}>Refuser</Button>
                </>
              )}
              {a.status === "accepted" && (PARTNER_TRIP_TRANSITIONS[b!.status] ?? []).map((s) => (
                <Button key={s} variant={s === "cancelled" ? "outline" : "default"} className="ref-btn"
                  onClick={() => act(() => moveTrip({ data: { bookingId: b!.id, status: s as any } }), "Statut mis à jour")}>
                  {BOOKING_STATUS[s]}
                </Button>
              ))}
            </div>
          </div>
        ))}
      </div>
    );

  const isHistory = (x: (typeof items)[number]) => x.a.status === "rejected" || ["completed", "cancelled"].includes(x.b!.status);

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header"><div><span className="eyebrow">Espace partenaire</span><h1>Bonjour</h1><p>{auth.email}</p></div></div>
        <div className="registry-tabs mb-6">
          {TABS.map((t) => <Button key={t} variant={t === tab ? "default" : "ghost"} className="ref-btn" onClick={() => setTab(t)}>{t}</Button>)}
        </div>
        {tab === "Tableau de bord" && (
          <>
            <div className="kpi-grid">{kpis.map(([l, v]) => <div key={l} className="kpi"><div className="kpi-label">{l}</div><div className="kpi-value">{v}</div></div>)}</div>
            <h3 className="mb-4">À traiter</h3>
            {list(items.filter((x) => x.a.status === "proposed" || (x.a.status === "accepted" && !isHistory(x))))}
          </>
        )}
        {tab === "Demandes" && list(items.filter((x) => !isHistory(x)))}
        {tab === "Historique" && list(items.filter(isHistory))}
        {tab === "Mon véhicule" && <PartnerVehicle uid={uid!} />}
        {tab === "Profil" && <PartnerProfile uid={uid!} />}
        {tab === "Notifications" && <NotificationsPanel />}
      </div>
    </section>
  );
}

function PartnerVehicle({ uid }: { uid: string }) {
  const qc = useQueryClient();
  const saveAvail = useServerFn(updateCarAvailability);
  const savePhoto = useServerFn(addCarPhoto);
  const { data: cars = [] } = useQuery({ queryKey: ["my-cars", uid], queryFn: () => fetchCars({ ownerId: uid }) });
  const { data: changes = [] } = useQuery({
    queryKey: ["my-changes", uid],
    queryFn: async () => (await supabase.from("vehicle_change_requests").select("*").order("created_at", { ascending: false })).data ?? [],
  });
  if (!cars.length) return <p className="admin-empty">Votre véhicule est en cours de création par l’équipe.</p>;
  const car = cars[0]!;
  const { data: raw } = { data: car as any };

  async function upload(files: FileList | null) {
    for (const f of [...(files ?? [])]) {
      if (!f.type.startsWith("image/") || f.size > 8 * 1024 * 1024) { toast.error("Image de 8 Mo max."); continue; }
      const path = `${uid}/${car.id}/${crypto.randomUUID()}.${f.name.split(".").pop()}`;
      const up = await supabase.storage.from("car-images").upload(path, f, { contentType: f.type });
      if (up.error) { toast.error("Envoi impossible"); continue; }
      await savePhoto({ data: { carId: car.id, path } });
    }
    toast.success("Photos ajoutées");
    qc.invalidateQueries({ queryKey: ["my-cars"] });
  }

  async function submitChange(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = Object.fromEntries(new FormData(e.currentTarget)) as any;
    const changes: Record<string, unknown> = {};
    if (f.color && f.color !== car.color) changes.color = f.color.slice(0, 40);
    if (f.seats && Number(f.seats) !== car.seats) changes.seats = Math.max(1, Math.min(60, Number(f.seats)));
    if (f.price_from && Number(f.price_from) !== car.price_from) changes.price_from = Number(f.price_from);
    if (f.description && f.description !== car.description) changes.description = f.description.slice(0, 2000);
    if (!Object.keys(changes).length) { toast.info("Aucune modification"); return; }
    const { error } = await supabase.from("vehicle_change_requests").insert({ car_id: car.id, partner_id: uid, changes: changes as any });
    if (error) { toast.error("Envoi impossible"); return; }
    toast.success("Modification envoyée pour validation");
    qc.invalidateQueries({ queryKey: ["my-changes"] });
  }

  return (
    <div className="dossier">
      <div className="car-meta"><span>{car.category}</span><StatusPill label={raw.validation_status === "active" ? "Publié" : raw.validation_status === "pending" ? "En attente de validation" : "Désactivé"} /></div>
      <h3>{car.name}</h3>
      <div className="admin-photo-strip">{car.images.map((u) => <img key={u} src={u} alt={car.name} />)}</div>
      <label className="ref-btn inline-flex cursor-pointer items-center border border-border px-4">
        Ajouter des photos<input type="file" accept="image/*" multiple className="sr-only" onChange={(e) => upload(e.target.files)} />
      </label>
      <form className="ref-form mt-6" onSubmit={async (e): Promise<void> => {
        e.preventDefault();
        const v = String(new FormData(e.currentTarget).get("availability") ?? "");
        try { await saveAvail({ data: { carId: car.id, availability: v } }); toast.success("Disponibilités mises à jour"); qc.invalidateQueries({ queryKey: ["my-cars"] }); } catch (err) { toast.error((err as Error).message); }
      }}>
        <label className="form-field form-wide"><span>Disponibilités</span><input name="availability" defaultValue={car.availability} /></label>
        <Button className="ref-btn">Enregistrer les disponibilités</Button>
      </form>
      <form className="ref-form form-section" onSubmit={submitChange}>
        <h3 className="form-wide">Modifications soumises à validation</h3>
        <label className="form-field"><span>Couleur</span><input name="color" defaultValue={car.color ?? ""} /></label>
        <label className="form-field"><span>Places</span><input name="seats" type="number" defaultValue={car.seats ?? 4} /></label>
        <label className="form-field"><span>Tarif indicatif (€)</span><input name="price_from" type="number" defaultValue={car.price_from ?? 0} /></label>
        <label className="form-field form-wide"><span>Description</span><textarea name="description" defaultValue={car.description} /></label>
        <Button className="ref-btn">Soumettre à l’administration</Button>
      </form>
      {changes.map((c) => <div key={c.id} className="note-row"><small>{fmtDate(c.created_at)} · {c.status === "pending" ? "En attente" : c.status === "approved" ? "Validée" : "Refusée"}</small> {Object.keys(c.changes as object).join(", ")}</div>)}
    </div>
  );
}

function PartnerProfile({ uid }: { uid: string }) {
  const { data: p } = useQuery({ queryKey: ["profile", uid], queryFn: async () => (await supabase.from("profiles").select("*").eq("id", uid).maybeSingle()).data });
  return (
    <div className="admin-edit-grid">
      <form key={p?.id ?? "x"} className="dossier ref-form" onSubmit={async (e): Promise<void> => {
        e.preventDefault();
        const f = Object.fromEntries(new FormData(e.currentTarget)) as any;
        const { error } = await supabase.from("profiles").upsert({ id: uid, first_name: f.first_name.slice(0, 80), last_name: f.last_name.slice(0, 80), phone: f.phone.slice(0, 20) });
        error ? toast.error("Enregistrement impossible") : toast.success("Profil enregistré");
      }}>
        <h3 className="form-wide">Profil et coordonnées</h3>
        <label className="form-field"><span>Prénom</span><input name="first_name" defaultValue={p?.first_name ?? ""} /></label>
        <label className="form-field"><span>Nom</span><input name="last_name" defaultValue={p?.last_name ?? ""} /></label>
        <label className="form-field form-wide"><span>Téléphone</span><input name="phone" defaultValue={p?.phone ?? ""} /></label>
        <Button className="ref-btn">Enregistrer</Button>
      </form>
      <form className="dossier ref-form" onSubmit={async (e): Promise<void> => {
        e.preventDefault();
        const pw = String(new FormData(e.currentTarget).get("password"));
        if (pw.length < 8) { toast.error("8 caractères minimum"); return; }
        const { error } = await supabase.auth.updateUser({ password: pw });
        error ? toast.error(error.message) : toast.success("Mot de passe modifié");
        e.currentTarget.reset();
      }}>
        <h3 className="form-wide">Sécurité du compte</h3>
        <label className="form-field form-wide"><span>Nouveau mot de passe</span><input name="password" type="password" autoComplete="new-password" /></label>
        <Button className="ref-btn">Changer le mot de passe</Button>
      </form>
    </div>
  );
}
