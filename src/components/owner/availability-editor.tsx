import { useEffect, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { AvailabilityCalendar, useCarRules } from "@/components/transport/availability-calendar";
import { call, type AvailabilityRule } from "@/lib/transport";
import { useI18n } from "@/lib/i18n";

type DayPlan = { mode: "full" | "hours" | "off"; periods: { from: string; to: string }[] };
const ORDER = [1, 2, 3, 4, 5, 6, 0];
const hhmm = (t: string | null) => (t ? t.slice(0, 5) : "");

function planFrom(rules: AvailabilityRule[]): Record<number, DayPlan> {
  const out: Record<number, DayPlan> = {};
  for (const d of ORDER) {
    const rs = rules.filter((r) => r.kind === "weekly" && r.weekday === d);
    const open = rs.filter((r) => r.available);
    out[d] = rs.some((r) => !r.available && !r.start_time) || !open.length ? { mode: "off", periods: [{ from: "08:00", to: "18:00" }] }
      : open.some((r) => !r.start_time) ? { mode: "full", periods: [{ from: "08:00", to: "18:00" }] }
      : { mode: "hours", periods: open.map((r) => ({ from: hhmm(r.start_time), to: hhmm(r.end_time) })).sort((a, b) => a.from.localeCompare(b.from)) };
  }
  return out;
}

export function AvailabilityEditor({ car }: { car: { id: string; name: string; availability_mode: string } }) {
  const { t, locale } = useI18n();
  const qc = useQueryClient();
  const { data: rules = [], isLoading } = useCarRules(car.id);
  const [mode, setMode] = useState(car.availability_mode);
  const [plan, setPlan] = useState<Record<number, DayPlan>>(() => planFrom([]));
  const [saving, setSaving] = useState(false);
  useEffect(() => setPlan(planFrom(rules)), [rules]);
  useEffect(() => setMode(car.availability_mode), [car.availability_mode]);

  const refresh = () => {
    qc.invalidateQueries({ queryKey: ["avail-rules", car.id] });
    qc.invalidateQueries({ queryKey: ["car-calendar", car.id] });
    qc.invalidateQueries({ queryKey: ["owner-cars"] });
  };
  const dayName = (d: number) => new Date(Date.UTC(2024, 0, 7 + d)).toLocaleDateString(locale, { weekday: "long", timeZone: "UTC" });
  const exceptions = rules.filter((r) => r.kind === "dates" || (r.kind === "weekly" && !r.available && r.start_time));

  async function saveMode(m: string) {
    try { await call(supabase.rpc("owner_set_availability_mode", { _car: car.id, _mode: m })); setMode(m); toast.success(t("Mode enregistré", "Mode saved", "تم حفظ الوضع")); refresh(); }
    catch (e) { toast.error((e as Error).message); }
  }

  async function savePlan() {
    for (const d of ORDER) {
      const p = plan[d]!;
      if (p.mode === "hours" && (!p.periods.length || p.periods.some((x) => !x.from || !x.to || x.to <= x.from))) {
        toast.error(`${dayName(d)} : ${t("plages horaires invalides", "invalid time ranges", "فترات زمنية غير صالحة")}`);
        return;
      }
    }
    setSaving(true);
    try {
      const old = rules.filter((r) => r.kind === "weekly" && !(!r.available && r.start_time)).map((r) => r.id);
      const rows = ORDER.flatMap((d) => {
        const p = plan[d]!;
        if (p.mode === "off") return [{ car_id: car.id, kind: "weekly", available: false, weekday: d }];
        if (p.mode === "full") return [{ car_id: car.id, kind: "weekly", available: true, weekday: d }];
        return p.periods.map((x) => ({ car_id: car.id, kind: "weekly", available: true, weekday: d, start_time: x.from, end_time: x.to === "00:00" ? "24:00" : x.to }));
      });
      // Insert first so a failure never leaves the car without a schedule.
      await call(supabase.from("car_availability_rules").insert(rows));
      if (old.length) await call(supabase.from("car_availability_rules").delete().in("id", old));
      if (mode !== "schedule") await call(supabase.rpc("owner_set_availability_mode", { _car: car.id, _mode: "schedule" }));
      setMode("schedule");
      toast.success(t("Planning hebdomadaire enregistré", "Weekly schedule saved", "تم حفظ الجدول الأسبوعي"));
      refresh();
    } catch (e) {
      toast.error((e as Error).message);
    } finally {
      setSaving(false);
    }
  }

  async function addException(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fd = new FormData(form);
    const repeat = fd.get("repeat") === "weekly";
    const allDay = fd.get("all_day") === "on";
    const from = String(fd.get("from") ?? "");
    const to = String(fd.get("to") ?? "") || from;
    const start = String(fd.get("start") ?? "");
    const end = String(fd.get("end") ?? "");
    const available = !repeat && fd.get("type") === "available";
    if (!repeat && !from) { toast.error(t("Choisissez une date", "Pick a date", "اختر تاريخاً")); return; }
    if ((repeat || !allDay) && (!start || !end || end <= start)) { toast.error(t("Horaires invalides", "Invalid hours", "ساعات غير صالحة")); return; }
    const timed = repeat || !allDay;
    const row = {
      car_id: car.id, available, note: String(fd.get("note") ?? "").slice(0, 200),
      kind: repeat ? "weekly" : "dates",
      weekday: repeat ? Number(fd.get("weekday")) : null,
      date_from: repeat ? null : from,
      date_to: repeat ? null : to < from ? from : to,
      start_time: timed ? start : null,
      end_time: timed ? end : null,
    };
    try { await call(supabase.from("car_availability_rules").insert(row)); form.reset(); toast.success(t("Exception ajoutée", "Exception added", "تمت إضافة الاستثناء")); refresh(); }
    catch (err) { toast.error((err as Error).message); }
  }

  async function remove(id: string) {
    try { await call(supabase.from("car_availability_rules").delete().eq("id", id)); refresh(); }
    catch (e) { toast.error((e as Error).message); }
  }

  const setDay = (d: number, p: DayPlan) => setPlan((x) => ({ ...x, [d]: p }));

  return (
    <div className="avail-layout">
      <div className="registry">
        <h3 className="mb-3">{car.name}</h3>
        <div className="seg-choice" role="radiogroup">
          <button type="button" role="radio" aria-checked={mode === "always"} onClick={() => void saveMode("always")}>
            <strong>{t("Disponible tous les jours", "Available every day", "متاح كل يوم")}</strong>
            <small>{t("Toute la journée, sauf exceptions", "All day, except exceptions", "طوال اليوم باستثناء الاستثناءات")}</small>
          </button>
          <button type="button" role="radio" aria-checked={mode === "schedule"} onClick={() => void saveMode("schedule")}>
            <strong>{t("Selon mon planning", "Following my schedule", "حسب جدولي")}</strong>
            <small>{t("Jours et horaires ci-dessous, ou dates choisies", "Days and hours below, or chosen dates", "الأيام والساعات أدناه أو تواريخ محددة")}</small>
          </button>
        </div>

        {mode === "schedule" && (
          <div className="week-plan">
            {isLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : ORDER.map((d) => {
              const p = plan[d]!;
              return (
                <div key={d} className="week-row">
                  <strong>{dayName(d)}</strong>
                  <select className="admin-select" value={p.mode} onChange={(e) => setDay(d, { ...p, mode: e.target.value as DayPlan["mode"] })} aria-label={dayName(d)}>
                    <option value="full">{t("Toute la journée", "All day", "طوال اليوم")}</option>
                    <option value="hours">{t("Plages horaires", "Time ranges", "فترات زمنية")}</option>
                    <option value="off">{t("Indisponible", "Unavailable", "غير متاح")}</option>
                  </select>
                  {p.mode === "hours" && (
                    <div className="week-periods">
                      {p.periods.map((x, i) => (
                        <span key={i} className="period">
                          <input type="time" value={x.from} onChange={(e) => setDay(d, { ...p, periods: p.periods.map((y, j) => (j === i ? { ...y, from: e.target.value } : y)) })} aria-label={t("Début", "From", "من")} />
                          –
                          <input type="time" value={x.to} onChange={(e) => setDay(d, { ...p, periods: p.periods.map((y, j) => (j === i ? { ...y, to: e.target.value } : y)) })} aria-label={t("Fin", "To", "إلى")} />
                          {p.periods.length > 1 && <button type="button" className="icon-btn" aria-label={t("Retirer", "Remove", "إزالة")} onClick={() => setDay(d, { ...p, periods: p.periods.filter((_, j) => j !== i) })}><Trash2 /></button>}
                        </span>
                      ))}
                      {p.periods.length < 4 && <button type="button" className="tile-link !mt-0" onClick={() => setDay(d, { ...p, periods: [...p.periods, { from: "17:00", to: "22:00" }] })}><Plus className="h-4 w-4" />{t("Plage", "Range", "فترة")}</button>}
                    </div>
                  )}
                </div>
              );
            })}
            <Button className="ref-btn mt-4" disabled={saving} onClick={() => void savePlan()}>{saving ? t("Enregistrement…", "Saving…", "جارٍ الحفظ…") : t("Enregistrer le planning", "Save schedule", "حفظ الجدول")}</Button>
          </div>
        )}

        <h3 className="mt-8 mb-3">{t("Exceptions", "Exceptions", "الاستثناءات")}</h3>
        <form className="ref-form exception-form" onSubmit={addException}>
          <label className="form-field"><span>{t("Répétition", "Repeat", "التكرار")}</span>
            <select name="repeat" defaultValue="once"><option value="once">{t("Dates précises", "Specific dates", "تواريخ محددة")}</option><option value="weekly">{t("Chaque semaine (indisponible)", "Every week (unavailable)", "كل أسبوع (غير متاح)")}</option></select>
          </label>
          <label className="form-field"><span>{t("Type", "Type", "النوع")}</span>
            <select name="type" defaultValue="unavailable"><option value="unavailable">{t("Indisponible", "Unavailable", "غير متاح")}</option><option value="available">{t("Disponible (date spéciale)", "Available (special date)", "متاح (تاريخ خاص)")}</option></select>
          </label>
          <label className="form-field"><span>{t("Du", "From", "من")}</span><input type="date" name="from" /></label>
          <label className="form-field"><span>{t("Au (facultatif)", "To (optional)", "إلى (اختياري)")}</span><input type="date" name="to" /></label>
          <label className="form-field"><span>{t("Jour (si chaque semaine)", "Day (if weekly)", "اليوم (إذا أسبوعي)")}</span>
            <select name="weekday" defaultValue="5">{ORDER.map((d) => <option key={d} value={d}>{dayName(d)}</option>)}</select>
          </label>
          <label className="check-label self-end"><input type="checkbox" name="all_day" defaultChecked />{t("Toute la journée", "All day", "طوال اليوم")}</label>
          <label className="form-field"><span>{t("De", "From", "من")}</span><input type="time" name="start" defaultValue="08:00" /></label>
          <label className="form-field"><span>{t("À", "To", "إلى")}</span><input type="time" name="end" defaultValue="12:00" /></label>
          <label className="form-field form-wide"><span>{t("Note (facultatif)", "Note (optional)", "ملاحظة (اختياري)")}</span><input name="note" maxLength={200} placeholder={t("Entretien, congé…", "Maintenance, holiday…", "صيانة، عطلة…")} /></label>
          <Button className="ref-btn">{t("Ajouter l’exception", "Add exception", "إضافة الاستثناء")}</Button>
        </form>
        {exceptions.map((r) => (
          <div key={r.id} className="note-row flex items-center justify-between gap-3">
            <span>
              <strong className={r.available ? "text-primary" : "text-destructive"}>{r.available ? t("Disponible", "Available", "متاح") : t("Indisponible", "Unavailable", "غير متاح")}</strong>{" "}
              {r.kind === "weekly" ? `${t("chaque", "every", "كل")} ${dayName(r.weekday!)}` : r.date_from === r.date_to ? r.date_from : `${r.date_from} → ${r.date_to}`}
              {" · "}{r.start_time ? `${hhmm(r.start_time)}–${hhmm(r.end_time)}` : t("toute la journée", "all day", "طوال اليوم")}
              {r.note && <small className="block">{r.note}</small>}
            </span>
            <button type="button" className="icon-btn" aria-label={t("Supprimer", "Delete", "حذف")} onClick={() => void remove(r.id)}><Trash2 /></button>
          </div>
        ))}
      </div>
      <div className="registry">
        <h3 className="mb-3">{t("Calendrier", "Calendar", "التقويم")}</h3>
        <AvailabilityCalendar carId={car.id} mode={mode} rules={rules} />
      </div>
    </div>
  );
}
