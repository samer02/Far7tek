import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { signedUrls } from "@/lib/cars";
import { BOOKING_STATUS, PROPOSAL_STATUS, ASSIGNMENT_STATUS, SERVICE_TYPES, fmtDate, matchScore, partnerServiceLabel, serviceLabel } from "@/lib/platform";
import { approvePartner, assignTrip, listClients, reviewChangeRequest, reviewPartner, setBookingStatus, setCarValidation } from "@/lib/admin.functions";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";

export const Route = createFileRoute("/_authenticated/admin")({
  head: () => ({ meta: [{ title: "Administration — Cortège & Cérémonie" }, { name: "robots", content: "noindex" }] }),
  component: Admin,
});

const SECTIONS = ["Vue générale", "Demandes clients", "Partenaires", "Véhicules", "Attribution", "Clients", "Trajets", "Notifications", "Paramètres"] as const;
type Section = (typeof SECTIONS)[number];

async function run(fn: () => Promise<unknown>, msg: string, after: () => void) {
  try { await fn(); toast.success(msg); after(); } catch (e) { toast.error((e as Error).message); }
}

function useAdminData() {
  const bookings = useQuery({ queryKey: ["adm-bookings"], queryFn: async () => (await supabase.from("booking_requests").select("*").order("created_at", { ascending: false })).data ?? [] });
  const proposals = useQuery({ queryKey: ["adm-proposals"], queryFn: async () => (await supabase.from("car_proposals").select("*, proposal_images(*)").order("created_at", { ascending: false })).data ?? [] });
  const cars = useQuery({ queryKey: ["adm-cars"], queryFn: async () => (await supabase.from("cars").select("*").order("created_at", { ascending: false })).data ?? [] });
  const assignments = useQuery({ queryKey: ["adm-assign"], queryFn: async () => (await supabase.from("trip_assignments").select("*").order("created_at", { ascending: false })).data ?? [] });
  const changes = useQuery({ queryKey: ["adm-changes"], queryFn: async () => (await supabase.from("vehicle_change_requests").select("*").eq("status", "pending")).data ?? [] });
  return { bookings: bookings.data ?? [], proposals: proposals.data ?? [], cars: cars.data ?? [], assignments: assignments.data ?? [], changes: changes.data ?? [] };
}

function Admin() {
  const { data: auth, isLoading } = useAuth();
  const [section, setSection] = useState<Section>("Vue générale");
  const qc = useQueryClient();
  const d = useAdminData();
  const refresh = () => qc.invalidateQueries({ predicate: (q) => String(q.queryKey[0]).startsWith("adm-") });

  if (isLoading) return <div className="container-ref section-ref">Chargement…</div>;
  if (!auth?.roles.includes("admin")) return <div className="auth-panel"><h1>Accès réservé</h1><p>Cet espace est réservé aux administrateurs.</p></div>;

  const partners = d.proposals.filter((p) => p.status === "approved" && p.partner_user_id);
  const ctx = { ...d, partners, refresh };

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header"><div><span className="eyebrow">Administration</span><h1>{section}</h1></div></div>
        <div className="registry-tabs mb-6">
          {SECTIONS.map((s) => <Button key={s} variant={s === section ? "default" : "ghost"} className="ref-btn" onClick={() => setSection(s)}>{s}</Button>)}
        </div>
        {section === "Vue générale" && <Overview {...ctx} />}
        {section === "Demandes clients" && <Requests {...ctx} />}
        {section === "Partenaires" && <Partners {...ctx} />}
        {section === "Véhicules" && <Vehicles {...ctx} />}
        {section === "Attribution" && <Assign {...ctx} />}
        {section === "Clients" && <Clients />}
        {section === "Trajets" && <Trips {...ctx} />}
        {section === "Notifications" && <NotificationsPanel admin />}
        {section === "Paramètres" && <Settings />}
      </div>
    </section>
  );
}

