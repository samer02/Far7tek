import { useState } from "react";
import { toast } from "sonner";
import { Flag, MapPinCheck, Play, Radio, ShieldAlert, WifiOff } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { call, fmtClock, fmtWhen, type OwnerOperation, type Stage } from "@/lib/transport";
import { currentPosition, useGpsTracker } from "@/lib/use-gps-tracker";
import { useI18n } from "@/lib/i18n";

const stageName = (s: Stage, t: (fr: string, en: string, ar: string) => string) => `${t("Partie", "Part", "الجزء")} ${s.stage_no}`;

/** Start / end controls for the owner's operation. Only the action valid right now is shown. */
export function JourneyControls({ op, onChanged }: { op: OwnerOperation; onChanged: () => void }) {
  const { t, locale } = useI18n();
  const [busy, setBusy] = useState<string | null>(null);
  const active = op.stages.find((s) => s.status === "in_progress") ?? null;
  const next = active ? null : op.stages.find((s) => s.status === "pending" && op.stages.every((o) => o.stage_no >= s.stage_no || ["completed", "skipped"].includes(o.status))) ?? null;
  const canRun = ["confirmed", "in_progress"].includes(op.status);
  const gps = useGpsTracker(op.id, op.status === "in_progress" && !!active, onChanged);

  async function act(key: string, fn: () => Promise<{ already?: boolean } | void>, ok: string) {
    if (busy) return;
    setBusy(key);
    try {
      const r = await fn();
      if (r && r.already) toast.info(t("Déjà enregistré", "Already recorded", "مسجل مسبقاً"));
      else toast.success(ok);
      onChanged();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function withPosition(askNoGps: boolean) {
    const pos = await currentPosition();
    if (!pos && askNoGps && !window.confirm(t(
      "Position GPS refusée ou indisponible. Continuer sans coordonnées ? L’administration ne pourra pas suivre le véhicule.",
      "GPS position denied or unavailable. Continue without coordinates? The admin team won't be able to follow the vehicle.",
      "تم رفض الموقع أو غير متاح. المتابعة بدون إحداثيات؟ لن تتمكن الإدارة من تتبع السيارة.",
    ))) return undefined;
    return { _lat: pos?.coords.latitude ?? null, _lng: pos?.coords.longitude ?? null, _accuracy: pos?.coords.accuracy ?? null };
  }

  const start = (s: Stage) => act(`start-${s.id}`, async () => {
    const c = await withPosition(true);
    if (!c) throw new Error(t("Départ annulé", "Start cancelled", "تم إلغاء الانطلاق"));
    return call<{ already: boolean }>(supabase.rpc("journey_start_stage", { _stage: s.id, ...c }));
  }, `${stageName(s, t)} ${t("démarrée", "started", "بدأت")}`);

  const end = (s: Stage) => {
    if (!window.confirm(t(`Confirmer l’arrivée : ${s.to_address} ?`, `Confirm arrival: ${s.to_address}?`, `تأكيد الوصول: ${s.to_address}؟`))) return;
    void act(`end-${s.id}`, async () => {
      const c = await withPosition(false);
      return call<{ already: boolean }>(supabase.rpc("journey_end_stage", { _stage: s.id, ...c! }));
    }, `${stageName(s, t)} ${t("terminée", "completed", "انتهت")}`);
  };

  const reachStop = (s: Stage, i: number) => act(`stop-${s.id}-${i}`, async () => {
    const pos = await currentPosition(8_000);
    return call<{ already: boolean }>(supabase.rpc("journey_mark_stop", { _stage: s.id, _index: i, _lat: pos?.coords.latitude ?? null, _lng: pos?.coords.longitude ?? null }));
  }, t("Arrêt enregistré", "Stop recorded", "تم تسجيل التوقف"));

  if (!canRun) return null;
  if (!active && !next) return null;

  return (
    <div className="journey-controls">
      {active ? (
        <>
          <div className={`tracking-banner ${gps.status === "live" ? "is-live" : gps.status === "offline" || gps.status === "error" ? "is-warn" : ""}`} role="status" aria-live="polite">
            {gps.status === "offline" ? <WifiOff /> : gps.status === "error" ? <ShieldAlert /> : <Radio />}
            <div>
              <strong>
                {gps.status === "live" ? t("Suivi GPS actif — position partagée avec l’administration", "Live GPS on — sharing your position with the admin team", "تتبع GPS نشط — يتم مشاركة موقعك مع الإدارة")
                  : gps.status === "offline" ? t("Connexion perdue — nouvel essai automatique", "Connection lost — retrying automatically", "انقطع الاتصال — إعادة المحاولة تلقائياً")
                  : gps.status === "error" ? (gps.permission === "denied" ? t("Accès GPS refusé — autorisez la localisation dans le navigateur", "GPS access denied — allow location in your browser", "تم رفض GPS — اسمح بتحديد الموقع في المتصفح") : t("Pas de signal GPS", "No GPS signal", "لا توجد إشارة GPS"))
                  : t("Recherche du signal GPS…", "Acquiring GPS…", "جارٍ البحث عن إشارة GPS…")}
              </strong>
              <small>
                {gps.lastSentAt ? `${t("Dernier envoi", "Last sent", "آخر إرسال")} ${fmtClock(new Date(gps.lastSentAt).toISOString(), locale)}` : t("Aucune position envoyée pour l’instant", "No position sent yet", "لم يتم إرسال أي موقع بعد")}
                {gps.fix && ` · ±${Math.round(gps.fix.accuracy)} m`}
                {gps.lastReason === "inaccurate" && ` · ${t("précision insuffisante", "low accuracy", "دقة منخفضة")}`}
              </small>
              <small>{t("Gardez cette page ouverte pendant le trajet. Le suivi s’arrête automatiquement à l’arrivée.", "Keep this page open while driving. Tracking stops automatically on arrival.", "أبقِ هذه الصفحة مفتوحة أثناء الرحلة. يتوقف التتبع تلقائياً عند الوصول.")}</small>
            </div>
          </div>
          <div className="journey-now">
            <small>{stageName(active, t)} · {t("en cours depuis", "running since", "جارية منذ")} {fmtWhen(active.started_at, locale, false)}</small>
            <strong>{active.to_address}</strong>
          </div>
          {active.stops.map((x, i) => !x.reached_at && (
            <Button key={i} variant="outline" className="journey-btn" disabled={!!busy} onClick={() => void reachStop(active, i)}>
              <MapPinCheck />{t("Arrivé à l’arrêt", "Reached stop", "وصلت إلى التوقف")} {i + 1} · {x.address}
            </Button>
          ))}
          <Button className="journey-btn journey-btn-end" disabled={!!busy} onClick={() => end(active)}>
            <Flag />{busy === `end-${active.id}` ? t("Enregistrement…", "Saving…", "جارٍ الحفظ…") : `${t("Terminer la", "End", "إنهاء")} ${stageName(active, t)}`}
          </Button>
        </>
      ) : next && (
        <>
          <div className="journey-now">
            <small>{t("Prochaine étape", "Next stage", "المرحلة التالية")} · {t("prévue", "planned", "مخطط")} {fmtWhen(next.scheduled_at, locale)}</small>
            <strong>{next.from_address}</strong>
            <span>→ {next.to_address}</span>
            {op.car && <span>{op.car.name}</span>}
          </div>
          <Button className="journey-btn journey-btn-start" disabled={!!busy} onClick={() => void start(next)}>
            <Play />{busy === `start-${next.id}` ? t("Localisation…", "Getting location…", "جارٍ تحديد الموقع…") : `${t("Démarrer la", "Start", "بدء")} ${stageName(next, t)}`}
          </Button>
          <small className="journey-hint">{t(
            "Le navigateur va demander l’accès à votre position. Le suivi en direct ne démarre qu’à cet instant et s’arrête à la fin de l’étape.",
            "Your browser will ask for your location. Live tracking starts only now and stops at the end of the stage.",
            "سيطلب المتصفح الوصول إلى موقعك. يبدأ التتبع المباشر الآن فقط ويتوقف في نهاية المرحلة.",
          )}</small>
        </>
      )}
    </div>
  );
}
