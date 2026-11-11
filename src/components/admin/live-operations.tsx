import { useEffect, useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { MessageCircle, Phone } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import type { Tables } from "@/integrations/supabase/types";
import { asStage, call, fmtClock, fmtCoords, fmtWhen, liveState, tunisDay, useLiveRefresh, type Booking, type LatLng, type LiveLocation, type Stage } from "@/lib/transport";
import { useI18n } from "@/lib/i18n";
import { OsmMap, type MapLine, type MapMarker } from "@/components/transport/osm-map";
import { LiveBadge, RequestStatus } from "@/components/transport/journey";
import { ownerName, telHref, useOwners, waHref } from "@/components/admin/transport-requests";
export function LiveOperations({ bookings, onOpen }: { bookings: Booking[]; onOpen: (id: string) => void }) {
  const { t, locale } = useI18n();
  const { data: owners = [] } = useOwners();
  const [selected, setSelected] = useState<string | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const active = bookings.filter((b) => b.status === "in_progress");
  const ids = active.map((b) => b.id);
  const key = ids.join(",");

  const { data, refetch } = useQuery({
    queryKey: ["adm-live", key],
    enabled: ids.length > 0,
    queryFn: async () => {
      const [live, stages] = await Promise.all([
        call<LiveLocation[]>(supabase.from("live_locations").select("*").in("booking_request_id", ids)),
        call<Tables<"journey_stages">[]>(supabase.from("journey_stages").select("*").in("booking_request_id", ids).order("stage_no")),
      ]);
      return { live, stages: stages.map(asStage) };
    },
  });
  useLiveRefresh("adm-live", [{ table: "live_locations" }, { table: "journey_stages" }], () => void refetch(), ids.length > 0, 15_000);
  useEffect(() => { const id = window.setInterval(() => setNow(Date.now()), 5_000); return () => window.clearInterval(id); }, []);

  const liveOf = (id: string) => data?.live.find((l) => l.booking_request_id === id) ?? null;
  const stageOf = (id: string): Stage | undefined => data?.stages.find((s) => s.booking_request_id === id && s.status === "in_progress");
  const sel = active.find((b) => b.id === selected) ?? null;
  const selStage = sel ? stageOf(sel.id) : undefined;

  const { data: track = [] } = useQuery({
    queryKey: ["adm-track", sel?.id, selStage?.id, data?.live.find((l) => l.booking_request_id === sel?.id)?.received_at],
    enabled: !!sel && !!selStage,
    queryFn: async () => (await call<LatLng[]>(supabase.from("gps_location_updates").select("lat,lng").eq("stage_id", selStage!.id).order("recorded_at").limit(3000))),
  });

  const today = tunisDay(new Date());
  const states = active.map((b) => liveState(liveOf(b.id), now));
  const stats: [string, number, string][] = [
    [t("Demandes en attente", "Pending requests", "طلبات قيد الانتظار"), bookings.filter((b) => ["pending", "new", "under_review"].includes(b.status)).length, "info"],
    [t("Réservations approuvées", "Approved bookings", "حجوزات معتمدة"), bookings.filter((b) => ["approved", "awaiting_owner", "confirmed"].includes(b.status)).length, "success"],
    [t("Opérations en cours", "Active operations", "عمليات جارية"), active.length, "live"],
    [t("Terminées aujourd’hui", "Completed today", "منتهية اليوم"), bookings.filter((b) => b.status === "completed" && tunisDay(b.updated_at) === today).length, "neutral"],
    [t("Véhicules suivis en direct", "Vehicles tracked live", "سيارات متتبعة مباشرة"), states.filter((s) => s === "live").length, "live"],
    [t("Problèmes GPS", "GPS issues", "مشاكل GPS"), states.filter((s) => s !== "live").length, "warning"],
  ];

  const markers: MapMarker[] = useMemo(() => {
    const out: MapMarker[] = [];
    for (const b of active) {
      const l = liveOf(b.id);
      const s = liveState(l, now);
      if (l && s !== "none") out.push({ id: b.id, lat: l.lat!, lng: l.lng!, kind: s === "live" ? "car-live" : s === "stale" ? "car-stale" : "car-paused", title: `${b.reference} · ${b.car_name}`, selected: b.id === selected, onClick: () => setSelected(b.id) });
    }
    if (selStage) {
      if (selStage.from_lat != null && selStage.from_lng != null) out.push({ id: "from", lat: selStage.from_lat, lng: selStage.from_lng, kind: "pickup", text: "A", title: selStage.from_address });
      selStage.stops.forEach((x, i) => out.push({ id: `s${i}`, lat: x.lat, lng: x.lng, kind: x.reached_at ? "stop-done" : "stop", text: String(i + 1), title: x.address }));
      if (selStage.to_lat != null && selStage.to_lng != null) out.push({ id: "to", lat: selStage.to_lat, lng: selStage.to_lng, kind: "destination", text: "B", title: selStage.to_address });
    }
    return out;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data, selected, selStage, now, key]);
  const lines: MapLine[] = track.length > 1 ? [{ id: "track", points: track, kind: "track" }] : [];
  const selLive = sel ? liveOf(sel.id) : null;
  const selOwner = owners.find((o) => o.id === sel?.owner_id);

  return (
    <>
      <div className="kpi-grid ops-kpis">
        {stats.map(([l, v, tone]) => <div key={l} className="kpi" data-tone={tone}><div className="kpi-label">{l}</div><div className="kpi-value">{v}</div></div>)}
      </div>
      <div className="ops-layout">
        <div className="ops-map">
          <OsmMap markers={markers} lines={lines} height="100%" fitKey={`${key}|${selected ?? ""}`} />
          {!active.length && <div className="ops-empty">{t("Aucune opération en cours.", "No active operation.", "لا توجد عمليات جارية.")}</div>}
        </div>
        <aside className="ops-side">
          {sel ? (
            <div className="ops-panel">
              <div className="car-meta"><span>{sel.reference}</span><RequestStatus status={sel.status} /></div>
              <h3>{sel.car_name}</h3>
              <LiveBadge live={selLive} />
              <dl className="ops-facts">
                <div><dt>{t("Propriétaire", "Owner", "المالك")}</dt><dd>{ownerName(selOwner)}</dd></div>
                <div><dt>{t("Téléphone", "Phone", "الهاتف")}</dt><dd dir="ltr">{selOwner?.phone ?? "—"}</dd></div>
                <div><dt>{t("Client", "Client", "العميل")}</dt><dd>{sel.first_name} {sel.last_name}</dd></div>
                <div><dt>{t("Étape", "Stage", "المرحلة")}</dt><dd>{selStage ? `${t("Partie", "Part", "الجزء")} ${selStage.stage_no} → ${selStage.to_address}` : t("Entre deux étapes", "Between stages", "بين مرحلتين")}</dd></div>
                <div><dt>{t("Coordonnées", "Coordinates", "الإحداثيات")}</dt><dd dir="ltr">{fmtCoords(selLive?.lat, selLive?.lng)}{selLive?.accuracy ? ` ±${Math.round(selLive.accuracy)} m` : ""}</dd></div>
                <div><dt>{t("Dernière mise à jour", "Last update", "آخر تحديث")}</dt><dd>{selLive?.received_at ? `${fmtWhen(selLive.received_at, locale)} (${fmtClock(selLive.received_at, locale)})` : "—"}</dd></div>
                {selLive?.speed != null && <div><dt>{t("Vitesse", "Speed", "السرعة")}</dt><dd>{Math.round(selLive.speed * 3.6)} km/h</dd></div>}
              </dl>
              <div className="action-row">
                {selOwner?.phone && <a className="ref-btn inline-flex items-center gap-2 border border-border" href={telHref(selOwner.phone)}><Phone className="h-4 w-4" />{t("Appeler", "Call", "اتصال")}</a>}
                {selOwner?.phone && <a className="ref-btn inline-flex items-center gap-2 border border-border" href={waHref(selOwner.phone)} target="_blank" rel="noreferrer"><MessageCircle className="h-4 w-4" />WhatsApp</a>}
                <Button className="ref-btn" onClick={() => onOpen(sel.id)}>{t("Ouvrir la demande", "Open request", "فتح الطلب")}</Button>
                <Button variant="ghost" className="ref-btn" onClick={() => setSelected(null)}>{t("Fermer", "Close", "إغلاق")}</Button>
              </div>
            </div>
          ) : null}
          <ul className="ops-list">
            {active.map((b) => {
              const st = stageOf(b.id);
              return (
                <li key={b.id}>
                  <button type="button" className={b.id === selected ? "is-active" : ""} onClick={() => setSelected(b.id)}>
                    <span className="req-item-top"><strong>{b.reference}</strong><LiveBadge live={liveOf(b.id)} compact /></span>
                    <span>{b.car_name} · {ownerName(owners.find((o) => o.id === b.owner_id))}</span>
                    <small>{st ? `${t("Partie", "Part", "الجزء")} ${st.stage_no} · ${st.to_address}` : t("Entre deux étapes", "Between stages", "بين مرحلتين")}</small>
                  </button>
                </li>
              );
            })}
          </ul>
        </aside>
      </div>
    </>
  );
}
