import { useEffect, useRef } from "react";
import { supabase } from "@/integrations/supabase/client";
import type { Json, Tables } from "@/integrations/supabase/types";
import type { CarCategory } from "@/lib/platform";

/** Tunisia is UTC+1 all year; every schedule is interpreted in this zone, like the database does. */
export const TZ = "Africa/Tunis";
const TZ_OFFSET = "+01:00";

export type LatLng = { lat: number; lng: number };
export type Place = LatLng & { address: string };
export type Stop = Place & { reached_at?: string };
export type Booking = Tables<"booking_requests">;
export type Stage = Omit<Tables<"journey_stages">, "stops"> & { stops: Stop[] };
export type LiveLocation = Tables<"live_locations">;
export type JourneyEvent = Tables<"journey_events">;
export type AvailabilityRule = Tables<"car_availability_rules">;
export type CalendarBooking = { id: string; reference: string; status: string; start: string; end: string };

export type OwnerOperation = {
  id: string; reference: string; status: string; category: CarCategory | null;
  car: { id: string; name: string; slug: string } | null;
  service_start_at: string | null; service_end_at: string | null;
  wedding_date: string; wedding_time: string; return_time: string | null; trip_type: string; passengers: number; city: string;
  pickup_address: string; pickup_lat: number | null; pickup_lng: number | null;
  venue: string; destination_lat: number | null; destination_lng: number | null;
  stops: Stop[]; requirements: string; client_name: string; client_phone: string | null; contact_extra: string | null;
  stages: Stage[];
};

/** Status changes an admin may make, mirroring admin_transport_set_status. */
export const ADMIN_TRANSITIONS: Record<string, string[]> = {
  new: ["under_review", "approved", "rejected", "cancelled"],
  pending: ["under_review", "approved", "rejected", "cancelled"],
  contacted: ["under_review", "approved", "rejected", "cancelled"],
  under_review: ["approved", "rejected", "pending", "cancelled"],
  accepted: ["approved", "confirmed", "cancelled"],
  approved: ["awaiting_owner", "confirmed", "under_review", "rejected", "cancelled"],
  awaiting_owner: ["confirmed", "approved", "under_review", "cancelled"],
  confirmed: ["approved", "cancelled"],
  in_progress: ["completed", "cancelled"],
  rejected: ["under_review"],
};
export const CLIENT_CANCELLABLE = ["new", "pending", "contacted", "under_review", "approved", "awaiting_owner", "confirmed", "accepted"];
/** Statuses that hold the car's time slot. */
export const HOLDING = ["approved", "awaiting_owner", "confirmed", "in_progress"];

type RpcResult = PromiseLike<{ data: unknown; error: { message: string } | null }>;
/** Awaits a Supabase call and turns its error into an exception carrying the database message. */
export async function call<T = unknown>(p: RpcResult): Promise<T> {
  const { data, error } = await p;
  if (error) throw new Error(error.message);
  return data as T;
}

export const asStops = (j: Json | null | undefined): Stop[] => (Array.isArray(j) ? (j as unknown as Stop[]) : []);
export const asStage = (s: Tables<"journey_stages">): Stage => ({ ...s, stops: asStops(s.stops) });

// ---------------------------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------------------------
const dayFmt = new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" });
/** YYYY-MM-DD of an instant, in Tunisian time. */
export const tunisDay = (d: Date | string) => dayFmt.format(typeof d === "string" ? new Date(d) : d);
/** ISO instant for a Tunisian local date + time. */
export const tunisInstant = (date: string, time: string) => `${date}T${time.length === 5 ? `${time}:00` : time}${TZ_OFFSET}`;
export const fmtWhen = (ts: string | null | undefined, locale: string, withDate = true) =>
  ts ? new Date(ts).toLocaleString(locale, { timeZone: TZ, ...(withDate ? { day: "2-digit", month: "short" } : {}), hour: "2-digit", minute: "2-digit" }) : "—";
export const fmtClock = (ts: string | null | undefined, locale: string) =>
  ts ? new Date(ts).toLocaleTimeString(locale, { timeZone: TZ, hour: "2-digit", minute: "2-digit", second: "2-digit" }) : "—";
export const fmtCoords = (lat: number | null | undefined, lng: number | null | undefined) =>
  lat != null && lng != null ? `${lat.toFixed(5)}, ${lng.toFixed(5)}` : "—";

// ---------------------------------------------------------------------------------------------
// Availability (display mirror of car_window_status; the database stays the authority)
// ---------------------------------------------------------------------------------------------
export type Period = { from: string; to: string };
export type DayAvailability = { state: "available" | "partial" | "unavailable"; periods: Period[] };
const toMin = (t: string) => { const [h, m] = t.split(":").map(Number); return (h ?? 0) * 60 + (m ?? 0); };
const toHHMM = (n: number) => `${String(Math.floor(n / 60)).padStart(2, "0")}:${String(n % 60).padStart(2, "0")}`;
export const weekdayOf = (date: string) => new Date(`${date}T12:00:00Z`).getUTCDay();

