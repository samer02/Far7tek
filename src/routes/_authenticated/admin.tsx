import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useMemo, useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { signedUrls } from "@/lib/cars";
import { BOOKING_STATUS, PROPOSAL_STATUS, ASSIGNMENT_STATUS, CAR_VALIDATION, SERVICE_TYPES, matchScore, partnerServiceLabel, serviceLabel, vehicleTypeLabel } from "@/lib/platform";
import { approvePartner, assignTrip, listClients, reviewChangeRequest, reviewPartner, setBookingStatus, setCarValidation } from "@/lib/admin.functions";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";
import { labelOf, useI18n, type Tri } from "@/lib/i18n";

export const Route = createFileRoute("/_authenticated/admin")({
  head: () => ({ meta: [{ title: "Administration — Far7tek" }, { name: "robots", content: "noindex" }] }),
  component: Admin,
});

type Section = "overview" | "requests" | "partners" | "vehicles" | "assign" | "clients" | "trips" | "notifications" | "settings";
const SECTIONS: [Section, Tri][] = [
  ["overview", ["Vue générale", "Overview", "نظرة عامة"]],
  ["requests", ["Demandes clients", "Client requests", "طلبات العملاء"]],
  ["partners", ["Partenaires", "Partners", "الشركاء"]],
  ["vehicles", ["Véhicules", "Vehicles", "السيارات"]],
  ["assign", ["Attribution", "Assignment", "الإسناد"]],
  ["clients", ["Clients", "Clients", "العملاء"]],
  ["trips", ["Trajets", "Trips", "الرحلات"]],
  ["notifications", ["Notifications", "Notifications", "الإشعارات"]],
  ["settings", ["Paramètres", "Settings", "الإعدادات"]],
];

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
  const { t, p } = useI18n();
  const { data: auth, isLoading } = useAuth();
  const [section, setSection] = useState<Section>("overview");
  const qc = useQueryClient();
  const d = useAdminData();
  const refresh = () => qc.invalidateQueries({ predicate: (q) => String(q.queryKey[0]).startsWith("adm-") });

  if (isLoading) return <div className="container-ref section-ref">{t("Chargement…", "Loading…", "جارٍ التحميل…")}</div>;
  if (!auth?.roles.includes("admin"))
    return <div className="auth-panel"><h1>{t("Accès réservé", "Restricted access", "دخول مقيّد")}</h1><p>{t("Cet espace est réservé aux administrateurs.", "This area is for administrators only.", "هذا الفضاء مخصص للمشرفين فقط.")}</p></div>;

  const partners = d.proposals.filter((x) => x.status === "approved" && x.partner_user_id);
  const ctx = { ...d, partners, refresh };
  const current = SECTIONS.find(([k]) => k === section)!;

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header"><div><span className="eyebrow">{t("Administration", "Admin", "الإدارة")}</span><h1>{p(current[1])}</h1></div></div>
        <div className="registry-tabs mb-6">
          {SECTIONS.map(([k, l]) => <Button key={k} variant={k === section ? "default" : "ghost"} className="ref-btn" onClick={() => setSection(k)}>{p(l)}</Button>)}
        </div>
        {section === "overview" && <Overview {...ctx} />}
        {section === "requests" && <Requests {...ctx} />}
        {section === "partners" && <Partners {...ctx} />}
        {section === "vehicles" && <Vehicles {...ctx} />}
        {section === "assign" && <Assign {...ctx} />}
        {section === "clients" && <Clients />}
        {section === "trips" && <Trips {...ctx} />}
        {section === "notifications" && <NotificationsPanel admin />}
        {section === "settings" && <Settings />}
      </div>
    </section>
  );
}

type Ctx = ReturnType<typeof useAdminData> & { partners: ReturnType<typeof useAdminData>["proposals"]; refresh: () => void };

