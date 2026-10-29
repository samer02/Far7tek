import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { fetchCars } from "@/lib/cars";
import { ASSIGNMENT_STATUS, BOOKING_STATUS, CAR_VALIDATION, PARTNER_TRIP_TRANSITIONS, serviceLabel, vehicleTypeLabel } from "@/lib/platform";
import { addCarPhoto, respondAssignment, updateCarAvailability, updateTripStatus } from "@/lib/partner.functions";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";
import { labelOf, useI18n } from "@/lib/i18n";

export const Route = createFileRoute("/_authenticated/partenaire")({
  head: () => ({ meta: [{ title: "Espace partenaire — Far7tek" }, { name: "robots", content: "noindex" }] }),
  component: PartnerDashboard,
});

type Tab = "dashboard" | "requests" | "history" | "vehicle" | "profile" | "notifications";

function PartnerDashboard() {
  const { t, lang, date } = useI18n();
  const { data: auth, isLoading } = useAuth();
  const [tab, setTab] = useState<Tab>("dashboard");
  const qc = useQueryClient();
  const respond = useServerFn(respondAssignment);
  const moveTrip = useServerFn(updateTripStatus);

  const TABS: [Tab, string][] = [
    ["dashboard", t("Tableau de bord", "Dashboard", "لوحة التحكم")],
    ["requests", t("Demandes", "Requests", "الطلبات")],
    ["history", t("Historique", "History", "السجل")],
    ["vehicle", t("Mon véhicule", "My vehicle", "سيارتي")],
    ["profile", t("Profil", "Profile", "الملف الشخصي")],
    ["notifications", t("Notifications", "Notifications", "الإشعارات")],
  ];

  const uid = auth?.userId;
  const { data: items = [] } = useQuery({
    queryKey: ["partner-assignments", uid],
    enabled: !!uid,
    queryFn: async () => {
      const { data: as } = await supabase.from("trip_assignments").select("*").eq("partner_id", uid!).order("created_at", { ascending: false });
      const ids = (as ?? []).map((a) => a.booking_request_id);
      const { data: bs } = ids.length ? await supabase.from("booking_requests").select("*").in("id", ids) : { data: [] };
      return (as ?? []).map((a) => ({ a, b: (bs ?? []).find((b) => b.id === a.booking_request_id) })).filter((x) => x.b);
    },
  });

  if (isLoading) return <div className="container-ref section-ref">{t("Chargement…", "Loading…", "جارٍ التحميل…")}</div>;
  if (!auth?.roles.includes("partner"))
    return (
      <div className="auth-panel">
        <h1>{t("Espace partenaire", "Partner area", "فضاء الشريك")}</h1>
        <p>{t("Cet espace est réservé aux propriétaires dont le dossier a été accepté.", "This area is reserved for owners whose application has been accepted.", "هذا الفضاء مخصص للملاك الذين قُبلت ملفاتهم.")}</p>
        <Button asChild className="ref-btn"><Link to="/devenir-partenaire">{t("Proposer ma voiture", "List my car", "اعرض سيارتك")}</Link></Button>
      </div>
    );

  const refresh = () => qc.invalidateQueries({ queryKey: ["partner-assignments"] });
  async function act(fn: () => Promise<unknown>, msg: string) {
    try { await fn(); toast.success(msg); refresh(); } catch (e) { toast.error((e as Error).message); }
  }

  const active = items.filter((x) => x.a.status !== "rejected");
  const today = new Date().toISOString().slice(0, 10);
  const kpis = [
    [t("Demandes reçues", "Requests received", "الطلبات المستلمة"), items.length],
    [t("En attente de réponse", "Awaiting your reply", "بانتظار ردك"), items.filter((x) => x.a.status === "proposed").length],
    [t("Acceptées", "Accepted", "المقبولة"), active.filter((x) => x.a.status === "accepted").length],
    [t("Refusées / annulées", "Declined / cancelled", "المرفوضة / الملغاة"), items.filter((x) => x.a.status === "rejected" || x.b!.status === "cancelled").length],
    [t("Prochains trajets", "Upcoming trips", "الرحلات القادمة"), active.filter((x) => x.a.status === "accepted" && x.b!.wedding_date >= today && ["accepted", "confirmed"].includes(x.b!.status)).length],
    [t("Terminés", "Completed", "المنتهية"), items.filter((x) => x.b!.status === "completed").length],
  ] as const;

  const list = (rows: typeof items) =>
    !rows.length ? <p className="admin-empty registry">{t("Aucune demande.", "No requests.", "لا توجد طلبات.")}</p> : (
      <div className="admin-list-grid">
        {rows.map(({ a, b }) => (
          <div key={a.id} className="admin-list-card">
            <div className="car-meta"><span>{t("Réf.", "Ref.", "مرجع")} {b!.reference}</span><StatusPill label={a.status === "accepted" ? labelOf(BOOKING_STATUS, b!.status, lang) : labelOf(ASSIGNMENT_STATUS, a.status, lang)} /></div>
            <h3>{b!.first_name} {b!.last_name}</h3>
            <p>
              {serviceLabel(b!.service_type, lang)} · {b!.trip_type === "round_trip" ? t("Aller-retour", "Round trip", "ذهاب وإياب") : t("Aller simple", "One way", "ذهاب فقط")}<br />
              {date(b!.wedding_date)} · {b!.wedding_time.slice(0, 5)}{b!.return_time ? ` → ${t("retour", "return", "العودة")} ${b!.return_time.slice(0, 5)}` : ""}<br />
              {b!.pickup_address} → {b!.venue} ({b!.city})<br />
              {b!.passengers} {t("passager(s)", "passenger(s)", "راكب")}{b!.message ? ` · ${b!.message}` : ""}<br />
              {a.status === "accepted"
                ? <>{t("Tél. client", "Client phone", "هاتف العميل")} : <a href={`tel:${b!.phone}`} className="text-primary font-semibold" dir="ltr">{b!.phone}</a></>
                : t("Téléphone visible après acceptation", "Phone visible after accepting", "يظهر الهاتف بعد القبول")}
            </p>
            {a.rejection_reason && <p className="form-error">{t("Motif", "Reason", "السبب")} : {a.rejection_reason}</p>}
            <div className="action-row">
              {a.status === "proposed" && (
                <>
                  <Button className="ref-btn" onClick={() => act(() => respond({ data: { id: a.id, accept: true, reason: "" } }), t("Demande acceptée", "Request accepted", "تم قبول الطلب"))}>{t("Accepter", "Accept", "قبول")}</Button>
                  <Button variant="outline" className="ref-btn" onClick={() => {
                    const reason = window.prompt(t("Motif du refus ?", "Reason for declining?", "سبب الرفض؟"))?.trim();
                    if (reason) act(() => respond({ data: { id: a.id, accept: false, reason } }), t("Demande refusée", "Request declined", "تم رفض الطلب"));
                  }}>{t("Refuser", "Decline", "رفض")}</Button>
                </>
              )}
              {a.status === "accepted" && (PARTNER_TRIP_TRANSITIONS[b!.status] ?? []).map((s) => (
                <Button key={s} variant={s === "cancelled" ? "outline" : "default"} className="ref-btn"
                  onClick={() => act(() => moveTrip({ data: { bookingId: b!.id, status: s as "confirmed" | "in_progress" | "completed" | "cancelled" } }), t("Statut mis à jour", "Status updated", "تم تحديث الحالة"))}>
                  {labelOf(BOOKING_STATUS, s, lang)}
                </Button>
              ))}
            </div>
          </div>
        ))}
      </div>
    );

  const isHistory = (x: (typeof items)[number]) => x.a.status === "rejected" || ["completed", "cancelled"].includes(x.b!.status);

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header"><div><span className="eyebrow">{t("Espace partenaire", "Partner area", "فضاء الشريك")}</span><h1>{t("Bonjour 👋", "Hello 👋", "مرحباً 👋")}</h1><p dir="ltr" className="text-start">{auth.email}</p></div></div>
        <div className="registry-tabs mb-6">
          {TABS.map(([k, l]) => <Button key={k} variant={k === tab ? "default" : "ghost"} className="ref-btn" onClick={() => setTab(k)}>{l}</Button>)}
        </div>
        {tab === "dashboard" && (
          <>
            <div className="kpi-grid">{kpis.map(([l, v]) => <div key={l} className="kpi"><div className="kpi-label">{l}</div><div className="kpi-value">{v}</div></div>)}</div>
            <h3 className="mb-4">{t("À traiter", "To handle", "للمعالجة")}</h3>
            {list(items.filter((x) => x.a.status === "proposed" || (x.a.status === "accepted" && !isHistory(x))))}
          </>
        )}
        {tab === "requests" && list(items.filter((x) => !isHistory(x)))}
        {tab === "history" && list(items.filter(isHistory))}
        {tab === "vehicle" && <PartnerVehicle uid={uid!} />}
        {tab === "profile" && <PartnerProfile uid={uid!} />}
        {tab === "notifications" && <NotificationsPanel />}
      </div>
    </section>
  );
}

