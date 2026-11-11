import { useRef, useState } from "react";
import { toast } from "sonner";
import { Crosshair, MapPin, Plus, Search, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { OsmMap, type MapMarker } from "@/components/transport/osm-map";
import { reverseGeocode, searchPlaces, type LatLng, type Place } from "@/lib/transport";
import { useI18n } from "@/lib/i18n";

export type Journey = { pickup: Place | null; destination: Place | null; stops: Place[] };
type Slot = "pickup" | "destination" | number;
export const MAX_STOPS = 5;

/** Pick-up, destination and intermediate stops chosen on an OpenStreetMap map. */
export function LocationPicker({ value, onChange, errors = {} }: { value: Journey; onChange: (v: Journey) => void; errors?: Record<string, string | undefined> }) {
  const { t, lang } = useI18n();
  const [mode, setMode] = useState<Slot | "new-stop">(value.pickup ? "destination" : "pickup");
  const [q, setQ] = useState("");
  const [results, setResults] = useState<Place[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [focus, setFocus] = useState<LatLng | null>(null);
  // Async geocoding answers must apply to the latest journey, not the one captured at click time.
  const latest = useRef(value);
  latest.current = value;

  const label = (m: Slot | "new-stop") => m === "pickup" ? t("Départ", "Pick-up", "الانطلاق") : m === "destination" ? t("Destination", "Destination", "الوجهة") : t("Arrêt", "Stop", "توقف");

  function set(slot: Slot, p: Place) {
    const v = latest.current;
    const next = slot === "pickup" ? { ...v, pickup: p } : slot === "destination" ? { ...v, destination: p } : { ...v, stops: v.stops.map((s, i) => (i === slot ? p : s)) };
    latest.current = next;
    onChange(next);
  }

  /** Places the active point (adding a stop if requested) and returns the slot it landed in. */
  function placeActive(p: Place): Slot | null {
    if (mode !== "new-stop") { set(mode, p); if (mode === "pickup" && !latest.current.destination) setMode("destination"); return mode; }
    const v = latest.current;
    if (v.stops.length >= MAX_STOPS) return null;
    const next = { ...v, stops: [...v.stops, p] };
    latest.current = next;
    onChange(next);
    setMode(v.stops.length);
    return v.stops.length;
  }

  async function locate(p: LatLng, slot: Slot | null) {
    if (slot === null) return;
    const name = await reverseGeocode(p, lang);
    if (name) set(slot, { ...p, address: name });
  }

  function pickOnMap(p: LatLng) {
    void locate(p, placeActive({ ...p, address: `${p.lat.toFixed(5)}, ${p.lng.toFixed(5)}` }));
  }

  async function search() {
    if (q.trim().length < 3) return;
    setBusy(true);
    try { setResults(await searchPlaces(q.trim(), lang)); }
    catch { toast.error(t("Recherche indisponible, cliquez directement sur la carte.", "Search unavailable, click on the map instead.", "البحث غير متاح، انقر على الخريطة مباشرة.")); }
    finally { setBusy(false); }
  }

  function locateMe() {
    if (!("geolocation" in navigator)) { toast.error(t("Géolocalisation non prise en charge", "Geolocation not supported", "تحديد الموقع غير مدعوم")); return; }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const p = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        setFocus(p);
        set("pickup", { ...p, address: `${p.lat.toFixed(5)}, ${p.lng.toFixed(5)}` });
        if (!latest.current.destination) setMode("destination");
        void locate(p, "pickup");
      },
      () => toast.error(t("Position refusée ou indisponible", "Location denied or unavailable", "تم رفض الموقع أو غير متاح")),
      { enableHighAccuracy: true, timeout: 15000 },
    );
  }

  const markers: MapMarker[] = [
    ...(value.pickup ? [{ id: "p", ...value.pickup, kind: "pickup" as const, text: "A", selected: mode === "pickup", title: value.pickup.address }] : []),
    ...value.stops.map((s, i) => ({ id: `s${i}`, lat: s.lat, lng: s.lng, kind: "stop" as const, text: String(i + 1), selected: mode === i, title: s.address })),
    ...(value.destination ? [{ id: "d", ...value.destination, kind: "destination" as const, text: "B", selected: mode === "destination", title: value.destination.address }] : []),
  ];
  const fitKey = [value.pickup, value.destination].map((p) => (p ? `${p.lat.toFixed(3)},${p.lng.toFixed(3)}` : "")).join("|");

  const row = (slot: Slot, p: Place | null, badge: string) => (
    <div key={String(slot)} className={`picker-row ${mode === slot ? "is-active" : ""}`}>
      <button type="button" className={`picker-badge picker-badge-${typeof slot === "number" ? "stop" : slot}`} onClick={() => setMode(slot)} aria-pressed={mode === slot}>{badge}</button>
      <div className="picker-field">
        <small>{label(slot)}{p && <span dir="ltr"> · {p.lat.toFixed(4)}, {p.lng.toFixed(4)}</span>}</small>
        {p ? <input value={p.address} maxLength={250} onChange={(e) => set(slot, { ...p, address: e.target.value })} onFocus={() => setMode(slot)} aria-label={label(slot)} />
          : <button type="button" className="picker-empty" onClick={() => setMode(slot)}>{t("Cliquez sur la carte ou recherchez une adresse", "Click the map or search an address", "انقر على الخريطة أو ابحث عن عنوان")}</button>}
      </div>
      {typeof slot === "number" && (
        <button type="button" className="icon-btn" aria-label={t("Supprimer l’arrêt", "Remove stop", "حذف التوقف")}
          onClick={() => { onChange({ ...value, stops: value.stops.filter((_, i) => i !== slot) }); setMode("destination"); }}><Trash2 /></button>
      )}
    </div>
  );

  return (
    <div className="picker">
      <div className="picker-toolbar">
        <div className="picker-search" role="search">
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t("Rechercher une adresse, un lieu…", "Search an address or place…", "ابحث عن عنوان أو مكان…")}
            onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void search(); } }} />
          <Button type="button" variant="outline" className="ref-btn" disabled={busy} onClick={() => void search()}><Search className="h-4 w-4" />{t("Chercher", "Search", "بحث")}</Button>
        </div>
        <Button type="button" variant="ghost" className="ref-btn" onClick={locateMe}><Crosshair className="h-4 w-4" />{t("Ma position", "My location", "موقعي")}</Button>
      </div>
      {results && (
        <div className="picker-results">
          {!results.length && <p>{t("Aucun résultat", "No results", "لا توجد نتائج")}</p>}
          {results.map((r) => (
            <button key={`${r.lat},${r.lng}`} type="button" onClick={() => { placeActive(r); setFocus(r); setResults(null); setQ(""); }}>
              <MapPin className="h-4 w-4" /><span>{r.address}</span>
            </button>
          ))}
        </div>
      )}
      <p className="picker-hint">
        {t("Point actif :", "Active point:", "النقطة النشطة:")} <strong>{label(mode)}{typeof mode === "number" ? ` ${mode + 1}` : ""}</strong> — {t("cliquez sur la carte pour le placer.", "click the map to place it.", "انقر على الخريطة لوضعها.")}
      </p>
      <OsmMap markers={markers} onMapClick={pickOnMap} height={380} fitKey={fitKey} focus={focus} />
      <div className="picker-rows">
        {row("pickup", value.pickup, "A")}
        {errors["pickup"] && <span className="form-error">{errors["pickup"]}</span>}
        {value.stops.map((s, i) => row(i, s, String(i + 1)))}
        {row("destination", value.destination, "B")}
        {errors["destination"] && <span className="form-error">{errors["destination"]}</span>}
        {value.stops.length < MAX_STOPS && (
          <Button type="button" variant="ghost" className="ref-btn self-start" onClick={() => setMode("new-stop")} aria-pressed={mode === "new-stop"}>
            <Plus className="h-4 w-4" />{mode === "new-stop" ? t("Cliquez sur la carte pour ajouter l’arrêt", "Click the map to add the stop", "انقر على الخريطة لإضافة التوقف") : t("Ajouter un arrêt", "Add a stop", "إضافة توقف")}
          </Button>
        )}
      </div>
    </div>
  );
}
