import { createFileRoute } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { signedUrls } from "@/lib/cars";
import { fmtPrice, BOOKING_STATUS, PROPOSAL_STATUS, CAR_VALIDATION, SERVICE_TYPES, CAR_CATEGORIES, partnerServiceLabel, vehicleTypeLabel } from "@/lib/platform";
import { approvePartner, listClients, reviewChangeRequest, reviewPartner, setCarValidation } from "@/lib/admin.functions";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";
import { TransportRequests, useOwners, ownerName, telHref, waHref } from "@/components/admin/transport-requests";
import { LiveOperations } from "@/components/admin/live-operations";
import { CarCatalog } from "@/components/admin/car-catalog";
import { labelOf, pick, useI18n, type Tri } from "@/lib/i18n";

export const Route = createFileRoute("/_authenticated/admin")({
  head: () => ({ meta: [{ title: "Administration — Far7tek" }, { name: "robots", content: "noindex" }] }),
  component: Admin,
});

type Section = "overview" | "requests" | "live" | "catalog" | "partners" | "vehicles" | "clients" | "notifications" | "settings";
const SECTIONS: [Section, Tri][] = [
  ["overview", ["Vue générale", "Overview", "نظرة عامة"]],
  ["requests", ["Demandes de transport", "Transport requests", "طلبات النقل"]],
  ["live", ["Opérations en direct", "Live operations", "العمليات المباشرة"]],
  ["catalog", ["Catalogue", "Catalog", "الكتالوج"]],
  ["partners", ["Partenaires", "Partners", "الشركاء"]],
  ["vehicles", ["Validation véhicules", "Vehicle approvals", "اعتماد السيارات"]],
  ["clients", ["Clients", "Clients", "العملاء"]],
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
  const [openRequest, setOpenRequest] = useState<string | null>(null);
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
          {SECTIONS.map(([k, l]) => <Button key={k} variant={k === section ? "default" : "ghost"} className="ref-btn" onClick={() => { setOpenRequest(null); setSection(k); }}>{p(l)}</Button>)}
        </div>
        {section === "overview" && <Overview {...ctx} onOpen={(id) => { setOpenRequest(id); setSection("requests"); }} />}
        {section === "requests" && <TransportRequests key={openRequest ?? "list"} bookings={d.bookings} cars={d.cars} refresh={refresh} initialOpen={openRequest} />}
        {section === "live" && <LiveOperations bookings={d.bookings} onOpen={(id) => { setOpenRequest(id); setSection("requests"); }} />}
        {section === "catalog" && <CarCatalog cars={d.cars} bookings={d.bookings} refresh={refresh} />}
        {section === "partners" && <Partners {...ctx} />}
        {section === "vehicles" && <Vehicles {...ctx} />}
        {section === "clients" && <Clients />}
        {section === "notifications" && <NotificationsPanel admin />}
        {section === "settings" && <Settings />}
      </div>
    </section>
  );
}

type Ctx = ReturnType<typeof useAdminData> & { partners: ReturnType<typeof useAdminData>["proposals"]; refresh: () => void };