function Overview({ bookings, proposals, cars, assignments }: Ctx) {
  const { t, lang, date } = useI18n();
  const k = [
    [t("Demandes clients", "Client requests", "طلبات العملاء"), bookings.length],
    [t("Demandes en attente", "Pending requests", "طلبات قيد الانتظار"), bookings.filter((b) => b.status === "pending" || b.status === "new").length],
    [t("Dossiers partenaires à traiter", "Partner applications to review", "ملفات شركاء للمعالجة"), proposals.filter((x) => ["pending", "new", "reviewing", "info_requested"].includes(x.status)).length],
    [t("Partenaires actifs", "Active partners", "الشركاء النشطون"), proposals.filter((x) => x.status === "approved").length],
    [t("Véhicules à valider", "Vehicles to approve", "سيارات للموافقة"), cars.filter((c) => c.validation_status === "pending").length],
    [t("Trajets confirmés", "Confirmed trips", "الرحلات المؤكدة"), bookings.filter((b) => ["accepted", "confirmed", "in_progress"].includes(b.status)).length],
  ] as const;
  return (
    <>
      <div className="kpi-grid">{k.map(([l, v]) => <div key={l} className="kpi"><div className="kpi-label">{l}</div><div className="kpi-value">{v}</div></div>)}</div>
      <div className="registry"><h3 className="mb-3">{t("Activité récente", "Recent activity", "النشاط الأخير")}</h3>
        {bookings.slice(0, 5).map((b) => <div key={b.id} className="note-row"><small>{date(b.created_at)}</small> {t("Demande", "Request", "طلب")} {b.reference} — {b.first_name} {b.last_name} · {serviceLabel(b.service_type, lang)} · {labelOf(BOOKING_STATUS, b.status, lang)}</div>)}
        {assignments.slice(0, 3).map((a) => <div key={a.id} className="note-row"><small>{date(a.created_at)}</small> {t("Attribution", "Assignment", "إسناد")} {labelOf(ASSIGNMENT_STATUS, a.status, lang)}</div>)}
        {!bookings.length && !assignments.length && <p className="admin-empty">{t("Aucune activité pour le moment.", "No activity yet.", "لا يوجد نشاط حالياً.")}</p>}
      </div>
    </>
  );
}

function Filters({ q, setQ, status, setStatus, statuses, extra }: { q: string; setQ: (v: string) => void; status: string; setStatus: (v: string) => void; statuses: Record<string, Tri>; extra?: React.ReactNode }) {
  const { t, p } = useI18n();
  return (
    <div className="flex flex-wrap gap-3 mb-4">
      <input className="admin-search" placeholder={t("Rechercher (nom, ville, référence…)", "Search (name, city, reference…)", "بحث (الاسم، المدينة، المرجع…)")} value={q} onChange={(e) => setQ(e.target.value)} />
      <select className="admin-select" value={status} onChange={(e) => setStatus(e.target.value)}>
        <option value="">{t("Tous les statuts", "All statuses", "كل الحالات")}</option>
        {Object.entries(statuses).map(([k, v]) => <option key={k} value={k}>{p(v)}</option>)}
      </select>
      {extra}
    </div>
  );
}

