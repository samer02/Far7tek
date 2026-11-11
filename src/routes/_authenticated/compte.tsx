import { useState } from "react";
import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { CheckCheck, Flag, XCircle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { fetchCars } from "@/lib/cars";
import { BOOKING_STATUS, CAR_CATEGORIES, HISTORY_STATUS } from "@/lib/platform";
import { asStage, asStops, call, CLIENT_CANCELLABLE, fmtWhen, useLiveRefresh, type Booking, type JourneyEvent, type LiveLocation } from "@/lib/transport";
import { labelOf, pick, useI18n } from "@/lib/i18n";
import { NotificationsPanel } from "@/components/notifications-panel";
import { JourneyTimeline, LiveBadge, RequestStatus, StatusSteps } from "@/components/transport/journey";
import { RouteMap, toPoint } from "@/components/transport/route-map";

export const Route = createFileRoute("/_authenticated/compte")({
  validateSearch: (s: Record<string, unknown>): { r?: string } => (typeof s["r"] === "string" ? { r: s["r"] } : {}),
  head: () => ({ meta: [{ title: "Mes demandes de transport — Far7tek" }, { name: "robots", content: "noindex" }] }),
  component: Account,
});

type History = { status: string; note: string | null; created_at: string };
type MyRequest = Booking & { trip_status_history: History[] };
/** History entries about internal coordination stay with the team. */
const CLIENT_HISTORY = new Set([...Object.keys(BOOKING_STATUS), "schedule_updated"]);

function Account() {
  const { t, lang, date } = useI18n();
  const { data: auth } = useAuth();
  const { r } = Route.useSearch();
  const navigate = Route.useNavigate();
  const qc = useQueryClient();
  const { data: cars } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const { data, isLoading } = useQuery({
    queryKey: ["my-requests", auth?.userId],
    enabled: !!auth?.userId,
    queryFn: () => call<MyRequest[]>(supabase
      .from("booking_requests")
      .select("*, trip_status_history(status,note,created_at)")
      .eq("client_id", auth!.userId!)
      .order("created_at", { ascending: false })),
  });
  useLiveRefresh("client-requests", [{ table: "booking_requests", filter: `client_id=eq.${auth?.userId}` }], () => qc.invalidateQueries({ queryKey: ["my-requests"] }), !!auth?.userId, 30_000);

  const list = data ?? [];
  const selected = list.find((x) => x.id === r) ?? list[0] ?? null;
  const carName = (b: Booking) => cars?.find((c) => c.id === b.car_id)?.name ?? (b.car_name && b.car_name !== "Sans préférence" ? b.car_name : t("Véhicule à attribuer", "Vehicle to be assigned", "سيارة سيتم تحديدها"));
  const catLabel = (b: Booking) => { const c = CAR_CATEGORIES.find((x) => x.value === b.category); return c ? pick(c.label, lang) : ""; };

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header">
          <div>
            <span className="eyebrow">{t("Espace client", "Client area", "فضاء العميل")}</span>
            <h1>{t("Mes demandes de transport", "My transportation requests", "طلبات النقل الخاصة بي")}</h1>
            <p dir="ltr" className="text-start">{auth?.email}</p>
          </div>
          <div className="admin-actions"><Button asChild className="ref-btn bg-primary"><Link to="/reserver">{t("Nouvelle demande", "New request", "طلب جديد")}</Link></Button></div>
        </div>
        {isLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : !list.length ? (
          <div className="registry admin-empty">{t("Aucune demande pour le moment.", "No requests yet.", "لا توجد طلبات حالياً.")}</div>
        ) : (
          <div className="split-panel">
            <nav className="req-list" aria-label={t("Mes demandes", "My requests", "طلباتي")}>
              {list.map((b) => (
                <button key={b.id} type="button" className={`req-item ${selected?.id === b.id ? "is-active" : ""}`} onClick={() => void navigate({ search: { r: b.id }, replace: true })}>
                  <span className="req-item-top"><strong>{b.reference}</strong><RequestStatus status={b.status} /></span>
                  <span>{carName(b)}</span>
                  <small>{catLabel(b)} · {date(b.wedding_date)} · {b.wedding_time.slice(0, 5)}</small>
                </button>
              ))}
            </nav>
            {selected && <RequestDetail key={selected.id} b={selected} carName={carName(selected)} catLabel={catLabel(selected)} />}
          </div>
        )}
        <div className="mt-10"><NotificationsPanel /></div>
      </div>
    </section>
  );
}

