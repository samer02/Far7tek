import { useEffect, useMemo, useState } from "react";
import { fetchRoute, liveState, type LatLng, type LiveLocation, type Stop } from "@/lib/transport";
import { OsmMap, type MapLine, type MapMarker } from "@/components/transport/osm-map";
import { useI18n } from "@/lib/i18n";

const point = (lat: number | null | undefined, lng: number | null | undefined): LatLng | null =>
  lat != null && lng != null ? { lat, lng } : null;
export { point as toPoint };

/** Requested route (pickup → stops → destination), optionally with the live car and its GPS trail. */
export function RouteMap({ pickup, destination, stops = [], live, track = [], height = 340, fitKey }: {
  pickup: LatLng | null; destination: LatLng | null; stops?: Stop[]; live?: LiveLocation | null; track?: LatLng[]; height?: number | string; fitKey?: string;
}) {
  const { t } = useI18n();
  const [road, setRoad] = useState<LatLng[] | null>(null);
  const waypoints = useMemo(() => [pickup, ...stops.map((s) => ({ lat: s.lat, lng: s.lng })), destination].filter(Boolean) as LatLng[], [pickup, destination, stops]);
  const wpKey = waypoints.map((p) => `${p.lat},${p.lng}`).join(";");

  useEffect(() => {
    let on = true;
    setRoad(null);
    if (waypoints.length > 1) fetchRoute(waypoints).then((r) => on && setRoad(r));
    return () => { on = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wpKey]);

  const state = liveState(live ?? null);
  const markers: MapMarker[] = [
    ...(pickup ? [{ id: "pickup", ...pickup, kind: "pickup" as const, text: "A", title: t("Départ", "Pick-up", "الانطلاق") }] : []),
    ...stops.map((s, i) => ({ id: `stop-${i}`, lat: s.lat, lng: s.lng, kind: s.reached_at ? ("stop-done" as const) : ("stop" as const), text: String(i + 1), title: s.address })),
    ...(destination ? [{ id: "dest", ...destination, kind: "destination" as const, text: "B", title: t("Destination", "Destination", "الوجهة") }] : []),
    ...(live && state !== "none" ? [{ id: "car", lat: live.lat!, lng: live.lng!, kind: (state === "live" ? "car-live" : state === "stale" ? "car-stale" : "car-paused") as MapMarker["kind"], title: t("Véhicule", "Vehicle", "السيارة") }] : []),
  ];
  const lines: MapLine[] = [
    road ? { id: "road", points: road, kind: "route" } : { id: "planned", points: waypoints, kind: "planned" },
    ...(track.length > 1 ? [{ id: "track", points: track, kind: "track" as const }] : []),
  ];
  return <OsmMap markers={markers} lines={lines} height={height} fitKey={fitKey ?? wpKey} />;
}
