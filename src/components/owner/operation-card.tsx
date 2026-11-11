import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import { Phone } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { CAR_CATEGORIES } from "@/lib/platform";
import { call, fmtWhen, type LiveLocation, type OwnerOperation } from "@/lib/transport";
import { useI18n } from "@/lib/i18n";
import { JourneyControls } from "@/components/transport/journey-controls";
import { JourneyTimeline, LiveBadge, RequestStatus } from "@/components/transport/journey";
import { RouteMap, toPoint } from "@/components/transport/route-map";

export function OperationCard({ op, onChanged }: { op: OwnerOperation; onChanged: () => void }) {
  const { t, p, locale, date } = useI18n();
  const [open, setOpen] = useState(op.status === "in_progress");
  const [busy, setBusy] = useState(false);
  const cat = CAR_CATEGORIES.find((c) => c.value === op.category);
  const active = op.status === "in_progress";
  const { data: live } = useQuery({
    queryKey: ["owner-live", op.id],
    enabled: active && open,
    refetchInterval: 15_000,
    queryFn: () => call<LiveLocation | null>(supabase.from("live_locations").select("*").eq("booking_request_id", op.id).maybeSingle()),
  });

  async function respond(accept: boolean) {
    let reason = "";
    if (!accept) {
      reason = window.prompt(t("Motif du refus ?", "Reason for declining?", "سبب الرفض؟"))?.trim() ?? "";
      if (!reason) return;
    }
    setBusy(true);
    try {
      await call(supabase.rpc("owner_respond_booking", { _id: op.id, _accept: accept, _reason: reason }));
      toast.success(accept ? t("Réservation confirmée", "Booking confirmed", "تم تأكيد الحجز") : t("Refus transmis à l’équipe", "Decline sent to the team", "تم إرسال الرفض إلى الفريق"));
      onChanged();
    } catch (e) { toast.error((e as Error).message); } finally { setBusy(false); }
  }

  return (
    <article className="op-card" data-status={op.status}>
      <div className="car-meta"><span>{t("Réf.", "Ref.", "مرجع")} {op.reference}{cat ? ` · ${p(cat.short)}` : ""}</span><RequestStatus status={op.status} /></div>
      <h3>{op.car?.name ?? t("Véhicule", "Vehicle", "السيارة")}</h3>
      <p className="op-when">
        {date(op.wedding_date)} · {op.wedding_time.slice(0, 5)}
        {op.return_time ? ` · ${t("retour", "return", "العودة")} ${op.return_time.slice(0, 5)}` : ""}
        {op.service_end_at && <small> ({t("créneau jusqu’à", "slot until", "الموعد حتى")} {fmtWhen(op.service_end_at, locale, false)})</small>}
      </p>
      <ul className="op-route">
        <li><b>A</b>{op.pickup_address}</li>
        {op.stops.map((s, i) => <li key={i}><b className="is-stop">{i + 1}</b>{s.address}</li>)}
        <li><b className="is-dest">B</b>{op.venue}{op.city ? ` (${op.city})` : ""}</li>
      </ul>
      <p className="op-facts">
        {op.passengers} {t("passager(s)", "passenger(s)", "راكب")} · {op.trip_type === "round_trip" ? t("Aller-retour", "Round trip", "ذهاب وإياب") : t("Aller simple", "One way", "ذهاب فقط")}
        {op.requirements && <><br />{t("Besoins", "Requirements", "المتطلبات")} : {op.requirements}</>}
      </p>
      <div className="op-client">
        <span>{t("Client", "Client", "العميل")} : <strong>{op.client_name}</strong></span>
        {op.client_phone
          ? <a href={`tel:${op.client_phone.replace(/[^+0-9]/g, "")}`} className="ref-btn inline-flex items-center gap-2 border border-border" dir="ltr"><Phone className="h-4 w-4" />{op.client_phone}</a>
          : <small>{t("Le téléphone du client s’affiche une fois la réservation confirmée.", "The client's phone appears once the booking is confirmed.", "يظهر هاتف العميل بعد تأكيد الحجز.")}</small>}
        {op.contact_extra && <small>{t("Autre contact", "Other contact", "جهة اتصال أخرى")} : {op.contact_extra}</small>}
      </div>

      {["approved", "awaiting_owner"].includes(op.status) && (
        <div className="action-row mt-4">
          <Button className="ref-btn bg-primary" disabled={busy} onClick={() => void respond(true)}>{t("Confirmer la disponibilité", "Confirm availability", "تأكيد التوفر")}</Button>
          <Button variant="outline" className="ref-btn" disabled={busy} onClick={() => void respond(false)}>{t("Je ne suis pas disponible", "I'm not available", "لست متاحاً")}</Button>
        </div>
      )}
      {["confirmed", "in_progress"].includes(op.status) && <div className="mt-4"><JourneyControls op={op} onChanged={onChanged} /></div>}

      <button type="button" className="tile-link" onClick={() => setOpen((o) => !o)} aria-expanded={open}>
        {open ? t("Masquer l’itinéraire", "Hide route", "إخفاء المسار") : t("Itinéraire et étapes", "Route and stages", "المسار والمراحل")}
      </button>
      {open && (
        <div className="mt-4 grid gap-4">
          {active && <LiveBadge live={live} />}
          <RouteMap pickup={toPoint(op.pickup_lat, op.pickup_lng)} destination={toPoint(op.destination_lat, op.destination_lng)} stops={op.stages.find((s) => s.status === "in_progress")?.stops ?? op.stops} live={active ? live ?? null : null} height={280} />
          <JourneyTimeline stages={op.stages} showCoords />
        </div>
      )}
    </article>
  );
}