function RequestDetail({ b, carName, catLabel }: { b: MyRequest; carName: string; catLabel: string }) {
  const { t, lang, locale, date, dateTime } = useI18n();
  const qc = useQueryClient();
  const [busy, setBusy] = useState(false);
  const active = b.status === "in_progress";
  const { data: journey, refetch } = useQuery({
    queryKey: ["my-journey", b.id],
    queryFn: async () => {
      const [stages, events, live] = await Promise.all([
        call<Parameters<typeof asStage>[0][]>(supabase.from("journey_stages").select("*").eq("booking_request_id", b.id).order("stage_no")),
        call<JourneyEvent[]>(supabase.from("journey_events").select("*").eq("booking_request_id", b.id).order("created_at")),
        active ? call<LiveLocation | null>(supabase.from("live_locations").select("*").eq("booking_request_id", b.id).maybeSingle()) : Promise.resolve(null),
      ]);
      return { stages: stages.map(asStage), events, live };
    },
  });
  useLiveRefresh(`client-journey-${b.id}`, [
    { table: "journey_stages", filter: `booking_request_id=eq.${b.id}` },
    { table: "live_locations", filter: `booking_request_id=eq.${b.id}` },
  ], () => void refetch(), ["confirmed", "in_progress"].includes(b.status), active ? 15_000 : 60_000);

  const stages = journey?.stages ?? [];
  const running = stages.find((s) => s.status === "in_progress");
  const signals = new Set((journey?.events ?? []).filter((e) => e.stage_id === running?.id).map((e) => e.event_type));
  const history = [...b.trip_status_history].filter((h) => CLIENT_HISTORY.has(h.status)).sort((a, c) => a.created_at.localeCompare(c.created_at));

  async function cancel() {
    const reason = window.prompt(t("Motif de l’annulation (facultatif)", "Reason for cancelling (optional)", "سبب الإلغاء (اختياري)"));
    if (reason === null) return;
    setBusy(true);
    try {
      await call(supabase.rpc("transport_client_cancel", { _id: b.id, _reason: reason }));
      toast.success(t("Demande annulée", "Request cancelled", "تم إلغاء الطلب"));
      qc.invalidateQueries({ queryKey: ["my-requests"] });
    } catch (e) { toast.error((e as Error).message); } finally { setBusy(false); }
  }

  async function signal(kind: "arrival_confirmed" | "completion_requested") {
    if (!running) return;
    setBusy(true);
    try {
      const res = await call<{ already?: boolean }>(supabase.rpc("journey_client_signal", { _stage: running.id, _kind: kind }));
      toast.success(res?.already ? t("Déjà signalé", "Already sent", "تم الإرسال مسبقاً") : t("Merci, l’équipe est informée", "Thanks, the team has been notified", "شكراً، تم إبلاغ الفريق"));
      void refetch();
    } catch (e) { toast.error((e as Error).message); } finally { setBusy(false); }
  }

  return (
    <article className="dossier req-detail">
      <div className="car-meta"><span>{t("Réf.", "Ref.", "مرجع")} {b.reference} · {catLabel}</span><RequestStatus status={b.status} /></div>
      <h2 className="text-2xl">{carName}</h2>
      <StatusSteps status={b.status} />
      {b.status === "rejected" && b.decision_note && <p className="note-row">{t("Motif", "Reason", "السبب")} : {b.decision_note}</p>}
      <div className="dossier-grid">
        <div><small>{t("Date", "Date", "التاريخ")}</small>{date(b.wedding_date)}</div>
        <div><small>{t("Départ", "Departure", "الانطلاق")}</small>{b.wedding_time.slice(0, 5)}{b.return_time ? ` · ${t("retour", "return", "العودة")} ${b.return_time.slice(0, 5)}` : ""}</div>
        <div><small>{t("Passagers", "Passengers", "الركاب")}</small>{b.passengers}</div>
        <div><small>{t("Trajet", "Trip", "الرحلة")}</small>{b.trip_type === "round_trip" ? t("Aller-retour", "Round trip", "ذهاب وإياب") : t("Aller simple", "One way", "ذهاب فقط")}</div>
        <div className="form-wide"><small>{t("Itinéraire", "Route", "المسار")}</small>{b.pickup_address} → {asStops(b.stops).map((s) => `${s.address} → `).join("")}{b.venue}</div>
        {b.message && <div className="form-wide"><small>{t("Besoins", "Requirements", "المتطلبات")}</small>{b.message}</div>}
      </div>

      {active && running && (
        <div className="live-strip">
          <LiveBadge live={journey?.live} />
          <span>{t("En route vers", "On the way to", "في الطريق إلى")} <strong>{running.to_address}</strong> · {t("depuis", "since", "منذ")} {fmtWhen(running.started_at, locale, false)}</span>
        </div>
      )}
      <div className="mt-5">
        <RouteMap pickup={toPoint(b.pickup_lat, b.pickup_lng)} destination={toPoint(b.destination_lat, b.destination_lng)} stops={running?.stops ?? asStops(b.stops)} live={active ? journey?.live ?? null : null} height={320} />
      </div>
      {active && running && (
        <div className="action-row mt-4">
          <Button variant="outline" className="ref-btn" disabled={busy || signals.has("arrival_confirmed")} onClick={() => void signal("arrival_confirmed")}>
            <CheckCheck className="h-4 w-4" />{signals.has("arrival_confirmed") ? t("Arrivée confirmée", "Arrival confirmed", "تم تأكيد الوصول") : t("Je confirme être arrivé(e)", "I confirm I have arrived", "أؤكد وصولي")}
          </Button>
          <Button variant="outline" className="ref-btn" disabled={busy || signals.has("completion_requested")} onClick={() => void signal("completion_requested")}>
            <Flag className="h-4 w-4" />{signals.has("completion_requested") ? t("Fin demandée", "Completion requested", "تم طلب الإنهاء") : t("Demander la fin du trajet", "Ask to end the trip", "طلب إنهاء الرحلة")}
          </Button>
        </div>
      )}

      <h3 className="mt-8 mb-3">{t("Déroulement du trajet", "Journey", "مراحل الرحلة")}</h3>
      <JourneyTimeline stages={stages} events={journey?.events ?? []} />

      <h3 className="mt-8 mb-1">{t("Historique", "History", "السجل")}</h3>
      {history.map((h, i) => (
        <div key={i} className="note-row"><small>{dateTime(h.created_at)}</small> {labelOf(HISTORY_STATUS, h.status, lang)} {h.note && `— ${h.note}`}</div>
      ))}

      {CLIENT_CANCELLABLE.includes(b.status) && (
        <Button variant="ghost" className="ref-btn mt-6 text-destructive" disabled={busy} onClick={() => void cancel()}>
          <XCircle className="h-4 w-4" />{t("Annuler ma demande", "Cancel my request", "إلغاء طلبي")}
        </Button>
      )}
    </article>
  );
}