export function dayAvailability(rules: AvailabilityRule[], mode: string, date: string): DayAvailability {
  const dow = weekdayOf(date);
  const applies = (r: AvailabilityRule) =>
    r.kind === "weekly" ? r.weekday === dow : !!r.date_from && !!r.date_to && r.date_from <= date && date <= r.date_to;
  const span = (r: AvailabilityRule): [number, number] => (r.start_time && r.end_time ? [toMin(r.start_time), toMin(r.end_time)] : [0, 1440]);
  const today = rules.filter(applies);
  const datesOpen = today.filter((r) => r.kind === "dates" && r.available);
  const open: [number, number][] = datesOpen.length ? datesOpen.map(span)
    : mode === "always" ? [[0, 1440]]
    : today.filter((r) => r.kind === "weekly" && r.available).map(span);
  let free: [number, number][] = [];
  for (const [s, e] of [...open].sort((a, b) => a[0] - b[0])) {
    const last = free[free.length - 1];
    if (last && s <= last[1]) last[1] = Math.max(last[1], e);
    else free.push([s, e]);
  }
  for (const [cs, ce] of today.filter((r) => !r.available).map(span)) {
    free = free.flatMap(([s, e]): [number, number][] => {
      if (ce <= s || cs >= e) return [[s, e]];
      const out: [number, number][] = [];
      if (cs > s) out.push([s, cs]);
      if (ce < e) out.push([ce, e]);
      return out;
    });
  }
  const periods = free.map(([s, e]) => ({ from: toHHMM(s), to: toHHMM(e) }));
  const total = free.reduce((n, [s, e]) => n + (e - s), 0);
  return { state: total === 0 ? "unavailable" : total >= 1440 ? "available" : "partial", periods };
}

// ---------------------------------------------------------------------------------------------
// GPS freshness
// ---------------------------------------------------------------------------------------------
/** Beyond this delay a tracked position is shown as "last known", not live. */
export const LIVE_STALE_MS = 60_000;
export type LiveState = "live" | "stale" | "paused" | "none";
export function liveState(l: LiveLocation | null | undefined, now = Date.now()): LiveState {
  if (!l || l.lat == null || l.lng == null) return "none";
  if (!l.tracking) return "paused";
  const t = l.received_at ? new Date(l.received_at).getTime() : 0;
  return now - t > LIVE_STALE_MS ? "stale" : "live";
}

// ---------------------------------------------------------------------------------------------
// OpenStreetMap services (Nominatim geocoding, OSRM routing)
// ---------------------------------------------------------------------------------------------
const NOMINATIM = "https://nominatim.openstreetmap.org";
const OSRM = (import.meta.env["VITE_OSRM_URL"] as string | undefined) ?? "https://router.project-osrm.org";

type NominatimHit = { display_name: string; lat: string; lon: string };
/** Address search (Nominatim policy: explicit user searches only, no autocomplete). */
export async function searchPlaces(q: string, lang: string): Promise<Place[]> {
  const go = async (country: boolean) => {
    const url = `${NOMINATIM}/search?format=jsonv2&limit=6&accept-language=${lang}${country ? "&countrycodes=tn" : ""}&q=${encodeURIComponent(q)}`;
    const res = await fetch(url, { headers: { Accept: "application/json" } });
    if (!res.ok) throw new Error(String(res.status));
    return ((await res.json()) as NominatimHit[]).map((h) => ({ address: h.display_name, lat: Number(h.lat), lng: Number(h.lon) }));
  };
  const local = await go(true);
  return local.length ? local : go(false);
}

export async function reverseGeocode(p: LatLng, lang: string): Promise<string | null> {
  try {
    const res = await fetch(`${NOMINATIM}/reverse?format=jsonv2&zoom=18&accept-language=${lang}&lat=${p.lat}&lon=${p.lng}`, { headers: { Accept: "application/json" } });
    if (!res.ok) return null;
    return ((await res.json()) as { display_name?: string }).display_name ?? null;
  } catch {
    return null;
  }
}

const routeCache = new Map<string, LatLng[] | null>();
/** Road route through the given points, or null when the routing service is unavailable. */
export async function fetchRoute(points: LatLng[]): Promise<LatLng[] | null> {
  if (points.length < 2) return null;
  const key = points.map((p) => `${p.lng.toFixed(5)},${p.lat.toFixed(5)}`).join(";");
  if (routeCache.has(key)) return routeCache.get(key)!;
  try {
    const res = await fetch(`${OSRM}/route/v1/driving/${key}?overview=full&geometries=geojson`);
    const json = (await res.json()) as { routes?: { geometry: { coordinates: [number, number][] } }[] };
    const coords = json.routes?.[0]?.geometry.coordinates.map(([lng, lat]) => ({ lat, lng })) ?? null;
    routeCache.set(key, coords);
    return coords;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------------------------
// Realtime
// ---------------------------------------------------------------------------------------------
/**
 * Calls `onChange` whenever one of the tables changes (Supabase Realtime, filtered by RLS),
 * and every `pollMs` as a fallback when the realtime connection is unavailable.
 */
export function useLiveRefresh(name: string, tables: { table: string; filter?: string }[], onChange: () => void, enabled = true, pollMs = 20_000) {
  const cb = useRef(onChange);
  cb.current = onChange;
  const key = tables.map((t) => `${t.table}:${t.filter ?? ""}`).join("|");
  useEffect(() => {
    if (!enabled) return;
    let channel = supabase.channel(`${name}-${Math.random().toString(36).slice(2)}`);
    for (const t of tables) {
      channel = channel.on("postgres_changes" as never, { event: "*", schema: "public", table: t.table, ...(t.filter ? { filter: t.filter } : {}) } as never, () => cb.current());
    }
    channel.subscribe();
    const timer = window.setInterval(() => cb.current(), pollMs);
    return () => {
      window.clearInterval(timer);
      supabase.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [name, key, enabled, pollMs]);
}