function Requests({ bookings, assignments, partners, refresh }: Ctx) {
  const { t, p, lang, date } = useI18n();
  const setStatus = useServerFn(setBookingStatus);
  const [q, setQ] = useState(""); const [st, setSt] = useState(""); const [svc, setSvc] = useState(""); const [partner, setPartner] = useState("");
  const [sort, setSort] = useState<"created" | "date">("created");
  const partnerOf = (id: string) => assignments.find((a) => a.booking_request_id === id && a.status !== "rejected")?.partner_id;
  const name = (uid?: string) => { const x = partners.find((y) => y.partner_user_id === uid); return x ? `${x.first_name} ${x.last_name}` : "—"; };
  const rows = bookings
    .filter((b) => (!st || b.status === st) && (!svc || b.service_type === svc) && (!partner || partnerOf(b.id) === partner))
    .filter((b) => !q || `${b.reference} ${b.first_name} ${b.last_name} ${b.city} ${b.phone}`.toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => (sort === "date" ? a.wedding_date.localeCompare(b.wedding_date) : b.created_at.localeCompare(a.created_at)));
  return (
    <div className="registry">
      <Filters q={q} setQ={setQ} status={st} setStatus={setSt} statuses={BOOKING_STATUS} extra={<>
        <select className="admin-select" value={svc} onChange={(e) => setSvc(e.target.value)}><option value="">{t("Tous services", "All services", "كل الخدمات")}</option>{SERVICE_TYPES.map((s) => <option key={s.value} value={s.value}>{p(s.label)}</option>)}</select>
        <select className="admin-select" value={partner} onChange={(e) => setPartner(e.target.value)}><option value="">{t("Tous partenaires", "All partners", "كل الشركاء")}</option>{partners.map((x) => <option key={x.id} value={x.partner_user_id!}>{x.first_name} {x.last_name}</option>)}</select>
        <select className="admin-select" value={sort} onChange={(e) => setSort(e.target.value as "created" | "date")}><option value="created">{t("Plus récentes", "Most recent", "الأحدث")}</option><option value="date">{t("Date du service", "Service date", "تاريخ الخدمة")}</option></select>
      </>} />
      <div className="table-scroll"><table className="registry-table">
        <thead><tr><th>{t("Réf.", "Ref.", "مرجع")}</th><th>{t("Client", "Client", "العميل")}</th><th>{t("Service", "Service", "الخدمة")}</th><th>{t("Date", "Date", "التاريخ")}</th><th>{t("Trajet", "Route", "المسار")}</th><th>{t("Partenaire", "Partner", "الشريك")}</th><th>{t("Statut", "Status", "الحالة")}</th></tr></thead>
        <tbody>{rows.map((b) => (
          <tr key={b.id}>
            <td>{b.reference}<small>{date(b.created_at)}</small></td>
            <td><strong>{b.first_name} {b.last_name}</strong><small><a href={`tel:${b.phone}`} dir="ltr">{b.phone}</a> · {b.email}</small>
              <small className="flex gap-2 mt-1"><a className="text-primary" href={`tel:${b.phone}`}>{t("Appeler", "Call", "اتصال")}</a><a className="text-primary" href={`https://wa.me/${b.phone.replace(/[^0-9]/g, "")}`} target="_blank" rel="noreferrer">WhatsApp</a></small></td>
            <td>{serviceLabel(b.service_type, lang)}<small>{b.passengers} {t("pass.", "pax", "راكب")} · {b.vehicle_type ? vehicleTypeLabel(b.vehicle_type, lang) : t("Sans préférence", "No preference", "بدون تفضيل")}</small></td>
            <td>{date(b.wedding_date)}<small>{b.wedding_time.slice(0, 5)}{b.return_time ? ` / ${b.return_time.slice(0, 5)}` : ""}</small></td>
            <td>{b.pickup_address}<small>→ {b.venue} ({b.city}) · {b.trip_type === "round_trip" ? t("A/R", "Return", "ذهاب وإياب") : t("Aller", "One way", "ذهاب")}</small>{b.message && <small>{b.message}</small>}</td>
            <td>{name(partnerOf(b.id))}</td>
            <td><select className="admin-select" value={b.status} onChange={(e) => run(() => setStatus({ data: { id: b.id, status: e.target.value as "pending", note: "" } }), t("Statut mis à jour", "Status updated", "تم تحديث الحالة"), refresh)}>
              {Object.entries(BOOKING_STATUS).filter(([k]) => k !== "new").map(([k, v]) => <option key={k} value={k}>{p(v)}</option>)}
            </select></td>
          </tr>
        ))}</tbody>
      </table>{!rows.length && <p className="admin-empty">{t("Aucune demande.", "No requests.", "لا توجد طلبات.")}</p>}</div>
    </div>
  );
}

