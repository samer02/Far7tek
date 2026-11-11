import { Check, Flag, MapPin, Navigation, Radio, Satellite, SatelliteDish } from "lucide-react";
import { StatusPill } from "@/components/site-chrome";
import { BOOKING_STATUS, STAGE_STATUS, statusTone } from "@/lib/platform";
import { fmtClock, fmtCoords, fmtWhen, liveState, type JourneyEvent, type LiveLocation, type Stage } from "@/lib/transport";
import { labelOf, useI18n } from "@/lib/i18n";

export function RequestStatus({ status }: { status: string }) {
  const { lang } = useI18n();
  return <StatusPill label={labelOf(BOOKING_STATUS, status, lang)} tone={statusTone(status)} />;
}

const STEPS = ["pending", "under_review", "approved", "confirmed", "in_progress", "completed"] as const;
const STEP_INDEX: Record<string, number> = { new: 0, pending: 0, contacted: 1, under_review: 1, approved: 2, awaiting_owner: 2, accepted: 2, confirmed: 3, in_progress: 4, completed: 5 };

/** Where a request stands in the approval → journey pipeline. */
export function StatusSteps({ status }: { status: string }) {
  const { lang } = useI18n();
  if (status === "rejected" || status === "cancelled") return <div className="status-steps is-closed"><RequestStatus status={status} /></div>;
  const at = STEP_INDEX[status] ?? 0;
  return (
    <ol className="status-steps">
      {STEPS.map((s, i) => (
        <li key={s} data-state={i < at ? "done" : i === at ? "current" : "todo"}>
          <span className="dot">{i < at ? <Check /> : i + 1}</span>
          <span className="txt">{labelOf(BOOKING_STATUS, i === at && status === "awaiting_owner" ? "awaiting_owner" : s, lang)}</span>
        </li>
      ))}
    </ol>
  );
}

export function LiveBadge({ live, compact = false }: { live: LiveLocation | null | undefined; compact?: boolean }) {
  const { t, locale } = useI18n();
  const s = liveState(live);
  if (s === "none") return <span className="live-badge" data-state="none"><SatelliteDish />{t("Pas de position GPS", "No GPS position", "لا يوجد موقع GPS")}</span>;
  const when = fmtClock(live!.received_at ?? live!.recorded_at, locale);
  if (s === "live") return <span className="live-badge" data-state="live"><Radio />{t("GPS en direct", "Live GPS", "GPS مباشر")}{!compact && ` · ${when}`}</span>;
  if (s === "stale") return <span className="live-badge" data-state="stale"><Satellite />{t("Signal perdu · dernière position", "Signal lost · last known", "انقطع الإشارة · آخر موقع")} {when}</span>;
  return <span className="live-badge" data-state="paused"><Satellite />{t("Suivi arrêté · dernière position", "Tracking stopped · last known", "التتبع متوقف · آخر موقع")} {when}</span>;
}

const EVENT_LABEL: Record<string, readonly [string, string, string]> = {
  stage_started: ["Départ", "Started", "انطلاق"],
  stage_ended: ["Arrivée", "Arrived", "وصول"],
  stop_reached: ["Arrêt atteint", "Stop reached", "تم الوصول إلى التوقف"],
  arrival_confirmed: ["Arrivée confirmée par le client", "Arrival confirmed by client", "أكد العميل الوصول"],
  completion_requested: ["Fin demandée par le client", "Client asked to finish", "طلب العميل الإنهاء"],
  operation_completed: ["Opération terminée", "Operation completed", "انتهت العملية"],
  operation_cancelled: ["Opération annulée", "Operation cancelled", "أُلغيت العملية"],
};

/** Part 1 / Part 2 … with planned route, actual times, GPS points and stops. */
export function JourneyTimeline({ stages, events = [], showCoords = false }: { stages: Stage[]; events?: JourneyEvent[]; showCoords?: boolean }) {
  const { t, p, lang, locale } = useI18n();
  if (!stages.length) return <p className="admin-empty">{t("Aucune étape planifiée.", "No stages planned.", "لا توجد مراحل مخططة.")}</p>;
  return (
    <ol className="journey">
      {stages.map((s) => {
        const evs = events.filter((e) => e.stage_id === s.id && !["stage_started", "stage_ended"].includes(e.event_type));
        const done = s.stops.filter((x) => x.reached_at).length;
        return (
          <li key={s.id} className="journey-stage" data-status={s.status}>
            <div className="journey-head">
              <span className="journey-no">{s.status === "completed" ? <Check /> : s.status === "in_progress" ? <Navigation /> : s.stage_no}</span>
              <div>
                <strong>{t("Partie", "Part", "الجزء")} {s.stage_no}{s.label ? ` · ${s.label === "Aller" ? t("Aller", "Outbound", "ذهاب") : s.label === "Retour" ? t("Retour", "Return", "عودة") : s.label}` : ""}</strong>
                <small>{t("Prévu", "Planned", "مخطط")} {fmtWhen(s.scheduled_at, locale)}</small>
              </div>
              <StatusPill label={labelOf(STAGE_STATUS, s.status, lang)} tone={s.status === "in_progress" ? "live" : s.status === "completed" ? "success" : s.status === "pending" ? "neutral" : "danger"} />
            </div>
            <div className="journey-route">
              <div><MapPin /><span>{s.from_address}</span></div>
              {s.stops.map((x, i) => (
                <div key={i} className={x.reached_at ? "is-done" : ""}>
                  <span className="journey-stop">{i + 1}</span>
                  <span>{x.address}{x.reached_at && <small> · {t("atteint", "reached", "تم الوصول")} {fmtWhen(x.reached_at, locale, false)}</small>}</span>
                </div>
              ))}
              <div><Flag /><span>{s.to_address}</span></div>
            </div>
            {(s.started_at || s.ended_at) && (
              <div className="journey-facts">
                <div><small>{t("Départ réel", "Actual start", "الانطلاق الفعلي")}</small>{fmtWhen(s.started_at, locale)}{showCoords && <em dir="ltr">{fmtCoords(s.start_lat, s.start_lng)}</em>}</div>
                <div><small>{t("Arrivée réelle", "Actual arrival", "الوصول الفعلي")}</small>{fmtWhen(s.ended_at, locale)}{showCoords && <em dir="ltr">{fmtCoords(s.end_lat, s.end_lng)}</em>}</div>
                {s.stops.length > 0 && <div><small>{t("Arrêts", "Stops", "التوقفات")}</small>{done} / {s.stops.length}</div>}
              </div>
            )}
            {s.notes && <p className="journey-note">{s.notes}</p>}
            {evs.length > 0 && (
              <ul className="journey-events">
                {evs.map((e) => <li key={e.id}><small>{fmtWhen(e.created_at, locale)}</small> {EVENT_LABEL[e.event_type] ? p(EVENT_LABEL[e.event_type]!) : e.event_type}</li>)}
              </ul>
            )}
          </li>
        );
      })}
    </ol>
  );
}