function PartnerVehicle({ uid }: { uid: string }) {
  const { t, lang, date } = useI18n();
  const qc = useQueryClient();
  const saveAvail = useServerFn(updateCarAvailability);
  const savePhoto = useServerFn(addCarPhoto);
  const { data: cars = [] } = useQuery({ queryKey: ["my-cars", uid], queryFn: () => fetchCars({ ownerId: uid }) });
  const { data: changes = [] } = useQuery({
    queryKey: ["my-changes", uid],
    queryFn: async () => (await supabase.from("vehicle_change_requests").select("*").order("created_at", { ascending: false })).data ?? [],
  });
  if (!cars.length) return <p className="admin-empty registry">{t("Votre véhicule est en cours de création par l’équipe.", "Your vehicle is being set up by the team.", "يقوم الفريق بإعداد سيارتك.")}</p>;
  const car = cars[0]!;
  const validation = (car as unknown as { validation_status: string }).validation_status;

  async function upload(files: FileList | null) {
    for (const f of [...(files ?? [])]) {
      if (!f.type.startsWith("image/") || f.size > 8 * 1024 * 1024) { toast.error(t("Image de 8 Mo max.", "Images up to 8 MB.", "صورة بحجم 8 ميغابايت كحد أقصى.")); continue; }
      const path = `${uid}/${car.id}/${crypto.randomUUID()}.${f.name.split(".").pop()}`;
      const up = await supabase.storage.from("car-images").upload(path, f, { contentType: f.type });
      if (up.error) { toast.error(t("Envoi impossible", "Upload failed", "تعذّر الإرسال")); continue; }
      await savePhoto({ data: { carId: car.id, path } });
    }
    toast.success(t("Photos ajoutées", "Photos added", "تمت إضافة الصور"));
    qc.invalidateQueries({ queryKey: ["my-cars"] });
  }

  async function submitChange(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const color = String(fd.get("color") ?? "");
    const seats = String(fd.get("seats") ?? "");
    const priceFrom = String(fd.get("price_from") ?? "");
    const description = String(fd.get("description") ?? "");
    const changes: Record<string, unknown> = {};
    if (color && color !== car.color) changes["color"] = color.slice(0, 40);
    if (seats && Number(seats) !== car.seats) changes["seats"] = Math.max(1, Math.min(60, Number(seats)));
    if (priceFrom && Number(priceFrom) !== car.price_from) changes["price_from"] = Number(priceFrom);
    if (description && description !== car.description) changes["description"] = description.slice(0, 2000);
    if (!Object.keys(changes).length) { toast.info(t("Aucune modification", "No changes", "لا توجد تعديلات")); return; }
    const { error } = await supabase.from("vehicle_change_requests").insert({ car_id: car.id, partner_id: uid, changes: changes as never });
    if (error) { toast.error(t("Envoi impossible", "Sending failed", "تعذّر الإرسال")); return; }
    toast.success(t("Modification envoyée pour validation", "Change sent for approval", "تم إرسال التعديل للموافقة"));
    qc.invalidateQueries({ queryKey: ["my-changes"] });
  }

  const changeStatus = (s: string) => (s === "pending" ? t("En attente", "Pending", "قيد الانتظار") : s === "approved" ? t("Validée", "Approved", "مقبول") : t("Refusée", "Declined", "مرفوض"));

  return (
    <div className="dossier">
      <div className="car-meta"><span>{vehicleTypeLabel(car.category, lang)}</span><StatusPill label={labelOf(CAR_VALIDATION, validation, lang)} /></div>
      <h3>{car.name}</h3>
      <div className="admin-photo-strip">{car.images.map((u) => <img key={u} src={u} alt={car.name} />)}</div>
      <label className="ref-btn inline-flex cursor-pointer items-center border border-border">
        {t("Ajouter des photos", "Add photos", "إضافة صور")}<input type="file" accept="image/*" multiple className="sr-only" onChange={(e) => upload(e.target.files)} />
      </label>
      <form className="ref-form mt-6" onSubmit={async (e): Promise<void> => {
        e.preventDefault();
        const v = String(new FormData(e.currentTarget).get("availability") ?? "");
        try { await saveAvail({ data: { carId: car.id, availability: v } }); toast.success(t("Disponibilités mises à jour", "Availability updated", "تم تحديث التوفر")); qc.invalidateQueries({ queryKey: ["my-cars"] }); } catch (err) { toast.error((err as Error).message); }
      }}>
        <label className="form-field form-wide"><span>{t("Disponibilités", "Availability", "التوفر")}</span><input name="availability" defaultValue={car.availability} /></label>
        <Button className="ref-btn">{t("Enregistrer les disponibilités", "Save availability", "حفظ التوفر")}</Button>
      </form>
      <form className="ref-form form-section" onSubmit={submitChange}>
        <h3 className="form-wide">{t("Modifications soumises à validation", "Changes subject to approval", "تعديلات تخضع للموافقة")}</h3>
        <label className="form-field"><span>{t("Couleur", "Colour", "اللون")}</span><input name="color" defaultValue={car.color ?? ""} /></label>
        <label className="form-field"><span>{t("Places", "Seats", "المقاعد")}</span><input name="seats" type="number" defaultValue={car.seats ?? 4} /></label>
        <label className="form-field"><span>{t("Tarif indicatif (DT)", "Indicative price (DT)", "السعر التقريبي (د.ت)")}</span><input name="price_from" type="number" defaultValue={car.price_from ?? 0} /></label>
        <label className="form-field form-wide"><span>{t("Description", "Description", "الوصف")}</span><textarea name="description" defaultValue={car.description} /></label>
        <Button className="ref-btn">{t("Soumettre à l’administration", "Submit to the admin team", "إرسال إلى الإدارة")}</Button>
      </form>
      {changes.map((c) => <div key={c.id} className="note-row"><small>{date(c.created_at)} · {changeStatus(c.status)}</small> {Object.keys(c.changes as object).join(", ")}</div>)}
    </div>
  );
}