function Partners({ proposals, refresh }: Ctx) {
  const { t, lang, date, dateTime } = useI18n();
  const approve = useServerFn(approvePartner);
  const review = useServerFn(reviewPartner);
  const [q, setQ] = useState(""); const [st, setSt] = useState(""); const [open, setOpen] = useState<string | null>(null);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<{ id: string; note: string; created_at: string }[]>([]);
  const rows = proposals.filter((x) => (!st || x.status === st) && (!q || `${x.first_name} ${x.last_name} ${x.city} ${x.brand} ${x.model}`.toLowerCase().includes(q.toLowerCase())));
  const cur = proposals.find((x) => x.id === open);
  const svc = (list: string[]) => list.map((s) => partnerServiceLabel(s, lang)).join(", ");

  async function openDossier(id: string) {
    setOpen(id);
    const x = proposals.find((y) => y.id === id)!;
    setUrls(await signedUrls("proposal-images", x.proposal_images.map((i) => i.storage_path)));
    setNotes((await supabase.from("admin_notes").select("id,note,created_at").eq("car_proposal_id", id).order("created_at")).data ?? []);
  }

  return (
    <>
      {cur && (
        <div className="dossier">
          <div className="registry-toolbar"><h3>{cur.first_name} {cur.last_name} — {cur.brand} {cur.model}</h3><Button variant="ghost" className="ref-btn" onClick={() => setOpen(null)}>{t("Fermer", "Close", "إغلاق")}</Button></div>
          <StatusPill label={labelOf(PROPOSAL_STATUS, cur.status, lang)} />
          <div className="admin-photo-strip">
            {cur.proposal_images.map((i) => i.kind === "document"
              ? <a key={i.id} href={urls[i.storage_path]} target="_blank" rel="noreferrer" className="note-row">{t("Document", "Document", "وثيقة")}</a>
              : <a key={i.id} href={urls[i.storage_path]} target="_blank" rel="noreferrer"><img src={urls[i.storage_path]} alt={i.kind} /></a>)}
          </div>
          <div className="dossier-grid">
            <div><small>{t("Téléphone", "Phone", "الهاتف")}</small><a href={`tel:${cur.phone}`} dir="ltr">{cur.phone}</a></div>
            <div><small>{t("E-mail", "Email", "البريد")}</small><a href={`mailto:${cur.email}`}>{cur.email}</a></div>
            <div><small>{t("Ville / adresse", "City / address", "المدينة / العنوان")}</small>{cur.city} · {cur.address}</div>
            <div><small>{t("Véhicule", "Vehicle", "السيارة")}</small>{cur.year} · {cur.color} · {vehicleTypeLabel(cur.vehicle_type, lang)} · {cur.seats} {t("places", "seats", "مقاعد")} · {cur.vehicle_condition}</div>
            <div><small>{t("Services", "Services", "الخدمات")}</small>{svc(cur.services)}</div>
            <div><small>{t("Disponibilités / tarif", "Availability / price", "التوفر / السعر")}</small>{cur.availability} · {cur.desired_rate ? `${cur.desired_rate} €` : t("non communiqué", "not given", "غير محدد")}</div>
            <div className="form-wide"><small>{t("Description", "Description", "الوصف")}</small>{cur.description}</div>
            {cur.extra_info && <div className="form-wide"><small>{t("Infos complémentaires", "Additional info", "معلومات إضافية")}</small>{cur.extra_info}</div>}
            {cur.rejection_reason && <div className="form-wide"><small>{t("Motif de refus", "Reason for declining", "سبب الرفض")}</small>{cur.rejection_reason}</div>}
            {cur.info_request && <div className="form-wide"><small>{t("Compléments demandés", "Info requested", "المعلومات المطلوبة")}</small>{cur.info_request}</div>}
          </div>
          {cur.status !== "approved" && (
            <div className="action-row mt-4">
              <Button className="ref-btn" onClick={() => run(async () => { const r = await approve({ data: { id: cur.id, origin: window.location.origin } }); if (r.invited) toast.info(t("Invitation envoyée par e-mail au propriétaire", "Invitation emailed to the owner", "تم إرسال الدعوة إلى المالك عبر البريد")); }, t("Dossier accepté", "Application approved", "تم قبول الملف"), refresh)}>{t("Accepter", "Approve", "قبول")}</Button>
              <Button variant="outline" className="ref-btn" onClick={() => { const m = window.prompt(t("Motif du refus ?", "Reason for declining?", "سبب الرفض؟"))?.trim(); if (m) run(() => review({ data: { id: cur.id, action: "reject", message: m } }), t("Dossier refusé", "Application declined", "تم رفض الملف"), refresh); }}>{t("Refuser", "Decline", "رفض")}</Button>
              <Button variant="outline" className="ref-btn" onClick={() => { const m = window.prompt(t("Informations à demander ?", "What information do you need?", "ما المعلومات المطلوبة؟"))?.trim(); if (m) run(() => review({ data: { id: cur.id, action: "info", message: m } }), t("Demande envoyée", "Request sent", "تم إرسال الطلب"), refresh); }}>{t("Demander des compléments", "Request more info", "طلب معلومات إضافية")}</Button>
              <Button asChild variant="ghost" className="ref-btn"><a href={`mailto:${cur.email}?subject=Far7tek`}>{t("Contacter", "Contact", "تواصل")}</a></Button>
            </div>
          )}
          <h3 className="mt-6">{t("Notes internes", "Internal notes", "ملاحظات داخلية")}</h3>
          {notes.map((n) => <div key={n.id} className="note-row"><small>{dateTime(n.created_at)}</small><p>{n.note}</p></div>)}
          <form className="ref-form mt-3" onSubmit={async (e): Promise<void> => {
            e.preventDefault();
            const form = e.currentTarget;
            const note = String(new FormData(form).get("note") ?? "").trim().slice(0, 2000);
            if (!note) return;
            const { error } = await supabase.from("admin_notes").insert({ car_proposal_id: cur.id, note, author_id: (await supabase.auth.getUser()).data.user!.id });
            if (error) { toast.error(t("Note non enregistrée", "Note not saved", "لم تُحفظ الملاحظة")); return; }
            form.reset(); openDossier(cur.id);
          }}>
            <label className="form-field form-wide"><span>{t("Ajouter une note", "Add a note", "إضافة ملاحظة")}</span><textarea name="note" /></label>
            <Button className="ref-btn">{t("Enregistrer la note", "Save note", "حفظ الملاحظة")}</Button>
          </form>
        </div>
      )}
      <div className="registry">
        <Filters q={q} setQ={setQ} status={st} setStatus={setSt} statuses={{
          pending: PROPOSAL_STATUS["pending"]!, reviewing: PROPOSAL_STATUS["reviewing"]!, info_requested: PROPOSAL_STATUS["info_requested"]!,
          approved: ["Actifs", "Active", "نشط"], rejected: PROPOSAL_STATUS["rejected"]!,
        }} />
        <div className="table-scroll"><table className="registry-table">
          <thead><tr><th>{t("Propriétaire", "Owner", "المالك")}</th><th>{t("Téléphone", "Phone", "الهاتف")}</th><th>{t("Ville", "City", "المدينة")}</th><th>{t("Véhicule", "Vehicle", "السيارة")}</th><th>{t("Services", "Services", "الخدمات")}</th><th>{t("Soumis le", "Submitted", "تاريخ الإرسال")}</th><th>{t("Statut", "Status", "الحالة")}</th><th></th></tr></thead>
          <tbody>{rows.map((x) => (
            <tr key={x.id}>
              <td><strong>{x.first_name} {x.last_name}</strong></td><td dir="ltr">{x.phone}</td><td>{x.city}</td><td>{x.brand} {x.model}</td>
              <td>{svc(x.services)}</td><td>{date(x.created_at)}</td>
              <td><StatusPill label={labelOf(PROPOSAL_STATUS, x.status, lang)} /></td>
              <td><Button variant="outline" className="ref-btn" onClick={() => openDossier(x.id)}>{t("Consulter", "Open", "عرض")}</Button></td>
            </tr>
          ))}</tbody>
        </table>{!rows.length && <p className="admin-empty">{t("Aucun dossier.", "No applications.", "لا توجد ملفات.")}</p>}</div>
      </div>
    </>
  );
}

