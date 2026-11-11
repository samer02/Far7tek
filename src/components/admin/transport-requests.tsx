import { useMemo, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { ArrowLeft, ArrowRight, MessageCircle, Phone } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import type { Tables } from "@/integrations/supabase/types";
import { useAuth } from "@/lib/use-auth";
import { BOOKING_STATUS, CAR_CATEGORIES, carInCategory, HISTORY_STATUS } from "@/lib/platform";
import {
  ADMIN_TRANSITIONS, asStage, asStops, call, fmtWhen, TZ, tunisDay, tunisInstant, useLiveRefresh,
  type Booking, type JourneyEvent, type LatLng, type LiveLocation,
} from "@/lib/transport";
import { labelOf, pick, useI18n, type Tri } from "@/lib/i18n";
import { AvailabilityCalendar, useCarRules } from "@/components/transport/availability-calendar";
import { JourneyTimeline, LiveBadge, RequestStatus, StatusSteps } from "@/components/transport/journey";
import { RouteMap, toPoint } from "@/components/transport/route-map";

type Car = Tables<"cars">;
export type Owner = { id: string; first_name: string; last_name: string; phone: string | null; email: string };

export function useOwners() {
  return useQuery({ queryKey: ["adm-owners"], queryFn: () => call<Owner[]>(supabase.rpc("admin_list_owners")) });
}
export const ownerName = (o: Owner | undefined) => (o ? `${o.first_name} ${o.last_name}`.trim() || o.email : "—");
export const telHref = (phone: string) => `tel:${phone.replace(/[^+0-9]/g, "")}`;
export const waHref = (phone: string) => {
  const digits = phone.replace(/[^0-9]/g, "");
  return `https://wa.me/${digits.length === 8 ? `216${digits}` : digits}`;
};

const ACTION_LABEL: Record<string, Tri> = {
  under_review: ["Passer en étude", "Start review", "بدء المراجعة"],
  pending: ["Remettre en attente", "Back to pending", "إرجاع إلى الانتظار"],
  approved: ["Approuver", "Approve", "موافقة"],
  awaiting_owner: ["Demander la confirmation du propriétaire", "Ask owner to confirm", "طلب تأكيد المالك"],
  confirmed: ["Confirmer la réservation", "Confirm booking", "تأكيد الحجز"],
  rejected: ["Refuser", "Reject", "رفض"],
  cancelled: ["Annuler", "Cancel", "إلغاء"],
  completed: ["Clôturer comme terminé", "Close as completed", "إغلاق كمنتهية"],
};
const AVAIL_LABEL: Record<string, Tri> = {
  available: ["Disponible", "Available", "متاح"],
  unavailable: ["Indisponible selon le planning du propriétaire", "Unavailable per owner schedule", "غير متاح حسب جدول المالك"],
  booked: ["Déjà réservé sur ce créneau", "Already booked for this slot", "محجوز في هذا الموعد"],
  invalid: ["Créneau invalide", "Invalid slot", "موعد غير صالح"],
  unknown: ["Inconnu", "Unknown", "غير معروف"],
};
const timeFmt = new Intl.DateTimeFormat("en-GB", { timeZone: TZ, hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
const localInput = (iso: string | null) => (iso ? `${tunisDay(iso)}T${timeFmt.format(new Date(iso))}` : "");

export function TransportRequests({ bookings, cars, refresh, initialOpen = null }: { bookings: Booking[]; cars: Car[]; refresh: () => void; initialOpen?: string | null }) {
  const { t, p, lang, date } = useI18n();
  const { data: owners = [] } = useOwners();
  const [openId, setOpenId] = useState<string | null>(initialOpen);
  const [q, setQ] = useState("");
  const [st, setSt] = useState("");
  const [cat, setCat] = useState("");
  const [sort, setSort] = useState<"created" | "date">("created");
  useLiveRefresh("adm-requests", [{ table: "booking_requests" }], refresh, true, 45_000);

  const owner = (id: string | null) => owners.find((o) => o.id === id);
  const rows = bookings
    .filter((b) => (!st || b.status === st) && (!cat || b.category === cat))
    .filter((b) => !q || `${b.reference} ${b.first_name} ${b.last_name} ${b.city} ${b.phone} ${b.car_name} ${ownerName(owner(b.owner_id))}`.toLowerCase().includes(q.toLowerCase()))
    .sort((a, b) => (sort === "date" ? a.wedding_date.localeCompare(b.wedding_date) : b.created_at.localeCompare(a.created_at)));

  const opened = bookings.find((b) => b.id === openId);
  if (opened) return <RequestAdminDetail b={opened} cars={cars} owners={owners} onBack={() => setOpenId(null)} refresh={refresh} />;

  return (
    <div className="registry">
      <div className="flex flex-wrap gap-3 mb-4">
        <input className="admin-search" placeholder={t("Rechercher (réf., client, propriétaire, ville…)", "Search (ref., client, owner, city…)", "بحث (المرجع، العميل، المالك، المدينة…)")} value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="admin-select" value={st} onChange={(e) => setSt(e.target.value)} aria-label={t("Statut", "Status", "الحالة")}>
          <option value="">{t("Tous les statuts", "All statuses", "كل الحالات")}</option>
          {Object.entries(BOOKING_STATUS).filter(([k]) => !["new", "contacted", "accepted"].includes(k)).map(([k, v]) => <option key={k} value={k}>{p(v)} ({bookings.filter((b) => b.status === k).length})</option>)}
        </select>
        <select className="admin-select" value={cat} onChange={(e) => setCat(e.target.value)} aria-label={t("Catégorie", "Category", "الفئة")}>
          <option value="">{t("Toutes catégories", "All categories", "كل الفئات")}</option>
          {CAR_CATEGORIES.map((c) => <option key={c.value} value={c.value}>{p(c.label)}</option>)}
        </select>
        <select className="admin-select" value={sort} onChange={(e) => setSort(e.target.value as "created" | "date")}>
          <option value="created">{t("Plus récentes", "Most recent", "الأحدث")}</option>
          <option value="date">{t("Date du service", "Service date", "تاريخ الخدمة")}</option>
        </select>
      </div>
      <div className="table-scroll"><table className="registry-table">
        <thead><tr>
          <th>{t("Réf.", "Ref.", "مرجع")}</th><th>{t("Client", "Client", "العميل")}</th><th>{t("Véhicule", "Vehicle", "السيارة")}</th>
          <th>{t("Propriétaire", "Owner", "المالك")}</th><th>{t("Date", "Date", "التاريخ")}</th><th>{t("Trajet", "Route", "المسار")}</th><th>{t("Statut", "Status", "الحالة")}</th><th></th>
        </tr></thead>
        <tbody>{rows.map((b) => {
          const o = owner(b.owner_id);
          const c = CAR_CATEGORIES.find((x) => x.value === b.category);
          return (
            <tr key={b.id}>
              <td><strong>{b.reference}</strong><small>{date(b.created_at)}</small></td>
              <td><strong>{b.first_name} {b.last_name}</strong><small><a href={telHref(b.phone)} dir="ltr">{b.phone}</a></small></td>
              <td>{b.car_name}<small>{c ? p(c.short) : "—"} · {b.passengers} {t("pass.", "pax", "راكب")}</small></td>
              <td>{o ? <><strong>{ownerName(o)}</strong>{o.phone ? <small><a href={telHref(o.phone)} dir="ltr">{o.phone}</a></small> : <small>{t("Pas de téléphone", "No phone", "لا يوجد هاتف")}</small>}</> : <small>{t("Non attribué", "Not assigned", "غير مسند")}</small>}</td>
              <td>{date(b.wedding_date)}<small>{b.wedding_time.slice(0, 5)}{b.return_time ? ` / ${b.return_time.slice(0, 5)}` : ""}</small></td>
              <td>{b.pickup_address}<small>→ {b.venue}{asStops(b.stops).length ? ` · ${asStops(b.stops).length} ${t("arrêt(s)", "stop(s)", "توقف")}` : ""}</small></td>
              <td><RequestStatus status={b.status} /></td>
              <td><Button variant="outline" className="ref-btn" onClick={() => setOpenId(b.id)}>{t("Ouvrir", "Open", "فتح")}</Button></td>
            </tr>
          );
        })}</tbody>
      </table>{!rows.length && <p className="admin-empty">{t("Aucune demande.", "No requests.", "لا توجد طلبات.")}</p>}</div>
      <p className="mt-3 text-sm">{labelOf(BOOKING_STATUS, "pending", lang)} : {bookings.filter((b) => ["pending", "new"].includes(b.status)).length}</p>
    </div>
  );
}

function RequestAdminDetail({ b, cars, owners, onBack, refresh }: { b: Booking; cars: Car[]; owners: Owner[]; onBack: () => void; refresh: () => void }) {
  const { t, p, lang, locale, date, dateTime, dir } = useI18n();
  const { data: auth } = useAuth();
  const qc = useQueryClient();
  const Back = dir === "rtl" ? ArrowRight : ArrowLeft;
  const [note, setNote] = useState("");
  const [override, setOverride] = useState(false);
  const [busy, setBusy] = useState(false);
  const [carId, setCarId] = useState(b.car_id ?? "");
  const [ownerId, setOwnerId] = useState(b.owner_id ?? "");
  const [start, setStart] = useState(localInput(b.service_start_at));
  const [end, setEnd] = useState(localInput(b.service_end_at));
  const [internal, setInternal] = useState("");
  const car = cars.find((c) => c.id === b.car_id);
  const owner = owners.find((o) => o.id === b.owner_id);
  const tracked = ["in_progress", "completed"].includes(b.status);

  const { data: avail } = useQuery({
    queryKey: ["adm-window", b.id, b.car_id, b.service_start_at, b.service_end_at, b.status],
    enabled: !!b.car_id && !!b.service_start_at && !!b.service_end_at,
    queryFn: () => call<string>(supabase.rpc("car_window_status", { _car: b.car_id!, _start: b.service_start_at!, _end: b.service_end_at!, _ignore: b.id })),
  });
  const { data: rules = [] } = useCarRules(b.car_id);
  const { data: detail, refetch } = useQuery({
    queryKey: ["adm-request-detail", b.id],
    queryFn: async () => {
      const [stages, events, history, notes, live, track] = await Promise.all([
        call<Tables<"journey_stages">[]>(supabase.from("journey_stages").select("*").eq("booking_request_id", b.id).order("stage_no")),
        call<JourneyEvent[]>(supabase.from("journey_events").select("*").eq("booking_request_id", b.id).order("created_at")),
        call<Tables<"trip_status_history">[]>(supabase.from("trip_status_history").select("*").eq("booking_request_id", b.id).order("created_at")),
        call<Tables<"admin_notes">[]>(supabase.from("admin_notes").select("*").eq("booking_request_id", b.id).order("created_at")),
        call<LiveLocation | null>(supabase.from("live_locations").select("*").eq("booking_request_id", b.id).maybeSingle()),
        tracked ? call<{ lat: number; lng: number }[]>(supabase.from("gps_location_updates").select("lat,lng").eq("booking_request_id", b.id).order("recorded_at").limit(3000)) : Promise.resolve([]),
      ]);
      return { stages: stages.map(asStage), events, history, notes, live, track: track as LatLng[] };
    },
  });
  useLiveRefresh(`adm-request-${b.id}`, [
    { table: "journey_stages", filter: `booking_request_id=eq.${b.id}` },
    { table: "live_locations", filter: `booking_request_id=eq.${b.id}` },
    { table: "journey_events", filter: `booking_request_id=eq.${b.id}` },
  ], () => void refetch(), true, b.status === "in_progress" ? 10_000 : 60_000);

  const after = () => { refresh(); void refetch(); qc.invalidateQueries({ queryKey: ["adm-window", b.id] }); qc.invalidateQueries({ queryKey: ["car-calendar"] }); };
  async function act(fn: () => PromiseLike<unknown>, msg: string) {
    if (busy) return;
    setBusy(true);
    try { await fn(); toast.success(msg); after(); return true; } catch (e) { toast.error((e as Error).message); return false; } finally { setBusy(false); }
  }

  async function setStatus(s: string) {
    if (s === "rejected" && !note.trim()) { toast.error(t("Indiquez le motif du refus dans le message.", "Enter the rejection reason in the message.", "أدخل سبب الرفض في الرسالة.")); return; }
    if (["cancelled", "rejected", "completed"].includes(s) && !window.confirm(`${p(ACTION_LABEL[s]!)} ${b.reference} ?`)) return;
    const ok = await act(() => call(supabase.rpc("admin_transport_set_status", { _id: b.id, _status: s, _note: note.trim(), _override: override })), t("Statut mis à jour", "Status updated", "تم تحديث الحالة"));
    if (ok) { setNote(""); setOverride(false); }
  }
  const logContact = (target: "owner" | "client") => { void supabase.rpc("admin_transport_log_contact", { _id: b.id, _target: target }).then(() => void refetch()); };

  const carOptions = cars.filter((c) => c.id === b.car_id || (c.active && (!b.category || carInCategory(c.services, b.category as "wedding" | "family"))));
  const transitions = ADMIN_TRANSITIONS[b.status] ?? [];
  const history = useMemo(() => [
    ...(detail?.history ?? []).map((h) => ({ at: h.created_at, label: labelOf(HISTORY_STATUS, h.status, lang), note: h.note })),
    ...(detail?.events ?? []).map((e) => ({ at: e.created_at, label: `${t("Trajet", "Journey", "الرحلة")} · ${e.event_type.replace(/_/g, " ")} (${e.actor_role})`, note: e.note })),
  ].sort((x, y) => x.at.localeCompare(y.at)), [detail, lang, t]);
  const stops = asStops(b.stops);
  const runningStops = detail?.stages.find((s) => s.status === "in_progress")?.stops;

  return (
    <div className="req-admin">
      <button type="button" className="tile-link !mt-0 mb-4" onClick={onBack}><Back className="h-4 w-4" />{t("Toutes les demandes", "All requests", "كل الطلبات")}</button>
      <div className="dossier">
        <div className="car-meta"><span>{b.reference} · {t("reçue le", "received", "استُلم في")} {dateTime(b.created_at)}</span><RequestStatus status={b.status} /></div>
        <h2 className="text-2xl">{b.first_name} {b.last_name} · {b.car_name}</h2>
        <StatusSteps status={b.status} />
        {b.status === "approved" && <p className="note-row">{t("Approuvée : l’opération ne démarrera que lorsque le propriétaire lancera la Partie 1.", "Approved: the operation only starts when the owner starts Part 1.", "تمت الموافقة: لن تبدأ العملية إلا عندما يبدأ المالك الجزء الأول.")}</p>}
      </div>

      <div className="req-admin-grid">
        <div>
          <div className="dossier">
            <h3 className="mb-3">{t("Décision", "Decision", "القرار")}</h3>
            {avail && (
              <p className={`avail-note is-${avail}`}>{t("Disponibilité du véhicule", "Vehicle availability", "توفر السيارة")} : <strong>{p(AVAIL_LABEL[avail] ?? AVAIL_LABEL["unknown"]!)}</strong></p>
            )}
            {!b.car_id && <p className="avail-note is-unavailable">{t("Attribuez un véhicule et son propriétaire avant d’approuver.", "Assign a vehicle and its owner before approving.", "أسند سيارة ومالكها قبل الموافقة.")}</p>}
            <label className="form-field mt-3"><span>{t("Message au client (obligatoire pour un refus)", "Message to the client (required to reject)", "رسالة للعميل (إلزامية عند الرفض)")}</span>
              <textarea value={note} maxLength={500} onChange={(e) => setNote(e.target.value)} />
            </label>
            {avail === "unavailable" && (
              <label className="check-label mt-3"><input type="checkbox" checked={override} onChange={(e) => setOverride(e.target.checked)} />{t("Forcer : le propriétaire a confirmé par téléphone", "Override: owner confirmed by phone", "تجاوز: أكد المالك هاتفياً")}</label>
            )}
            <div className="action-row mt-4">
              {transitions.map((s) => (
                <Button key={s} disabled={busy} variant={["approved", "confirmed", "completed"].includes(s) ? "default" : s === "rejected" || s === "cancelled" ? "outline" : "secondary"} className={`ref-btn ${["approved", "confirmed"].includes(s) ? "bg-primary" : ""}`} onClick={() => void setStatus(s)}>
                  {p(ACTION_LABEL[s] ?? [s, s, s])}
                </Button>
              ))}
              {!transitions.length && <small>{t("Aucune action possible sur ce statut.", "No action available for this status.", "لا يوجد إجراء متاح لهذه الحالة.")}</small>}
            </div>
          </div>

          <div className="dossier">
            <h3 className="mb-3">{t("Contacts", "Contacts", "جهات الاتصال")}</h3>
            <div className="contact-row">
              <div><small>{t("Propriétaire", "Owner", "المالك")}</small><strong>{ownerName(owner)}</strong>{owner?.email && <small dir="ltr">{owner.email}</small>}</div>
              {owner?.phone ? (
                <div className="action-row">
                  <a className="ref-btn inline-flex items-center gap-2 border border-border" href={telHref(owner.phone)} onClick={() => logContact("owner")} dir="ltr"><Phone className="h-4 w-4" />{owner.phone}</a>
                  <a className="ref-btn inline-flex items-center gap-2 border border-border" href={waHref(owner.phone)} target="_blank" rel="noreferrer" onClick={() => logContact("owner")}><MessageCircle className="h-4 w-4" />WhatsApp</a>
                </div>
              ) : <small>{owner ? t("Aucun téléphone dans le profil du propriétaire", "No phone in the owner's profile", "لا يوجد هاتف في ملف المالك") : t("Aucun propriétaire attribué", "No owner assigned", "لم يتم إسناد مالك")}</small>}
            </div>
            <div className="contact-row">
              <div><small>{t("Client", "Client", "العميل")}</small><strong>{b.first_name} {b.last_name}</strong><small dir="ltr">{b.email}</small>{b.contact_extra && <small>{t("Autre contact", "Other contact", "جهة اتصال أخرى")} : {b.contact_extra}</small>}</div>
              <div className="action-row">
                <a className="ref-btn inline-flex items-center gap-2 border border-border" href={telHref(b.phone)} onClick={() => logContact("client")} dir="ltr"><Phone className="h-4 w-4" />{b.phone}</a>
                <a className="ref-btn inline-flex items-center gap-2 border border-border" href={waHref(b.phone)} target="_blank" rel="noreferrer" onClick={() => logContact("client")}><MessageCircle className="h-4 w-4" />WhatsApp</a>
              </div>
            </div>
          </div>

          <div className="dossier">
            <h3 className="mb-3">{t("Véhicule et propriétaire", "Vehicle and owner", "السيارة والمالك")}</h3>
            <div className="ref-form">
              <label className="form-field"><span>{t("Véhicule", "Vehicle", "السيارة")}</span>
                <select value={carId} onChange={(e) => { setCarId(e.target.value); const c = cars.find((x) => x.id === e.target.value); if (c?.owner_id) setOwnerId(c.owner_id); }}>
                  <option value="">—</option>
                  {carOptions.map((c) => <option key={c.id} value={c.id}>{c.name}{c.seats ? ` · ${c.seats} pl.` : ""}{c.city ? ` · ${c.city}` : ""}</option>)}
                </select>
              </label>
              <label className="form-field"><span>{t("Propriétaire", "Owner", "المالك")}</span>
                <select value={ownerId} onChange={(e) => setOwnerId(e.target.value)}>
                  <option value="">{t("Propriétaire du véhicule", "Vehicle's owner", "مالك السيارة")}</option>
                  {owners.map((o) => <option key={o.id} value={o.id}>{ownerName(o)}{o.phone ? ` · ${o.phone}` : ""}</option>)}
                </select>
              </label>
              <Button className="ref-btn" disabled={busy || !carId || (carId === b.car_id && ownerId === (b.owner_id ?? ""))}
                onClick={() => void act(() => call(supabase.rpc("admin_transport_assign", { _id: b.id, _car: carId, _owner: ownerId || null })), t("Attribution enregistrée", "Assignment saved", "تم حفظ الإسناد"))}>
                {t("Enregistrer l’attribution", "Save assignment", "حفظ الإسناد")}
              </Button>
            </div>
            <h4 className="mt-6 mb-2 font-semibold">{t("Créneau réservé (heure de Tunisie)", "Reserved slot (Tunisia time)", "الموعد المحجوز (توقيت تونس)")}</h4>
            <div className="ref-form">
              <label className="form-field"><span>{t("Début", "Start", "البداية")}</span><input type="datetime-local" value={start} onChange={(e) => setStart(e.target.value)} /></label>
              <label className="form-field"><span>{t("Fin", "End", "النهاية")}</span><input type="datetime-local" value={end} onChange={(e) => setEnd(e.target.value)} /></label>
              <Button className="ref-btn" disabled={busy || !start || !end || (start === localInput(b.service_start_at) && end === localInput(b.service_end_at))}
                onClick={() => void act(() => call(supabase.rpc("admin_transport_set_window", { _id: b.id, _start: tunisInstant(start.slice(0, 10), start.slice(11, 16)), _end: tunisInstant(end.slice(0, 10), end.slice(11, 16)) })), t("Créneau mis à jour", "Slot updated", "تم تحديث الموعد"))}>
                {t("Mettre à jour le créneau", "Update slot", "تحديث الموعد")}
              </Button>
            </div>
            {car && (
              <div className="mt-6">
                <h4 className="mb-2 font-semibold">{t("Calendrier de", "Calendar of", "تقويم")} {car.name}</h4>
                <AvailabilityCalendar carId={car.id} mode={car.availability_mode} rules={rules} highlight={[b.wedding_date]} />
              </div>
            )}
          </div>
        </div>

        <div>
          <div className="dossier">
            <h3 className="mb-3">{t("Détails de la demande", "Request details", "تفاصيل الطلب")}</h3>
            <div className="dossier-grid !mt-0">
              <div><small>{t("Catégorie", "Category", "الفئة")}</small>{(() => { const c = CAR_CATEGORIES.find((x) => x.value === b.category); return c ? pick(c.label, lang) : "—"; })()}</div>
              <div><small>{t("Date", "Date", "التاريخ")}</small>{date(b.wedding_date)} · {b.wedding_time.slice(0, 5)}{b.return_time ? ` / ${t("retour", "return", "العودة")} ${b.return_time.slice(0, 5)}` : ""}</div>
              <div><small>{t("Créneau", "Slot", "الموعد")}</small>{fmtWhen(b.service_start_at, locale)} → {fmtWhen(b.service_end_at, locale)}</div>
              <div><small>{t("Passagers", "Passengers", "الركاب")}</small>{b.passengers}</div>
              <div className="form-wide"><small>{t("Départ", "Pick-up", "الانطلاق")}</small>{b.pickup_address}</div>
              {stops.map((s, i) => <div key={i} className="form-wide"><small>{t("Arrêt", "Stop", "توقف")} {i + 1}</small>{s.address}</div>)}
              <div className="form-wide"><small>{t("Destination", "Destination", "الوجهة")}</small>{b.venue} ({b.city})</div>
              {b.message && <div className="form-wide"><small>{t("Besoins", "Requirements", "المتطلبات")}</small>{b.message}</div>}
              {b.client_notes && <div className="form-wide"><small>{t("Note du client pour l’équipe", "Client note for the team", "ملاحظة العميل للفريق")}</small>{b.client_notes}</div>}
              {b.decision_note && <div className="form-wide"><small>{t("Message de décision", "Decision message", "رسالة القرار")}</small>{b.decision_note}</div>}
            </div>
            {b.status === "in_progress" && <div className="mt-4"><LiveBadge live={detail?.live} /></div>}
            <div className="mt-4">
              <RouteMap pickup={toPoint(b.pickup_lat, b.pickup_lng)} destination={toPoint(b.destination_lat, b.destination_lng)} stops={runningStops ?? stops}
                live={detail?.live ?? null} track={detail?.track ?? []} height={360} />
            </div>
          </div>
          <div className="dossier">
            <h3 className="mb-3">{t("Étapes du trajet", "Journey stages", "مراحل الرحلة")}</h3>
            <JourneyTimeline stages={detail?.stages ?? []} events={detail?.events ?? []} showCoords />
          </div>
          <div className="dossier">
            <h3 className="mb-1">{t("Notes internes", "Internal notes", "ملاحظات داخلية")}</h3>
            {(detail?.notes ?? []).map((n) => <div key={n.id} className="note-row"><small>{dateTime(n.created_at)}</small> {n.note}</div>)}
            <form className="flex gap-2 mt-3" onSubmit={(e) => {
              e.preventDefault();
              const v = internal.trim();
              if (!v || !auth?.userId) return;
              void act(() => call(supabase.from("admin_notes").insert({ booking_request_id: b.id, author_id: auth.userId!, note: v.slice(0, 2000) })), t("Note ajoutée", "Note added", "تمت إضافة الملاحظة")).then((ok) => ok && setInternal(""));
            }}>
              <input className="admin-search flex-1" value={internal} onChange={(e) => setInternal(e.target.value)} placeholder={t("Visible uniquement par l’administration", "Visible to admins only", "مرئية للإدارة فقط")} />
              <Button className="ref-btn" disabled={busy || !internal.trim()}>{t("Ajouter", "Add", "إضافة")}</Button>
            </form>
          </div>
          <div className="dossier">
            <h3 className="mb-1">{t("Historique complet", "Full history", "السجل الكامل")}</h3>
            {history.map((h, i) => <div key={i} className="note-row"><small>{dateTime(h.at)}</small> {h.label}{h.note ? ` — ${h.note}` : ""}</div>)}
          </div>
        </div>
      </div>
    </div>
  );
}
