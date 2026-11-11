import { useEffect, useRef, useState } from "react";
import type * as Leaflet from "leaflet";
import type { LatLng } from "@/lib/transport";
import { useI18n } from "@/lib/i18n";

export type MarkerKind = "pickup" | "destination" | "stop" | "stop-done" | "start" | "end" | "car-live" | "car-stale" | "car-paused";
export type MapMarker = { id: string; lat: number; lng: number; kind: MarkerKind; text?: string; title?: string; onClick?: () => void; selected?: boolean };
export type LineKind = "route" | "planned" | "track" | "done";
export type MapLine = { id: string; points: LatLng[]; kind: LineKind };

const TILES = (import.meta.env["VITE_MAP_TILES_URL"] as string | undefined) ?? "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const TUNIS: LatLng = { lat: 36.8065, lng: 10.1815 };
const CAR_SVG = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><path d="M9 17h6"/><circle cx="17" cy="17" r="2"/></svg>';
const LINE_STYLE: Record<LineKind, Leaflet.PolylineOptions> = {
  route: { color: "#b0704f", weight: 5, opacity: 0.85 },
  planned: { color: "#b0704f", weight: 3, opacity: 0.7, dashArray: "6 8" },
  track: { color: "#2f7d5b", weight: 4, opacity: 0.9 },
  done: { color: "#8a8f96", weight: 4, opacity: 0.6 },
};

function iconHtml(m: MapMarker) {
  const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]!);
  if (m.kind.startsWith("car")) return `<span class="map-car map-${m.kind}${m.selected ? " is-selected" : ""}">${CAR_SVG}</span>`;
  return `<span class="map-pin map-pin-${m.kind}${m.selected ? " is-selected" : ""}"><b>${esc(m.text ?? "")}</b></span>`;
}

/**
 * OpenStreetMap view (Leaflet). Bounds are fitted when `fitKey` changes, so live updates
 * move markers without resetting the user's zoom.
 */
export function OsmMap({ markers = [], lines = [], onMapClick, fitKey, className = "", height = 360, focus }: {
  markers?: MapMarker[]; lines?: MapLine[]; onMapClick?: (p: LatLng) => void; fitKey?: string; className?: string; height?: number | string; focus?: LatLng | null;
}) {
  const { t } = useI18n();
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<Leaflet.Map | null>(null);
  const L = useRef<typeof Leaflet | null>(null);
  const layer = useRef<Leaflet.LayerGroup | null>(null);
  const clickRef = useRef(onMapClick);
  clickRef.current = onMapClick;
  const [ready, setReady] = useState(false);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    import("leaflet")
      .then((mod) => {
        if (cancelled || !el.current) return;
        const lib = (mod as unknown as { default?: typeof Leaflet }).default ?? (mod as unknown as typeof Leaflet);
        L.current = lib;
        const m = lib.map(el.current, { zoomControl: true, attributionControl: true }).setView([TUNIS.lat, TUNIS.lng], 11);
        lib.tileLayer(TILES, { maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">OpenStreetMap</a>' }).addTo(m);
        layer.current = lib.layerGroup().addTo(m);
        m.on("click", (e: Leaflet.LeafletMouseEvent) => clickRef.current?.({ lat: e.latlng.lat, lng: e.latlng.lng }));
        map.current = m;
        setReady(true);
      })
      .catch(() => setFailed(true));
    return () => {
      cancelled = true;
      map.current?.remove();
      map.current = null;
    };
  }, []);

  useEffect(() => {
    const lib = L.current;
    const g = layer.current;
    if (!ready || !lib || !g) return;
    g.clearLayers();
    for (const l of lines) if (l.points.length > 1) lib.polyline(l.points.map((p) => [p.lat, p.lng] as [number, number]), LINE_STYLE[l.kind]).addTo(g);
    for (const m of markers) {
      const car = m.kind.startsWith("car");
      const mk = lib.marker([m.lat, m.lng], {
        icon: lib.divIcon({ html: iconHtml(m), className: "map-icon", iconSize: car ? [40, 40] : [30, 38], iconAnchor: car ? [20, 20] : [15, 36] }),
        zIndexOffset: car ? 1000 : 0,
        title: m.title ?? "",
        keyboard: !!m.onClick,
      }).addTo(g);
      if (m.title) mk.bindTooltip(m.title, { direction: "top", offset: [0, car ? -18 : -34] });
      if (m.onClick) mk.on("click", m.onClick);
    }
  }, [ready, markers, lines]);

  useEffect(() => {
    const lib = L.current;
    const m = map.current;
    if (!ready || !lib || !m) return;
    const pts = [...markers.map((x) => [x.lat, x.lng] as [number, number]), ...lines.flatMap((l) => l.points.map((p) => [p.lat, p.lng] as [number, number]))];
    if (pts.length === 1) m.setView(pts[0]!, 14);
    else if (pts.length > 1) m.fitBounds(lib.latLngBounds(pts), { padding: [36, 36], maxZoom: 15 });
    // Only refit when the caller says the subject changed.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ready, fitKey]);

  useEffect(() => {
    if (ready && focus && map.current) map.current.setView([focus.lat, focus.lng], Math.max(map.current.getZoom(), 15));
  }, [ready, focus]);

  return (
    <div className={`osm-map ${className}`} style={{ height }}>
      <div ref={el} className="osm-map-canvas" dir="ltr" role="application" aria-label={t("Carte", "Map", "خريطة")} />
      {!ready && !failed && <div className="osm-map-overlay">{t("Chargement de la carte…", "Loading map…", "جارٍ تحميل الخريطة…")}</div>}
      {failed && <div className="osm-map-overlay">{t("Carte indisponible", "Map unavailable", "الخريطة غير متاحة")}</div>}
    </div>
  );
}
