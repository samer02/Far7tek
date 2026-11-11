import { useEffect, useRef, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { call } from "@/lib/transport";

export type GpsPermission = "unknown" | "prompt" | "granted" | "denied" | "unsupported";
export type GpsTrackerState = {
  permission: GpsPermission;
  /** idle: not tracking · acquiring: waiting for a first fix · live: positions flowing · offline: fixes not reaching the server · error: no GPS fix */
  status: "idle" | "acquiring" | "live" | "offline" | "error";
  fix: { lat: number; lng: number; accuracy: number; at: number } | null;
  lastSentAt: number | null;
  lastReason: string | null;
  sent: number;
};

const SEND_EVERY_MS = 5_000;
const MOVE_M = 25;
const HEARTBEAT_MS = 15_000;

const dist = (a: { lat: number; lng: number }, b: { lat: number; lng: number }) => {
  const r = Math.PI / 180;
  const x = Math.sin(((b.lat - a.lat) * r) / 2) ** 2 + Math.cos(a.lat * r) * Math.cos(b.lat * r) * Math.sin(((b.lng - a.lng) * r) / 2) ** 2;
  return 2 * 6371000 * Math.asin(Math.sqrt(x));
};

/** One-off position for Start/End actions. Resolves null when permission is denied or no fix arrives. */
export function currentPosition(timeout = 15_000): Promise<GeolocationPosition | null> {
  return new Promise((resolve) => {
    if (typeof navigator === "undefined" || !("geolocation" in navigator)) return resolve(null);
    navigator.geolocation.getCurrentPosition(resolve, () => resolve(null), { enableHighAccuracy: true, timeout, maximumAge: 10_000 });
  });
}

export async function gpsPermission(): Promise<GpsPermission> {
  if (typeof navigator === "undefined" || !("geolocation" in navigator)) return "unsupported";
  try {
    const s = await navigator.permissions?.query({ name: "geolocation" as PermissionName });
    return (s?.state as GpsPermission | undefined) ?? "unknown";
  } catch {
    return "unknown";
  }
}

/**
 * Streams the device position to journey_push_location while `active` (a stage is running).
 * Only real device fixes are sent; when the server answers that tracking is over, `onServerStop` fires.
 */
export function useGpsTracker(bookingId: string | null, active: boolean, onServerStop?: () => void): GpsTrackerState {
  const [state, setState] = useState<GpsTrackerState>({ permission: "unknown", status: "idle", fix: null, lastSentAt: null, lastReason: null, sent: 0 });
  const stopRef = useRef(onServerStop);
  stopRef.current = onServerStop;

  useEffect(() => {
    gpsPermission().then((permission) => setState((s) => ({ ...s, permission })));
  }, []);

  useEffect(() => {
    if (!active || !bookingId || typeof navigator === "undefined" || !("geolocation" in navigator)) {
      setState((s) => ({ ...s, status: "idle" }));
      return;
    }
    let disposed = false;
    let pending: GeolocationPosition | null = null;
    let lastSent: { lat: number; lng: number; at: number } | null = null;
    let lastFixAt = 0;
    let inflight = false;
    let wake: { release: () => Promise<void> } | null = null;
    setState((s) => ({ ...s, status: "acquiring" }));

    async function flush(force = false) {
      const pos = pending;
      if (!pos || inflight || disposed) return;
      const p = { lat: pos.coords.latitude, lng: pos.coords.longitude };
      if (!force && lastSent && Date.now() - lastSent.at < SEND_EVERY_MS && dist(lastSent, p) < MOVE_M) return;
      inflight = true;
      try {
        const res = await call<{ accepted: boolean; reason?: string; tracking: boolean }>(supabase.rpc("journey_push_location", {
          _booking: bookingId!, _lat: p.lat, _lng: p.lng, _accuracy: pos.coords.accuracy ?? null,
          _heading: Number.isFinite(pos.coords.heading) ? pos.coords.heading : null,
          _speed: Number.isFinite(pos.coords.speed) ? pos.coords.speed : null,
          _recorded_at: new Date(pos.timestamp).toISOString(),
        }));
        if (disposed) return;
        if (pending === pos) pending = null;
        if (res.accepted || res.reason === "throttled") lastSent = { ...p, at: Date.now() };
        setState((s) => ({ ...s, status: "live", lastReason: res.accepted ? null : (res.reason ?? null), lastSentAt: res.accepted ? Date.now() : s.lastSentAt, sent: s.sent + (res.accepted ? 1 : 0) }));
        if (!res.tracking) stopRef.current?.();
      } catch {
        // Connection lost: keep the newest fix and retry on the next tick.
        if (!disposed) setState((s) => ({ ...s, status: "offline" }));
      } finally {
        inflight = false;
      }
    }

    const onFix = (pos: GeolocationPosition) => {
      lastFixAt = Date.now();
      pending = pos;
      setState((s) => ({ ...s, permission: "granted", status: s.status === "offline" ? "offline" : "live", fix: { lat: pos.coords.latitude, lng: pos.coords.longitude, accuracy: pos.coords.accuracy, at: pos.timestamp } }));
      void flush();
    };
    const onError = (err: GeolocationPositionError) => {
      setState((s) => ({ ...s, permission: err.code === err.PERMISSION_DENIED ? "denied" : s.permission, status: "error" }));
    };
    const watch = navigator.geolocation.watchPosition(onFix, onError, { enableHighAccuracy: true, maximumAge: 5_000, timeout: 30_000 });
    // A parked car produces no watch events; ask for a fresh fix so the admin keeps seeing a live position.
    const tick = window.setInterval(() => {
      if (Date.now() - lastFixAt > HEARTBEAT_MS) navigator.geolocation.getCurrentPosition(onFix, onError, { enableHighAccuracy: true, maximumAge: 0, timeout: 20_000 });
      void flush(true);
    }, HEARTBEAT_MS);

    const lockScreen = async () => {
      try {
        const nav = navigator as Navigator & { wakeLock?: { request: (t: "screen") => Promise<{ release: () => Promise<void> }> } };
        if (nav.wakeLock && document.visibilityState === "visible") wake = await nav.wakeLock.request("screen");
      } catch { /* wake lock not granted: tracking still works while the screen is on */ }
    };
    const onVisible = () => { if (document.visibilityState === "visible") { void lockScreen(); void flush(true); } };
    void lockScreen();
    document.addEventListener("visibilitychange", onVisible);
    window.addEventListener("online", onVisible);

    return () => {
      disposed = true;
      navigator.geolocation.clearWatch(watch);
      window.clearInterval(tick);
      document.removeEventListener("visibilitychange", onVisible);
      window.removeEventListener("online", onVisible);
      void wake?.release().catch(() => {});
    };
  }, [active, bookingId]);

  return state;
}