function Vehicles({ cars, changes, refresh }: Ctx) {
  const { t, lang } = useI18n();
  const setVal = useServerFn(setCarValidation);
  const reviewCh = useServerFn(reviewChangeRequest);
  const [st, setSt] = useState("");
  return (
    <>
      {changes.length > 0 && (
        <div className="registry"><h3 className="mb-3">{t("Modifications à valider", "Changes to approve", "تعديلات للموافقة")}</h3>
          {changes.map((c) => (
            <div key={c.id} className="note-row">
              <strong>{cars.find((x) => x.id === c.car_id)?.name}</strong>
              <p>{Object.entries(c.changes as Record<string, unknown>).map(([k, v]) => `${k} : ${v}`).join(" · ")}</p>
              <div className="action-row">
                <Button className="ref-btn" onClick={() => run(() => reviewCh({ data: { id: c.id, approve: true } }), t("Modification appliquée", "Change applied", "تم تطبيق التعديل"), refresh)}>{t("Valider", "Approve", "موافقة")}</Button>
                <Button variant="outline" className="ref-btn" onClick={() => run(() => reviewCh({ data: { id: c.id, approve: false } }), t("Modification refusée", "Change declined", "تم رفض التعديل"), refresh)}>{t("Refuser", "Decline", "رفض")}</Button>
              </div>
            </div>
          ))}
        </div>
      )}
      <div className="registry">
        <div className="filter-row">{["", "pending", "active", "disabled"].map((s) => <Button key={s || "all"} variant={st === s ? "default" : "outline"} className="filter-btn" onClick={() => setSt(s)}>{s ? labelOf(CAR_VALIDATION, s, lang) : t("Tous", "All", "الكل")}</Button>)}</div>
        <div className="table-scroll"><table className="registry-table">
          <thead><tr><th>{t("Véhicule", "Vehicle", "السيارة")}</th><th>{t("Ville", "City", "المدينة")}</th><th>{t("Places", "Seats", "المقاعد")}</th><th>{t("Propriétaire", "Owner", "المالك")}</th><th>{t("Statut", "Status", "الحالة")}</th><th></th></tr></thead>
          <tbody>{cars.filter((c) => !st || c.validation_status === st).map((c) => (
            <tr key={c.id}>
              <td><strong>{c.name}</strong><small>{vehicleTypeLabel(c.category, lang)}</small></td><td>{c.city}</td><td>{c.seats}</td><td>{c.owner_id ? t("Partenaire", "Partner", "شريك") : t("Flotte", "Fleet", "الأسطول")}</td>
              <td><StatusPill label={labelOf(CAR_VALIDATION, c.validation_status, lang)} /></td>
              <td><div className="action-row">
                {c.validation_status !== "active" && <Button className="ref-btn" onClick={() => run(() => setVal({ data: { carId: c.id, status: "active" } }), t("Véhicule publié", "Vehicle published", "تم نشر السيارة"), refresh)}>{t("Valider / publier", "Approve / publish", "موافقة / نشر")}</Button>}
                {c.validation_status !== "disabled" && <Button variant="outline" className="ref-btn" onClick={() => run(() => setVal({ data: { carId: c.id, status: "disabled" } }), t("Véhicule désactivé", "Vehicle disabled", "تم تعطيل السيارة"), refresh)}>{t("Désactiver", "Disable", "تعطيل")}</Button>}
              </div></td>
            </tr>
          ))}</tbody>
        </table></div>
      </div>
    </>
  );
}