type Ctx = ReturnType<typeof useAdminData> & { partners: ReturnType<typeof useAdminData>["proposals"]; refresh: () => void };

function Overview({ bookings, proposals, cars, assignments }: Ctx) {
  const k = [
    ["Demandes clients", bookings.length],
    ["Demandes en attente", bookings.filter((b) => b.status === "pending" || b.status === "new").length],
    ["Dossiers partenaires à traiter", proposals.filter((p) => ["pending", "new", "reviewing", "info_requested"].includes(p.status)).length],
    ["Partenaires actifs", proposals.filter((p) => p.status === "approved").length],
    ["Véhicules à valider", cars.filter((c) => c.validation_status === "pending").length],
    ["Trajets confirmés", bookings.filter((b) => ["accepted", "confirmed", "in_progress"].includes(b.status)).length],
  ] as const;
  return (
    <>
      <div className="kpi-grid">{k.map(([l, v]) => <div key={l} className="kpi"><div className="kpi-label">{l}</div><div className="kpi-value">{v}</div></div>)}</div>
      <div className="registry"><h3 className="mb-3">Activité récente</h3>
        {bookings.slice(0, 5).map((b) => <div key={b.id} className="note-row"><small>{fmtDate(b.created_at)}</small> Demande {b.reference} — {b.first_name} {b.last_name} · {serviceLabel(b.service_type)} · {BOOKING_STATUS[b.status]}</div>)}
        {assignments.slice(0, 3).map((a) => <div key={a.id} className="note-row"><small>{fmtDate(a.created_at)}</small> Attribution {ASSIGNMENT_STATUS[a.status]}</div>)}
      </div>
    </>
  );
}