function Overview({ bookings, proposals, cars, onOpen }: Ctx & { onOpen: (id: string) => void }) {
  const { t, lang, date } = useI18n();
  const k = [
    [t("Demandes en attente", "Pending requests", "طلبات قيد الانتظار"), bookings.filter((b) => ["pending", "new", "under_review"].includes(b.status)).length],
    [t("À confirmer par le propriétaire", "Awaiting owner", "بانتظار تأكيد المالك"), bookings.filter((b) => ["approved", "awaiting_owner"].includes(b.status)).length],
    [t("Réservations confirmées", "Confirmed bookings", "حجوزات مؤكدة"), bookings.filter((b) => b.status === "confirmed").length],
    [t("Opérations en cours", "Active operations", "عمليات جارية"), bookings.filter((b) => b.status === "in_progress").length],
    [t("Dossiers partenaires à traiter", "Partner applications to review", "ملفات شركاء للمعالجة"), proposals.filter((x) => ["pending", "new", "reviewing", "info_requested"].includes(x.status)).length],
    [t("Véhicules publiés", "Published vehicles", "سيارات منشورة"), cars.filter((c) => c.active).length],
  ] as const;
  const cat = (v: string | null) => { const c = CAR_CATEGORIES.find((x) => x.value === v); return c ? pick(c.short, lang) : "—"; };
  return (
    <>
      <div className="kpi-grid">{k.map(([l, v]) => <div key={l} className="kpi"><div className="kpi-label">{l}</div><div className="kpi-value">{v}</div></div>)}</div>
      <div className="registry"><h3 className="mb-3">{t("Dernières demandes", "Latest requests", "أحدث الطلبات")}</h3>
        {bookings.slice(0, 8).map((b) => (
          <button key={b.id} type="button" className="note-row block w-full text-start" onClick={() => onOpen(b.id)}>
            <small>{date(b.created_at)}</small> {b.reference} — {b.first_name} {b.last_name} · {cat(b.category)} · {date(b.wedding_date)} · <strong>{labelOf(BOOKING_STATUS, b.status, lang)}</strong>
          </button>
        ))}
        {!bookings.length && <p className="admin-empty">{t("Aucune activité pour le moment.", "No activity yet.", "لا يوجد نشاط حالياً.")}</p>}
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

function Partners({ proposals, cars, refresh }: Ctx) {
  const { t, lang, date, dateTime } = useI18n();
  const approve = useServerFn(approvePartner);
  const review = useServerFn(reviewPartner);
  const { data: owners = [] } = useOwners();
  const [subTab, setSubTab] = useState<"owners" | "proposals">("owners");
  const [q, setQ] = useState("");
  const [st, setSt] = useState("");
  const [open, setOpen] = useState<string | null>(null);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<{ id: string; note: string; created_at: string }[]>([]);

  const filteredOwners = owners.filter((o) => {
    if (!q) return true;
    const myCars = cars.filter((c) => c.owner_id === o.id).map((c) => c.name).join(" ");
    return `${o.first_name} ${o.last_name} ${o.email} ${o.phone ?? ""} ${myCars}`.toLowerCase().includes(q.toLowerCase());
  });

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
      <div className="registry-tabs mb-6">
        <Button variant={subTab === "owners" ? "default" : "ghost"} className="ref-btn" onClick={() => { setOpen(null); setSubTab("owners"); }}>
          {t("Partenaires actifs", "Active partners", "الشركاء النشطون")} ({owners.length})
        </Button>
        <Button variant={subTab === "proposals" ? "default" : "ghost"} className="ref-btn" onClick={() => { setOpen(null); setSubTab("proposals"); }}>
          {t("Candidatures & dossiers", "Applications & proposals", "الملفات والطلبات")} ({proposals.length})
        </Button>
      </div>

      {subTab === "owners" && (
        <div className="registry">
          <div className="flex flex-wrap gap-3 mb-4 items-center">
            <input
              className="admin-search flex-1"
              placeholder={t("Rechercher un partenaire (nom, e-mail, téléphone, voiture…)", "Search partner (name, email, phone, car…)", "بحث عن شريك (الاسم، البريد، الهاتف، السيارة…)")}
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
          </div>

          <div className="table-scroll">
            <table className="registry-table">
              <thead>
                <tr>
                  <th>{t("Partenaire", "Partner", "الشريك")}</th>
                  <th>{t("Contact", "Contact", "الاتصال")}</th>
                  <th>{t("Voitures attribuées", "Assigned vehicles", "السيارات المخصصة")}</th>
                  <th>{t("Statut", "Status", "الحالة")}</th>
                </tr>
              </thead>
              <tbody>
                {filteredOwners.map((o) => {
                  const myCars = cars.filter((c) => c.owner_id === o.id);
                  return (
                    <tr key={o.id}>
                      <td>
                        <strong className="block text-base">{o.first_name} {o.last_name}</strong>
                        {o.email && <small className="text-muted-foreground block font-mono">{o.email}</small>}
                      </td>
                      <td>
                        {o.phone ? (
                          <div className="flex flex-col gap-1 text-sm">
                            <a href={telHref(o.phone)} dir="ltr" className="font-semibold text-primary">{o.phone}</a>
                            <a href={waHref(o.phone)} target="_blank" rel="noreferrer" className="text-xs text-muted-foreground hover:text-foreground">WhatsApp ↗</a>
                          </div>
                        ) : (
                          <span className="text-muted-foreground">—</span>
                        )}
                      </td>
                      <td>
                        <div className="flex items-center gap-2 mb-1.5">
                          <span className="px-2 py-0.5 rounded-full text-xs font-semibold bg-primary/10 text-primary">
                            {myCars.length} {t("véhicules", "vehicles", "سيارات")}
                          </span>
                        </div>
                        <div className="flex flex-wrap gap-1 max-w-lg">
                          {myCars.map((c) => (
                            <span key={c.id} className="text-xs py-0.5 px-1.5 rounded bg-muted text-foreground border border-border">
                              {c.name}
                            </span>
                          ))}
                          {!myCars.length && <span className="text-xs text-muted-foreground">{t("Aucune voiture", "No cars", "لا توجد سيارات")}</span>}
                        </div>
                      </td>
                      <td>
                        <span className="px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-600 border border-emerald-500/20">
                          {t("Actif", "Active", "نشط")}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            {!filteredOwners.length && (
              <p className="admin-empty">
                {t("Aucun partenaire trouvé.", "No partner found.", "لم يتم العثور على أي شريك.")}
              </p>
            )}
          </div>
        </div>
      )}

      {subTab === "proposals" && (
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
                <div><small>{t("Véhicule", "Vehicle", "السيارة")}</small>{cur.year} · {cur.color} · {cur.vehicle_type ? `${vehicleTypeLabel(cur.vehicle_type, lang)} · ` : ""}{cur.seats} {t("places", "seats", "مقاعد")} · {cur.vehicle_condition}</div>
                <div><small>{t("Services", "Services", "الخدمات")}</small>{svc(cur.services)}</div>
                <div><small>{t("Disponibilités / tarif", "Availability / price", "التوفر / السعر")}</small>{cur.availability} · {cur.desired_rate ? fmtPrice(cur.desired_rate, lang) : t("non communiqué", "not given", "غير محدد")}</div>
                <div className="form-wide"><small>{t("Description", "Description", "الوصف")}</small>{cur.description}</div>
                {cur.extra_info && <div className="form-wide"><small>{t("Infos complémentaires", "Additional info", "معلومات إضافية")}</small>{cur.extra_info}</div>}
                {cur.rejection_reason && <div className="form-wide"><small>{t("Motif de refus", "Reason for declining", "سبب الرفض")}</small>{cur.rejection_reason}</div>}
                {cur.info_request && <div className="form-wide"><small>{t("Compléments demandés", "Info requested", "المعلومات المطلوبة")}</small>{cur.info_request}</div>}
              </div>
              {cur.status !== "approved" && (
                <div className="action-row mt-4">
                  <Button className="ref-btn" onClick={() => run(async () => { try { const r = await approve({ data: { id: cur.id, origin: window.location.origin } }); if (r.invited) toast.info(t("Invitation envoyée par e-mail au propriétaire", "Invitation emailed to the owner", "تم إرسال الدعوة إلى المالك عبر البريد")); } catch { const { error } = await supabase.rpc("admin_approve_partner", { _id: cur.id }); if (error) throw error; } }, t("Dossier accepté", "Application approved", "تم قبول الملف"), refresh)}>{t("Accepter", "Approve", "قبول")}</Button>
                  <Button variant="outline" className="ref-btn" onClick={() => { const m = window.prompt(t("Motif du refus ?", "Reason for declining?", "سبب الرفض؟"))?.trim(); if (m) run(async () => { try { await review({ data: { id: cur.id, action: "reject", message: m } }); } catch { const { error } = await supabase.rpc("admin_review_partner", { _id: cur.id, _action: "reject", _message: m }); if (error) throw error; } }, t("Dossier refusé", "Application declined", "تم رفض الملف"), refresh); }}>{t("Refuser", "Decline", "رفض")}</Button>
                  <Button variant="outline" className="ref-btn" onClick={() => { const m = window.prompt(t("Informations à demander ?", "What information do you need?", "ما المعلومات المطلوبة؟"))?.trim(); if (m) run(async () => { try { await review({ data: { id: cur.id, action: "info", message: m } }); } catch { const { error } = await supabase.rpc("admin_review_partner", { _id: cur.id, _action: "info", _message: m }); if (error) throw error; } }, t("Demande envoyée", "Request sent", "تم إرسال الطلب"), refresh); }}>{t("Demander des compléments", "Request more info", "طلب معلومات إضافية")}</Button>
                  <Button asChild variant="ghost" className="ref-btn"><a href={`mailto:${cur.email}?subject=Far7tek`}>{t("Contacter", "Contact", "تواصل")}</a></Button>
                </div>
              )}
              <h3 className="mt-6">{t("Notes internes", "Internal notes", "ملاحظats داخلية")}</h3>
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
      )}
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
                <Button className="ref-btn" onClick={() => run(async () => { try { await reviewCh({ data: { id: c.id, approve: true } }); } catch { const { error } = await supabase.rpc("admin_review_change_request", { _id: c.id, _approve: true }); if (error) throw error; } }, t("Modification appliquée", "Change applied", "تم تطبيق التعديل"), refresh)}>{t("Valider", "Approve", "موافقة")}</Button>
                <Button variant="outline" className="ref-btn" onClick={() => run(async () => { try { await reviewCh({ data: { id: c.id, approve: false } }); } catch { const { error } = await supabase.rpc("admin_review_change_request", { _id: c.id, _approve: false }); if (error) throw error; } }, t("Modification refusée", "Change declined", "تم رفض التعديل"), refresh)}>{t("Refuser", "Decline", "رفض")}</Button>
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
                {c.validation_status !== "active" && <Button className="ref-btn" onClick={() => run(async () => { try { await setVal({ data: { carId: c.id, status: "active" } }); } catch { const { error } = await supabase.rpc("admin_set_car_validation", { _car: c.id, _status: "active" }); if (error) throw error; } }, t("Véhicule publié", "Vehicle published", "تم نشر السيارة"), refresh)}>{t("Valider / publier", "Approve / publish", "موافقة / نشر")}</Button>}
                {c.validation_status !== "disabled" && <Button variant="outline" className="ref-btn" onClick={() => run(async () => { try { await setVal({ data: { carId: c.id, status: "disabled" } }); } catch { const { error } = await supabase.rpc("admin_set_car_validation", { _car: c.id, _status: "disabled" }); if (error) throw error; } }, t("Véhicule désactivé", "Vehicle disabled", "تم تعطيل السيارة"), refresh)}>{t("Désactiver", "Disable", "تعطيل")}</Button>}
              </div></td>
            </tr>
          ))}</tbody>
        </table></div>
      </div>
    </>
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
        "Validation : chaque demande est étudiée puis approuvée par l’administration, qui vérifie la disponibilité du véhicule. Le téléphone du propriétaire n’est jamais visible du client ; celui du client n’est transmis au propriétaire qu’après confirmation. Le suivi GPS ne démarre que lorsque le propriétaire lance une étape et s’arrête à la fin.",
        "Approval: every request is reviewed and approved by the admin team, which checks vehicle availability. The owner's phone is never shown to clients; the client's phone is only shared with the owner once confirmed. GPS tracking starts only when the owner starts a stage and stops when it ends.",
        "الموافقة: تتم مراجعة كل طلب والموافقة عليه من الإدارة بعد التحقق من توفر السيارة. لا يظهر هاتف المالك للعميل أبداً، ولا يُرسل هاتف العميل إلى المالك إلا بعد التأكيد. يبدأ تتبع GPS فقط عندما يبدأ المالك مرحلة ويتوقف عند نهايتها.",
      )}</p>
      <p className="mt-2">{t(
        "Notifications : internes au site. Les envois par e-mail ou SMS ne sont pas encore configurés (seule l’invitation partenaire part par e-mail).",
        "Notifications: in-app only. Email and SMS delivery are not set up yet (only the partner invitation is emailed).",
        "الإشعارات: داخلية فقط. لم يتم إعداد الإرسال عبر البريد أو الرسائل القصيرة بعد (فقط دعوة الشريك تُرسل بالبريد).",
      )}</p>
    </div>
  );
}