function Assign({ bookings, assignments, partners, cars, refresh }: Ctx) {
  const { t, lang, date } = useI18n();
  const assign = useServerFn(assignTrip);
  const open = bookings.filter((b) => ["pending", "new", "contacted"].includes(b.status) && !assignments.some((a) => a.booking_request_id === b.id && a.status !== "rejected"));
  return (
    <div className="registry">
      {!open.length && <p className="admin-empty">{t("Aucune demande à attribuer.", "No requests to assign.", "لا توجد طلبات للإسناد.")}</p>}
      {open.map((b) => {
        const options = partners
          .map((x) => { const car = cars.find((c) => c.id === x.car_id); return { x, car, score: car ? matchScore(b, car) : 0 }; })
          .filter((o) => o.score >= 0)
          .sort((m, n) => n.score - m.score);
        return (
          <div key={b.id} className="note-row">
            <strong>{b.reference} — {serviceLabel(b.service_type, lang)}</strong>
            <p>{date(b.wedding_date)} {b.wedding_time.slice(0, 5)} · {b.city} · {b.passengers} {t("pass.", "pax", "راكب")} · {b.vehicle_type ? vehicleTypeLabel(b.vehicle_type, lang) : t("Sans préférence", "No preference", "بدون تفضيل")}</p>
            {assignments.filter((a) => a.booking_request_id === b.id && a.status === "rejected").map((a) => <small key={a.id} className="block">{t("Refusée précédemment", "Previously declined", "رُفض سابقاً")} : {a.rejection_reason}</small>)}
            <div className="action-row mt-2">
              {!options.length && <small>{t("Aucun partenaire compatible (places).", "No compatible partner (seats).", "لا يوجد شريك مناسب (المقاعد).")}</small>}
              {options.slice(0, 5).map(({ x, car, score }) => (
                <Button key={x.id} variant={score >= 3 ? "default" : "outline"} className="ref-btn"
                  onClick={() => run(() => assign({ data: { bookingId: b.id, partnerId: x.partner_user_id!, carId: car?.id ?? null } }), t("Demande attribuée", "Request assigned", "تم إسناد الطلب"), refresh)}>
                  {x.first_name} {x.last_name} · {car?.name ?? "—"} ({car?.city}) {score >= 3 ? `★ ${t("suggéré", "suggested", "مقترح")}` : ""}
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
  const { t, date } = useI18n();
  const today = new Date().toISOString().slice(0, 10);
  const groups = useMemo(() => [
    [t("À venir", "Upcoming", "القادمة"), bookings.filter((b) => ["accepted", "confirmed"].includes(b.status) && b.wedding_date >= today)],
    [t("En cours", "In progress", "الجارية"), bookings.filter((b) => b.status === "in_progress")],
    [t("Terminés", "Completed", "المنتهية"), bookings.filter((b) => b.status === "completed")],
    [t("Annulés", "Cancelled", "الملغاة"), bookings.filter((b) => b.status === "cancelled" || b.status === "rejected")],
  ] as const, [bookings, today, t]);
  return (
    <div className="admin-edit-grid">
      {groups.map(([g, rows]) => (
        <div key={g} className="registry"><h3 className="mb-3">{g} ({rows.length})</h3>
          {rows.map((b) => <div key={b.id} className="note-row"><strong>{b.reference}</strong> {date(b.wedding_date)} · {b.pickup_address} → {b.venue}<small className="block">{assignments.some((a) => a.booking_request_id === b.id && a.status === "accepted") ? t("Partenaire assigné", "Partner assigned", "تم تعيين شريك") : t("Sans partenaire", "No partner", "بدون شريك")}</small></div>)}
        </div>
      ))}
    </div>
  );
}

function Clients() {
  const { t, date } = useI18n();
  const fetchClients = useServerFn(listClients);
  const { data, isLoading, error } = useQuery({ queryKey: ["adm-clients"], queryFn: () => fetchClients() });
  const [q, setQ] = useState("");
  if (isLoading) return <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p>;
  if (error) return <p className="form-error">{t("Liste indisponible.", "List unavailable.", "القائمة غير متاحة.")}</p>;
  return (
    <div className="registry">
      <input className="admin-search mb-4" placeholder={t("Rechercher un e-mail", "Search an email", "ابحث عن بريد")} value={q} onChange={(e) => setQ(e.target.value)} />
      <div className="table-scroll"><table className="registry-table">
        <thead><tr><th>{t("E-mail", "Email", "البريد")}</th><th>{t("Rôles", "Roles", "الأدوار")}</th><th>{t("Demandes", "Requests", "الطلبات")}</th><th>{t("Inscrit le", "Joined", "تاريخ التسجيل")}</th><th>{t("Dernière connexion", "Last sign-in", "آخر دخول")}</th></tr></thead>
        <tbody>{(data ?? []).filter((u) => u.email.includes(q.toLowerCase())).map((u) => (
          <tr key={u.id}><td><a href={`mailto:${u.email}`}>{u.email}</a></td><td>{u.roles.join(", ") || t("client", "client", "عميل")}</td><td>{u.requests}</td><td>{date(u.created_at)}</td><td>{u.last_sign_in_at ? date(u.last_sign_in_at) : "—"}</td></tr>
        ))}</tbody>
      </table></div>
    </div>
  );
}

function Settings() {
  const { t, p } = useI18n();
  return (
    <div className="registry">
      <h3 className="mb-3">{t("Services et règles", "Services and rules", "الخدمات والقواعد")}</h3>
      {SERVICE_TYPES.map((s) => <div key={s.value} className="note-row">{p(s.label)}</div>)}
      <p className="mt-4">{t(
        "Attribution : manuelle, avec suggestion des partenaires selon la ville, le nombre de places, le type de véhicule et les services proposés. Un partenaire doit accepter la demande avant de voir le téléphone du client.",
        "Assignment: manual, with partner suggestions based on city, seats, vehicle type and services. A partner must accept the request before seeing the client's phone number.",
        "الإسناد: يدوي، مع اقتراح الشركاء حسب المدينة وعدد المقاعد ونوع السيارة والخدمات. يجب على الشريك قبول الطلب قبل رؤية هاتف العميل.",
      )}</p>
      <p className="mt-2">{t(
        "Notifications : internes au site. Les envois par e-mail ou SMS ne sont pas encore configurés (seule l’invitation partenaire part par e-mail).",
        "Notifications: in-app only. Email and SMS delivery are not set up yet (only the partner invitation is emailed).",
        "الإشعارات: داخلية فقط. لم يتم إعداد الإرسال عبر البريد أو الرسائل القصيرة بعد (فقط دعوة الشريك تُرسل بالبريد).",
      )}</p>
    </div>
  );
}