function Filters({ q, setQ, status, setStatus, statuses, extra }: { q: string; setQ: (v: string) => void; status: string; setStatus: (v: string) => void; statuses: Record<string, string>; extra?: React.ReactNode }) {
  return (
    <div className="flex flex-wrap gap-3 mb-4">
      <input className="admin-search" placeholder="Rechercher (nom, ville, référence…)" value={q} onChange={(e) => setQ(e.target.value)} />
      <select className="admin-select" value={status} onChange={(e) => setStatus(e.target.value)}>
        <option value="">Tous les statuts</option>
        {Object.entries(statuses).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
      </select>
      {extra}
    </div>
  );
}

function Requests({ bookings, assignments, partners, refresh }: Ctx) {
  const setStatus = useServerFn(setBookingStatus);
  const [q, setQ] = useState(""); const [st, setSt] = useState(""); const [svc, setSvc] = useState(""); const [partner, setPartner] = useState("");
  const [sort, setSort] = useState<"created" | "date">("created");
  const partnerOf = (id: string) => assignments.find((a) => a.booking_request_id === id && a.status !== "rejected")?.partner_id;
  const name = (uid?: string) => { const p = partners.find((x) => x.partner_user_id === uid); return p ? `${p.first_name} ${p.last_name}` : "—"; };
  const rows = bookings
    .filter((b) => (!st || b.status === st) && (!svc || b.service_type === svc) && (!partner || partnerOf(b.id) === partner))
    .filter((b) => !q || `${b.reference} ${b.first_name} ${b.last_name} ${b.city} ${b.phone}`.toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => (sort === "date" ? a.wedding_date.localeCompare(b.wedding_date) : b.created_at.localeCompare(a.created_at)));
  return (
    <div className="registry">
      <Filters q={q} setQ={setQ} status={st} setStatus={setSt} statuses={BOOKING_STATUS} extra={<>
        <select className="admin-select" value={svc} onChange={(e) => setSvc(e.target.value)}><option value="">Tous services</option>{SERVICE_TYPES.map((s) => <option key={s.value} value={s.value}>{s.label}</option>)}</select>
        <select className="admin-select" value={partner} onChange={(e) => setPartner(e.target.value)}><option value="">Tous partenaires</option>{partners.map((p) => <option key={p.id} value={p.partner_user_id!}>{p.first_name} {p.last_name}</option>)}</select>
        <select className="admin-select" value={sort} onChange={(e) => setSort(e.target.value as any)}><option value="created">Plus récentes</option><option value="date">Date du service</option></select>
      </>} />
      <div className="table-scroll"><table className="registry-table">
        <thead><tr><th>Réf.</th><th>Client</th><th>Service</th><th>Date</th><th>Trajet</th><th>Partenaire</th><th>Statut</th></tr></thead>
        <tbody>{rows.map((b) => (
          <tr key={b.id}>
            <td>{b.reference}<small>{fmtDate(b.created_at)}</small></td>
            <td><strong>{b.first_name} {b.last_name}</strong><small><a href={`tel:${b.phone}`}>{b.phone}</a> · {b.email}</small></td>
            <td>{serviceLabel(b.service_type)}<small>{b.passengers} pass. · {b.vehicle_type || "Sans préférence"}</small></td>
            <td>{fmtDate(b.wedding_date)}<small>{b.wedding_time.slice(0, 5)}{b.return_time ? ` / ${b.return_time.slice(0, 5)}` : ""}</small></td>
            <td>{b.pickup_address}<small>→ {b.venue} ({b.city}) · {b.trip_type === "round_trip" ? "A/R" : "Aller"}</small>{b.message && <small>{b.message}</small>}</td>
            <td>{name(partnerOf(b.id))}</td>
            <td><select className="admin-select" value={b.status} onChange={(e) => run(() => setStatus({ data: { id: b.id, status: e.target.value as any, note: "" } }), "Statut mis à jour", refresh)}>
              {Object.entries(BOOKING_STATUS).filter(([k]) => k !== "new").map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </select></td>
          </tr>
        ))}</tbody>
      </table>{!rows.length && <p className="admin-empty">Aucune demande.</p>}</div>
    </div>
  );
}

function Partners({ proposals, refresh }: Ctx) {
  const approve = useServerFn(approvePartner);
  const review = useServerFn(reviewPartner);
  const [q, setQ] = useState(""); const [st, setSt] = useState(""); const [open, setOpen] = useState<string | null>(null);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<{ id: string; note: string; created_at: string }[]>([]);
  const rows = proposals.filter((p) => (!st || p.status === st) && (!q || `${p.first_name} ${p.last_name} ${p.city} ${p.brand} ${p.model}`.toLowerCase().includes(q.toLowerCase())));
  const cur = proposals.find((p) => p.id === open);

  async function openDossier(id: string) {
    setOpen(id);
    const p = proposals.find((x) => x.id === id)!;
    setUrls(await signedUrls("proposal-images", p.proposal_images.map((i) => i.storage_path)));
    setNotes((await supabase.from("admin_notes").select("id,note,created_at").eq("car_proposal_id", id).order("created_at")).data ?? []);
  }

  return (
    <>
      {cur && (
        <div className="dossier">
          <div className="registry-toolbar"><h3>{cur.first_name} {cur.last_name} — {cur.brand} {cur.model}</h3><Button variant="ghost" onClick={() => setOpen(null)}>Fermer</Button></div>
          <StatusPill label={PROPOSAL_STATUS[cur.status]} />
          <div className="admin-photo-strip">
            {cur.proposal_images.map((i) => i.kind === "document"
              ? <a key={i.id} href={urls[i.storage_path]} target="_blank" rel="noreferrer" className="note-row">Document</a>
              : <a key={i.id} href={urls[i.storage_path]} target="_blank" rel="noreferrer"><img src={urls[i.storage_path]} alt={i.kind} /></a>)}
          </div>
          <div className="dossier-grid">
            <div><small>Téléphone</small><a href={`tel:${cur.phone}`}>{cur.phone}</a></div>
            <div><small>E-mail</small><a href={`mailto:${cur.email}`}>{cur.email}</a></div>
            <div><small>Ville / adresse</small>{cur.city} · {cur.address}</div>
            <div><small>Véhicule</small>{cur.year} · {cur.color} · {cur.vehicle_type} · {cur.seats} places · {cur.vehicle_condition}</div>
            <div><small>Services</small>{cur.services.map(partnerServiceLabel).join(", ")}</div>
            <div><small>Disponibilités / tarif</small>{cur.availability} · {cur.desired_rate ? `${cur.desired_rate} €` : "non communiqué"}</div>
            <div className="form-wide"><small>Description</small>{cur.description}</div>
            {cur.extra_info && <div className="form-wide"><small>Infos complémentaires</small>{cur.extra_info}</div>}
            {cur.rejection_reason && <div className="form-wide"><small>Motif de refus</small>{cur.rejection_reason}</div>}
            {cur.info_request && <div className="form-wide"><small>Compléments demandés</small>{cur.info_request}</div>}
          </div>
          {cur.status !== "approved" && (
            <div className="action-row mt-4">
              <Button className="ref-btn" onClick={() => run(async () => { const r = await approve({ data: { id: cur.id, origin: window.location.origin } }); if (r.invited) toast.info("Invitation envoyée par e-mail au propriétaire"); }, "Dossier accepté", refresh)}>Accepter</Button>
              <Button variant="outline" className="ref-btn" onClick={() => { const m = window.prompt("Motif du refus ?")?.trim(); if (m) run(() => review({ data: { id: cur.id, action: "reject", message: m } }), "Dossier refusé", refresh); }}>Refuser</Button>
              <Button variant="outline" className="ref-btn" onClick={() => { const m = window.prompt("Informations à demander ?")?.trim(); if (m) run(() => review({ data: { id: cur.id, action: "info", message: m } }), "Demande envoyée", refresh); }}>Demander des compléments</Button>
              <Button asChild variant="ghost" className="ref-btn"><a href={`mailto:${cur.email}?subject=Votre dossier partenaire`}>Contacter</a></Button>
            </div>
          )}
          <h3 className="mt-6">Notes internes</h3>
          {notes.map((n) => <div key={n.id} className="note-row"><small>{new Date(n.created_at).toLocaleString("fr-FR")}</small><p>{n.note}</p></div>)}
          <form className="ref-form mt-3" onSubmit={async (e) => {
            e.preventDefault();
            const form = e.currentTarget;
            const note = String(new FormData(form).get("note") ?? "").trim().slice(0, 2000);
            if (!note) return;
            const { error } = await supabase.from("admin_notes").insert({ car_proposal_id: cur.id, note, author_id: (await supabase.auth.getUser()).data.user!.id });
            if (error) return toast.error("Note non enregistrée");
            form.reset(); openDossier(cur.id);
          }}>
            <label className="form-field form-wide"><span>Ajouter une note</span><textarea name="note" /></label>
            <Button className="ref-btn">Enregistrer la note</Button>
          </form>
        </div>
      )}
      <div className="registry">
        <Filters q={q} setQ={setQ} status={st} setStatus={setSt} statuses={{ pending: "En attente", reviewing: "En étude", info_requested: "Compléments demandés", approved: "Actifs", rejected: "Refusés" }} />
        <div className="table-scroll"><table className="registry-table">
          <thead><tr><th>Propriétaire</th><th>Téléphone</th><th>Ville</th><th>Véhicule</th><th>Services</th><th>Soumis le</th><th>Statut</th><th></th></tr></thead>
          <tbody>{rows.map((p) => (
            <tr key={p.id}>
              <td><strong>{p.first_name} {p.last_name}</strong></td><td>{p.phone}</td><td>{p.city}</td><td>{p.brand} {p.model}</td>
              <td>{p.services.map(partnerServiceLabel).join(", ")}</td><td>{fmtDate(p.created_at)}</td>
              <td><StatusPill label={PROPOSAL_STATUS[p.status]} /></td>
              <td><Button variant="outline" className="ref-btn" onClick={() => openDossier(p.id)}>Consulter</Button></td>
            </tr>
          ))}</tbody>
        </table>{!rows.length && <p className="admin-empty">Aucun dossier.</p>}</div>
      </div>
    </>
  );
}

function Vehicles({ cars, changes, refresh }: Ctx) {
  const setVal = useServerFn(setCarValidation);
  const reviewCh = useServerFn(reviewChangeRequest);
  const [st, setSt] = useState("");
  const label: Record<string, string> = { pending: "En attente", active: "Actif", disabled: "Désactivé" };
  return (
    <>
      {changes.length > 0 && (
        <div className="registry"><h3 className="mb-3">Modifications à valider</h3>
          {changes.map((c) => (
            <div key={c.id} className="note-row">
              <strong>{cars.find((x) => x.id === c.car_id)?.name}</strong>
              <p>{Object.entries(c.changes as Record<string, unknown>).map(([k, v]) => `${k} : ${v}`).join(" · ")}</p>
              <div className="action-row">
                <Button className="ref-btn" onClick={() => run(() => reviewCh({ data: { id: c.id, approve: true } }), "Modification appliquée", refresh)}>Valider</Button>
                <Button variant="outline" className="ref-btn" onClick={() => run(() => reviewCh({ data: { id: c.id, approve: false } }), "Modification refusée", refresh)}>Refuser</Button>
              </div>
            </div>
          ))}
        </div>
      )}
      <div className="registry">
        <div className="filter-row">{["", "pending", "active", "disabled"].map((s) => <Button key={s} variant={st === s ? "default" : "outline"} className="filter-btn" onClick={() => setSt(s)}>{s ? label[s] : "Tous"}</Button>)}</div>
        <div className="table-scroll"><table className="registry-table">
          <thead><tr><th>Véhicule</th><th>Ville</th><th>Places</th><th>Propriétaire</th><th>Statut</th><th></th></tr></thead>
          <tbody>{cars.filter((c) => !st || c.validation_status === st).map((c) => (
            <tr key={c.id}>
              <td><strong>{c.name}</strong><small>{c.category}</small></td><td>{c.city}</td><td>{c.seats}</td><td>{c.owner_id ? "Partenaire" : "Flotte"}</td>
              <td><StatusPill label={label[c.validation_status] ?? c.validation_status} /></td>
              <td className="action-row">
                {c.validation_status !== "active" && <Button className="ref-btn" onClick={() => run(() => setVal({ data: { carId: c.id, status: "active" } }), "Véhicule publié", refresh)}>Valider / publier</Button>}
                {c.validation_status !== "disabled" && <Button variant="outline" className="ref-btn" onClick={() => run(() => setVal({ data: { carId: c.id, status: "disabled" } }), "Véhicule désactivé", refresh)}>Désactiver</Button>}
              </td>
            </tr>
          ))}</tbody>
        </table></div>
      </div>
    </>
  );
}

function Assign({ bookings, assignments, partners, cars, refresh }: Ctx) {
  const assign = useServerFn(assignTrip);
  const open = bookings.filter((b) => ["pending", "new", "contacted"].includes(b.status) && !assignments.some((a) => a.booking_request_id === b.id && a.status !== "rejected"));
  return (
    <div className="registry">
      {!open.length && <p className="admin-empty">Aucune demande à attribuer.</p>}
      {open.map((b) => {
        const options = partners
          .map((p) => { const car = cars.find((c) => c.id === p.car_id); return { p, car, score: car ? matchScore(b, car) : 0 }; })
          .filter((o) => o.score >= 0)
          .sort((x, y) => y.score - x.score);
        return (
          <div key={b.id} className="note-row">
            <strong>{b.reference} — {serviceLabel(b.service_type)}</strong>
            <p>{fmtDate(b.wedding_date)} {b.wedding_time.slice(0, 5)} · {b.city} · {b.passengers} pass. · {b.vehicle_type || "Sans préférence"}</p>
            {assignments.filter((a) => a.booking_request_id === b.id && a.status === "rejected").map((a) => <small key={a.id}>Refusée précédemment : {a.rejection_reason}</small>)}
            <div className="action-row mt-2">
              {!options.length && <small>Aucun partenaire compatible (places).</small>}
              {options.slice(0, 5).map(({ p, car, score }) => (
                <Button key={p.id} variant={score >= 3 ? "default" : "outline"} className="ref-btn"
                  onClick={() => run(() => assign({ data: { bookingId: b.id, partnerId: p.partner_user_id!, carId: car?.id ?? null } }), "Demande attribuée", refresh)}>
                  {p.first_name} {p.last_name} · {car?.name ?? "—"} ({car?.city}) {score >= 3 ? "★ suggéré" : ""}
                </Button>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function Trips({ bookings, assignments }: Ctx) {
  const today = new Date().toISOString().slice(0, 10);
  const groups = useMemo(() => ({
    "À venir": bookings.filter((b) => ["accepted", "confirmed"].includes(b.status) && b.wedding_date >= today),
    "En cours": bookings.filter((b) => b.status === "in_progress"),
    "Terminés": bookings.filter((b) => b.status === "completed"),
    "Annulés": bookings.filter((b) => b.status === "cancelled" || b.status === "rejected"),
  }), [bookings, today]);
  return (
    <div className="admin-edit-grid">
      {Object.entries(groups).map(([g, rows]) => (
        <div key={g} className="registry"><h3 className="mb-3">{g} ({rows.length})</h3>
          {rows.map((b) => <div key={b.id} className="note-row"><strong>{b.reference}</strong> {fmtDate(b.wedding_date)} · {b.pickup_address} → {b.venue}<small>{assignments.some((a) => a.booking_request_id === b.id && a.status === "accepted") ? "Partenaire assigné" : "Sans partenaire"}</small></div>)}
        </div>
      ))}
    </div>
  );
}

function Clients() {
  const fetchClients = useServerFn(listClients);
  const { data, isLoading, error } = useQuery({ queryKey: ["adm-clients"], queryFn: () => fetchClients() });
  const [q, setQ] = useState("");
  if (isLoading) return <p>Chargement…</p>;
  if (error) return <p className="form-error">Liste indisponible.</p>;
  return (
    <div className="registry">
      <input className="admin-search mb-4" placeholder="Rechercher un e-mail" value={q} onChange={(e) => setQ(e.target.value)} />
      <div className="table-scroll"><table className="registry-table">
        <thead><tr><th>E-mail</th><th>Rôles</th><th>Demandes</th><th>Inscrit le</th><th>Dernière connexion</th></tr></thead>
        <tbody>{(data ?? []).filter((u) => u.email.includes(q.toLowerCase())).map((u) => (
          <tr key={u.id}><td><a href={`mailto:${u.email}`}>{u.email}</a></td><td>{u.roles.join(", ") || "client"}</td><td>{u.requests}</td><td>{fmtDate(u.created_at)}</td><td>{u.last_sign_in_at ? fmtDate(u.last_sign_in_at) : "—"}</td></tr>
        ))}</tbody>
      </table></div>
    </div>
  );
}

function Settings() {
  return (
    <div className="registry">
      <h3 className="mb-3">Services et règles</h3>
      {SERVICE_TYPES.map((s) => <div key={s.value} className="note-row">{s.label}</div>)}
      <p className="mt-4">Attribution : manuelle, avec suggestion des partenaires selon la ville, le nombre de places, le type de véhicule et les services proposés. Un partenaire doit accepter la demande avant de voir le téléphone du client.</p>
      <p className="mt-2">Notifications : internes au site. Les envois par e-mail ou SMS ne sont pas encore configurés (seule l’invitation partenaire part par e-mail).</p>
    </div>
  );
}
