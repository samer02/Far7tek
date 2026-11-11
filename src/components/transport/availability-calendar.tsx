import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { supabase } from "@/integrations/supabase/client";
import { call, dayAvailability, fmtWhen, tunisDay, type AvailabilityRule, type CalendarBooking } from "@/lib/transport";
import { BOOKING_STATUS } from "@/lib/platform";
import { labelOf, useI18n } from "@/lib/i18n";

const pad = (n: number) => String(n).padStart(2, "0");
const iso = (y: number, m: number, d: number) => `${y}-${pad(m + 1)}-${pad(d)}`;

export function useCarRules(carId: string | null | undefined) {
  return useQuery({
    queryKey: ["avail-rules", carId],
    enabled: !!carId,
    queryFn: async () => call<AvailabilityRule[]>(supabase.from("car_availability_rules").select("*").eq("car_id", carId!).order("created_at")),
  });
}

/** Month view of a car's availability and bookings. `highlight` marks the dates of the request being reviewed. */
export function AvailabilityCalendar({ carId, mode, rules, highlight = [] }: { carId: string; mode: string; rules: AvailabilityRule[]; highlight?: string[] }) {
  const { t, lang, locale, dir } = useI18n();
  const first = highlight[0] ?? tunisDay(new Date());
  const [month, setMonth] = useState(() => ({ y: Number(first.slice(0, 4)), m: Number(first.slice(5, 7)) - 1 }));
  const [selected, setSelected] = useState<string | null>(highlight[0] ?? null);
  const days = new Date(Date.UTC(month.y, month.m + 1, 0)).getUTCDate();
  const from = iso(month.y, month.m, 1);
  const to = iso(month.y, month.m, days);
  const { data: bookings = [], isLoading } = useQuery({
    queryKey: ["car-calendar", carId, from],
    queryFn: () => call<CalendarBooking[]>(supabase.rpc("car_calendar_bookings", { _car: carId, _from: from, _to: to })),
  });

  const byDay = useMemo(() => {
    const out: Record<string, CalendarBooking[]> = {};
    for (const b of bookings) {
      for (let d = new Date(b.start); d < new Date(b.end); d = new Date(d.getTime() + 86_400_000)) (out[tunisDay(d)] ??= []).push(b);
      const endDay = tunisDay(new Date(new Date(b.end).getTime() - 1));
      if (!(out[endDay] ?? []).includes(b)) (out[endDay] ??= []).push(b);
    }
    return out;
  }, [bookings]);

  const offset = (new Date(Date.UTC(month.y, month.m, 1)).getUTCDay() + 6) % 7;
  const weekdays = Array.from({ length: 7 }, (_, i) => new Date(Date.UTC(2024, 0, 1 + i)).toLocaleDateString(locale, { weekday: "short", timeZone: "UTC" }));
  const title = new Date(Date.UTC(month.y, month.m, 15)).toLocaleDateString(locale, { month: "long", year: "numeric", timeZone: "UTC" });
  const shift = (n: number) => setMonth(({ y, m }) => ({ y: m + n < 0 ? y - 1 : m + n > 11 ? y + 1 : y, m: (m + n + 12) % 12 }));
  const Prev = dir === "rtl" ? ChevronRight : ChevronLeft;
  const Next = dir === "rtl" ? ChevronLeft : ChevronRight;
  const today = tunisDay(new Date());

  const cellState = (date: string) => {
    const bs = byDay[date] ?? [];
    if (bs.some((b) => b.status === "in_progress")) return "active";
    if (bs.some((b) => ["confirmed", "approved", "awaiting_owner", "accepted"].includes(b.status))) return "booked";
    const avail = dayAvailability(rules, mode, date).state;
    if (bs.length) return avail === "unavailable" ? "unavailable pending" : "pending";
    return avail;
  };
  const sel = selected ? { date: selected, avail: dayAvailability(rules, mode, selected), bookings: byDay[selected] ?? [] } : null;

  return (
    <div className="cal">
      <div className="cal-head">
        <button type="button" className="icon-btn" onClick={() => shift(-1)} aria-label={t("Mois précédent", "Previous month", "الشهر السابق")}><Prev /></button>
        <strong>{title}</strong>
        <button type="button" className="icon-btn" onClick={() => shift(1)} aria-label={t("Mois suivant", "Next month", "الشهر التالي")}><Next /></button>
      </div>
      <div className="cal-grid" aria-busy={isLoading}>
        {weekdays.map((w) => <span key={w} className="cal-wd">{w}</span>)}
        {Array.from({ length: offset }, (_, i) => <span key={`e${i}`} />)}
        {Array.from({ length: days }, (_, i) => {
          const date = iso(month.y, month.m, i + 1);
          return (
            <button key={date} type="button" className={`cal-day ${cellState(date)} ${highlight.includes(date) ? "is-target" : ""} ${date === today ? "is-today" : ""} ${date === selected ? "is-selected" : ""}`}
              onClick={() => setSelected(date)} aria-pressed={date === selected}>
              <span>{i + 1}</span>
              {(byDay[date]?.length ?? 0) > 0 && <i>{byDay[date]!.length}</i>}
            </button>
          );
        })}
      </div>
      <div className="cal-legend">
        <span className="available">{t("Disponible", "Available", "متاح")}</span>
        <span className="partial">{t("Partiellement", "Partly", "جزئياً")}</span>
        <span className="unavailable">{t("Indisponible", "Unavailable", "غير متاح")}</span>
        <span className="pending">{t("Demande en attente", "Pending request", "طلب قيد الانتظار")}</span>
        <span className="booked">{t("Réservé", "Booked", "محجوز")}</span>
        <span className="active">{t("Opération en cours", "Active operation", "عملية جارية")}</span>
      </div>
      {sel && (
        <div className="cal-detail">
          <strong>{new Date(`${sel.date}T12:00:00Z`).toLocaleDateString(locale, { weekday: "long", day: "numeric", month: "long", timeZone: "UTC" })}</strong>
          <p>
            {sel.avail.state === "unavailable" ? t("Indisponible", "Unavailable", "غير متاح")
              : sel.avail.state === "available" ? t("Disponible toute la journée", "Available all day", "متاح طوال اليوم")
              : `${t("Disponible", "Available", "متاح")} ${sel.avail.periods.map((p) => `${p.from}–${p.to}`).join(", ")}`}
          </p>
          {sel.bookings.map((b) => (
            <div key={b.id} className="note-row"><strong>{b.reference}</strong> · {labelOf(BOOKING_STATUS, b.status, lang)}<small className="block">{fmtWhen(b.start, locale)} → {fmtWhen(b.end, locale)}</small></div>
          ))}
        </div>
      )}
    </div>
  );
}