function PartnerProfile({ uid }: { uid: string }) {
  const { t } = useI18n();
  const { data: p } = useQuery({ queryKey: ["profile", uid], queryFn: async () => (await supabase.from("profiles").select("*").eq("id", uid).maybeSingle()).data });
  return (
    <div className="admin-edit-grid">
      <form key={p?.id ?? "x"} className="dossier ref-form" onSubmit={async (e): Promise<void> => {
        e.preventDefault();
        const fd = new FormData(e.currentTarget);
        const { error } = await supabase.from("profiles").upsert({
          id: uid,
          first_name: String(fd.get("first_name") ?? "").slice(0, 80),
          last_name: String(fd.get("last_name") ?? "").slice(0, 80),
          phone: String(fd.get("phone") ?? "").slice(0, 20),
        });
        if (error) toast.error(t("Enregistrement impossible", "Could not save", "تعذّر الحفظ"));
        else toast.success(t("Profil enregistré", "Profile saved", "تم حفظ الملف"));
      }}>
        <h3 className="form-wide">{t("Profil et coordonnées", "Profile and contact", "الملف ومعلومات الاتصال")}</h3>
        <label className="form-field"><span>{t("Prénom", "First name", "الاسم")}</span><input name="first_name" defaultValue={p?.first_name ?? ""} /></label>
        <label className="form-field"><span>{t("Nom", "Last name", "اللقب")}</span><input name="last_name" defaultValue={p?.last_name ?? ""} /></label>
        <label className="form-field form-wide"><span>{t("Téléphone", "Phone", "الهاتف")}</span><input name="phone" defaultValue={p?.phone ?? ""} dir="ltr" /></label>
        <Button className="ref-btn">{t("Enregistrer", "Save", "حفظ")}</Button>
      </form>
      <form className="dossier ref-form" onSubmit={async (e): Promise<void> => {
        e.preventDefault();
        const form = e.currentTarget;
        const pw = String(new FormData(form).get("password"));
        if (pw.length < 8) { toast.error(t("8 caractères minimum", "8 characters minimum", "8 أحرف على الأقل")); return; }
        const { error } = await supabase.auth.updateUser({ password: pw });
        if (error) toast.error(error.message);
        else toast.success(t("Mot de passe modifié", "Password changed", "تم تغيير كلمة المرور"));
        form.reset();
      }}>
        <h3 className="form-wide">{t("Sécurité du compte", "Account security", "أمان الحساب")}</h3>
        <label className="form-field form-wide"><span>{t("Nouveau mot de passe", "New password", "كلمة المرور الجديدة")}</span><input name="password" type="password" autoComplete="new-password" dir="ltr" /></label>
        <Button className="ref-btn">{t("Changer le mot de passe", "Change password", "تغيير كلمة المرور")}</Button>
      </form>
    </div>
  );
}
