import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useServerFn } from "@tanstack/react-start";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { fetchCars, type CarView } from "@/lib/cars";
import { ASSIGNMENT_STATUS, BOOKING_STATUS, CAR_VALIDATION, PARTNER_TRIP_TRANSITIONS, serviceLabel, vehicleTypeLabel } from "@/lib/platform";
import { addCarPhoto, respondAssignment, updateCarAvailability, updateTripStatus } from "@/lib/partner.functions";
import { call, useLiveRefresh, type OwnerOperation } from "@/lib/transport";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";
import { ColorPalette, NumberInput } from "@/components/form-inputs";
import { AvailabilityEditor } from "@/components/owner/availability-editor";
import { OperationCard } from "@/components/owner/operation-card";
import { labelOf, useI18n } from "@/lib/i18n";

export const Route = createFileRoute("/_authenticated/partenaire")({
  head: () => ({ meta: [{ title: "Espace partenaire — Far7tek" }, { name: "robots", content: "noindex" }] }),
  component: PartnerDashboard,
});

type Tab = "dashboard" | "operations" | "availability" | "cars" | "legacy" | "profile" | "notifications";
type OpFilter = "incoming" | "approved" | "upcoming" | "active" | "completed";
type OwnerCar = CarView & { availability_mode: string; validation_status: string };

const OP_FILTERS: Record<OpFilter, (o: OwnerOperation) => boolean> = {
  incoming: (o) => o.status === "awaiting_owner",
  approved: (o) => o.status === "approved",
  upcoming: (o) => o.status === "confirmed",
  active: (o) => o.status === "in_progress",
  completed: (o) => o.status === "completed" || o.status === "cancelled",
};

function PartnerDashboard() {
  const { t } = useI18n();
  const { data: auth, isLoading } = useAuth();
  const [tab, setTab] = useState<Tab>("dashboard");
  const [filter, setFilter] = useState<OpFilter>("incoming");
  const qc = useQueryClient();
  const uid = auth?.userId;
  const isOwner = !!auth?.roles.includes("partner");

  const { data: ops = [], isLoading: opsLoading } = useQuery({
    queryKey: ["owner-ops", uid],
    enabled: isOwner,
    refetchInterval: 30_000,
    queryFn: () => call<OwnerOperation[]>(supabase.rpc("owner_transport_operations")),
  });
  const { data: cars = [] } = useQuery({ queryKey: ["owner-cars", uid], enabled: isOwner, queryFn: async () => (await fetchCars({ ownerId: uid! })) as OwnerCar[] });
  const { data: legacy = [] } = useQuery({
    queryKey: ["partner-assignments", uid],
    enabled: isOwner,
    queryFn: async () => {
      const { data: as } = await supabase.from("trip_assignments").select("*").eq("partner_id", uid!).order("created_at", { ascending: false });
      const ids = (as ?? []).map((a) => a.booking_request_id);
      const { data: bs } = ids.length ? await supabase.from("booking_requests").select("*").in("id", ids) : { data: [] };
      return (as ?? []).map((a) => ({ a, b: (bs ?? []).find((b) => b.id === a.booking_request_id) })).filter((x) => x.b);
    },
  });
  const refreshOps = () => qc.invalidateQueries({ queryKey: ["owner-ops"] });
  useLiveRefresh("owner-stages", [{ table: "journey_stages" }], refreshOps, isOwner, 60_000);

  if (isLoading) return <div className="container-ref section-ref">{t("Chargement…", "Loading…", "جارٍ التحميل…")}</div>;
  if (!isOwner)
    return (
      <div className="auth-panel">
        <h1>{t("Espace partenaire", "Partner area", "فضاء الشريك")}</h1>
        <p>{t("Cet espace est réservé aux propriétaires dont le dossier a été accepté.", "This area is reserved for owners whose application has been accepted.", "هذا الفضاء مخصص للملاك الذين قُبلت ملفاتهم.")}</p>
        <Button asChild className="ref-btn"><Link to="/devenir-partenaire">{t("Proposer ma voiture", "List my car", "اعرض سيارتك")}</Link></Button>
      </div>
    );

  const count = (f: OpFilter) => ops.filter(OP_FILTERS[f]).length;
  const FILTER_LABEL: Record<OpFilter, string> = {
    incoming: t("À confirmer", "Incoming", "بانتظار تأكيدك"),
    approved: t("Validées", "Approved", "المعتمدة"),
    upcoming: t("À venir", "Upcoming", "القادمة"),
    active: t("En cours", "Active", "الجارية"),
    completed: t("Terminées", "Completed", "المنتهية"),
  };
  const TABS: [Tab, string][] = [
    ["dashboard", t("Tableau de bord", "Dashboard", "لوحة التحكم")],
    ["operations", t("Réservations", "Bookings", "الحجوزات")],
    ["availability", t("Disponibilités", "Availability", "التوفر")],
    ["cars", t("Mes voitures", "My cars", "سياراتي")],
    ...(legacy.length ? [["legacy", t("Anciennes demandes", "Earlier requests", "طلبات سابقة")] as [Tab, string]] : []),
    ["profile", t("Profil", "Profile", "الملف الشخصي")],
    ["notifications", t("Notifications", "Notifications", "الإشعارات")],
  ];
  const activeOps = ops.filter(OP_FILTERS.active);
  const todo = ops.filter((o) => OP_FILTERS.incoming(o) || OP_FILTERS.approved(o));
  const next = ops.filter(OP_FILTERS.upcoming).slice(0, 3);
  const cards = (rows: OwnerOperation[], empty: string) =>
    !rows.length ? <p className="admin-empty registry">{empty}</p> : <div className="op-grid">{rows.map((o) => <OperationCard key={o.id} op={o} onChanged={refreshOps} />)}</div>;

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header"><div><span className="eyebrow">{t("Espace partenaire", "Partner area", "فضاء الشريك")}</span><h1>{t("Bonjour 👋", "Hello 👋", "مرحباً 👋")}</h1><p dir="ltr" className="text-start">{auth!.email}</p></div></div>
        <div className="registry-tabs mb-6">
          {TABS.map(([k, l]) => <Button key={k} variant={k === tab ? "default" : "ghost"} className="ref-btn" onClick={() => setTab(k)}>{l}</Button>)}
        </div>
        {tab === "dashboard" && (
          <>
            <div className="kpi-grid">
              {(Object.keys(OP_FILTERS) as OpFilter[]).map((f) => (
                <button key={f} type="button" className="kpi text-start" onClick={() => { setFilter(f); setTab("operations"); }}>
                  <div className="kpi-label">{FILTER_LABEL[f]}</div><div className="kpi-value">{count(f)}</div>
                </button>
              ))}
              <button type="button" className="kpi text-start" onClick={() => setTab("cars")}>
                <div className="kpi-label">{t("Mes voitures", "My cars", "سياراتي")}</div><div className="kpi-value">{cars.length}</div>
              </button>
            </div>
            {opsLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : (
              <>
                {activeOps.length > 0 && <><h3 className="mb-4">{t("Opération en cours", "Active operation", "عملية جارية")}</h3>{cards(activeOps, "")}</>}
                <h3 className="mb-4 mt-8">{t("À traiter", "To handle", "للمعالجة")}</h3>
                {cards(todo, t("Aucune réservation à confirmer.", "No booking to confirm.", "لا توجد حجوزات للتأكيد."))}
                <h3 className="mb-4 mt-8">{t("Prochaines réservations", "Next bookings", "الحجوزات القادمة")}</h3>
                {cards(next, t("Aucune réservation confirmée à venir.", "No upcoming confirmed booking.", "لا توجد حجوزات مؤكدة قادمة."))}
              </>
            )}
          </>
        )}
        {tab === "operations" && (
          <>
            <div className="registry-tabs mb-6">
              {(Object.keys(OP_FILTERS) as OpFilter[]).map((f) => (
                <Button key={f} variant={f === filter ? "default" : "ghost"} className="ref-btn" onClick={() => setFilter(f)}>{FILTER_LABEL[f]} ({count(f)})</Button>
              ))}
            </div>
            {cards(ops.filter(OP_FILTERS[filter]), t("Aucune réservation dans cette liste.", "No booking in this list.", "لا توجد حجوزات في هذه القائمة."))}
          </>
        )}
        {tab === "availability" && <OwnerAvailability cars={cars} />}
        {tab === "cars" && (!cars.length
          ? <p className="admin-empty registry">{t("Votre véhicule est en cours de création par l’équipe.", "Your vehicle is being set up by the team.", "يقوم الفريق بإعداد سيارتك.")}</p>
          : cars.map((c) => <PartnerVehicle key={c.id} uid={uid!} car={c} />))}
        {tab === "legacy" && <LegacyAssignments items={legacy} />}
        {tab === "profile" && <PartnerProfile uid={uid!} />}
        {tab === "notifications" && <NotificationsPanel />}
      </div>
    </section>
  );
}

function OwnerAvailability({ cars }: { cars: OwnerCar[] }) {
  const { t } = useI18n();
  const [id, setId] = useState<string | null>(null);
  const car = cars.find((c) => c.id === id) ?? cars[0];
  if (!car) return <p className="admin-empty registry">{t("Aucun véhicule.", "No vehicle.", "لا توجد سيارة.")}</p>;
  return (
    <>
      {cars.length > 1 && (
        <div className="registry-tabs mb-6">
          {cars.map((c) => <Button key={c.id} variant={c.id === car.id ? "default" : "ghost"} className="ref-btn" onClick={() => setId(c.id)}>{c.name}</Button>)}
        </div>
      )}
      <AvailabilityEditor key={car.id} car={car} />
    </>
  );
}

type LegacyItem = { a: { id: string; status: string; rejection_reason: string | null }; b: Record<string, any> | undefined };

/** Requests assigned through the previous assignment flow, still answerable until they are closed. */
function LegacyAssignments({ items }: { items: LegacyItem[] }) {
  const { t, lang, date } = useI18n();
  const qc = useQueryClient();
  const respond = useServerFn(respondAssignment);
  const moveTrip = useServerFn(updateTripStatus);
  const refresh = () => qc.invalidateQueries({ queryKey: ["partner-assignments"] });
  async function act(fn: () => Promise<unknown>, msg: string) {
    try { await fn(); toast.success(msg); refresh(); } catch (e) { toast.error((e as Error).message); }
  }
  return (
    <div className="admin-list-grid">
      {items.map(({ a, b }) => (
        <div key={a.id} className="admin-list-card">
          <div className="car-meta"><span>{t("Réf.", "Ref.", "مرجع")} {b!["reference"]}</span><StatusPill label={a.status === "accepted" ? labelOf(BOOKING_STATUS, b!["status"], lang) : labelOf(ASSIGNMENT_STATUS, a.status, lang)} /></div>
          <h3>{b!["first_name"]} {b!["last_name"]}</h3>
          <p>
            {serviceLabel(b!["service_type"], lang)} · {date(b!["wedding_date"])} · {String(b!["wedding_time"]).slice(0, 5)}<br />
            {b!["pickup_address"]} → {b!["venue"]} ({b!["city"]})<br />
            {a.status === "accepted"
              ? <>{t("Tél. client", "Client phone", "هاتف العميل")} : <a href={`tel:${b!["phone"]}`} className="text-primary font-semibold" dir="ltr">{b!["phone"]}</a></>
              : t("Téléphone visible après acceptation", "Phone visible after accepting", "يظهر الهاتف بعد القبول")}
          </p>
          {a.rejection_reason && <p className="form-error">{t("Motif", "Reason", "السبب")} : {a.rejection_reason}</p>}
          <div className="action-row">
            {a.status === "proposed" && (
              <>
                <Button className="ref-btn" onClick={() => act(async () => { try { await respond({ data: { id: a.id, accept: true, reason: "" } }); } catch { const { error } = await supabase.rpc("partner_respond_assignment", { _id: a.id, _accept: true, _reason: "" }); if (error) throw error; } }, t("Demande acceptée", "Request accepted", "تم قبول الطلب"))}>{t("Accepter", "Accept", "قبول")}</Button>
                <Button variant="outline" className="ref-btn" onClick={() => {
                  const reason = window.prompt(t("Motif du refus ?", "Reason for declining?", "سبب الرفض؟"))?.trim();
                  if (reason) act(async () => { try { await respond({ data: { id: a.id, accept: false, reason } }); } catch { const { error } = await supabase.rpc("partner_respond_assignment", { _id: a.id, _accept: false, _reason: reason }); if (error) throw error; } }, t("Demande refusée", "Request declined", "تم رفض الطلب"));
                }}>{t("Refuser", "Decline", "رفض")}</Button>
              </>
            )}
            {a.status === "accepted" && (PARTNER_TRIP_TRANSITIONS[b!["status"]] ?? []).map((s) => (
              <Button key={s} variant={s === "cancelled" ? "outline" : "default"} className="ref-btn"
                onClick={() => act(async () => { try { await moveTrip({ data: { bookingId: b!["id"], status: s as "confirmed" | "in_progress" | "completed" | "cancelled" } }); } catch { const { error } = await supabase.rpc("partner_update_trip_status", { _booking: b!["id"], _status: s }); if (error) throw error; } }, t("Statut mis à jour", "Status updated", "تم تحديث الحالة"))}>
                {labelOf(BOOKING_STATUS, s, lang)}
              </Button>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function PartnerVehicle({ uid, car }: { uid: string; car: OwnerCar }) {
  const { t, lang, date } = useI18n();
  const qc = useQueryClient();
  const saveAvail = useServerFn(updateCarAvailability);
  const savePhoto = useServerFn(addCarPhoto);
  const { data: changes = [] } = useQuery({
    queryKey: ["my-changes", car.id],
    queryFn: async () => (await supabase.from("vehicle_change_requests").select("*").eq("car_id", car.id).order("created_at", { ascending: false })).data ?? [],
  });
  const refreshCars = () => qc.invalidateQueries({ queryKey: ["owner-cars"] });

  async function upload(files: FileList | null) {
    for (const f of [...(files ?? [])]) {
      if (!f.type.startsWith("image/") || f.size > 8 * 1024 * 1024) { toast.error(t("Image de 8 Mo max.", "Images up to 8 MB.", "صورة بحجم 8 ميغابايت كحد أقصى.")); continue; }
      const path = `${uid}/${car.id}/${crypto.randomUUID()}.${f.name.split(".").pop()}`;
      const up = await supabase.storage.from("car-images").upload(path, f, { contentType: f.type });
      if (up.error) { toast.error(t("Envoi impossible", "Upload failed", "تعذّر الإرسال")); continue; }
      try { await savePhoto({ data: { carId: car.id, path } }); } catch { const { error } = await supabase.rpc("partner_add_car_photo", { _car: car.id, _path: path }); if (error) { toast.error(t("Envoi impossible", "Upload failed", "تعذّر الإرسال")); continue; } }
    }
    toast.success(t("Photos ajoutées", "Photos added", "تمت إضافة الصور"));
    refreshCars();
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
    qc.invalidateQueries({ queryKey: ["my-changes", car.id] });
  }

  const changeStatus = (s: string) => (s === "pending" ? t("En attente", "Pending", "قيد الانتظار") : s === "approved" ? t("Validée", "Approved", "مقبول") : t("Refusée", "Declined", "مرفوض"));

  return (
    <div className="dossier">
      <div className="car-meta"><span>{vehicleTypeLabel(car.category, lang)}</span><StatusPill label={labelOf(CAR_VALIDATION, car.validation_status, lang)} /></div>
      <h3>{car.name}</h3>
      <div className="admin-photo-strip">{car.images.map((u) => <img key={u} src={u} alt={car.name} />)}</div>
      <label className="ref-btn inline-flex cursor-pointer items-center border border-border">
        {t("Ajouter des photos", "Add photos", "إضافة صور")}<input type="file" accept="image/*" multiple className="sr-only" onChange={(e) => upload(e.target.files)} />
      </label>
      <form className="ref-form mt-6" onSubmit={async (e): Promise<void> => {
        e.preventDefault();
        const v = String(new FormData(e.currentTarget).get("availability") ?? "");
        try { await saveAvail({ data: { carId: car.id, availability: v } }); toast.success(t("Disponibilités mises à jour", "Availability updated", "تم تحديث التوفر")); refreshCars(); } catch { try { const { error } = await supabase.rpc("partner_update_car_availability", { _car: car.id, _availability: v }); if (error) throw error; toast.success(t("Disponibilités mises à jour", "Availability updated", "تم تحديث التوفر")); refreshCars(); } catch (err) { toast.error((err as Error).message); } }
      }}>
        <label className="form-field form-wide"><span>{t("Texte de disponibilité affiché", "Displayed availability text", "نص التوفر المعروض")}</span><input name="availability" defaultValue={car.availability} /></label>
        <Button className="ref-btn">{t("Enregistrer", "Save", "حفظ")}</Button>
      </form>
      <form className="ref-form form-section" onSubmit={submitChange}>
        <h3 className="form-wide">{t("Modifications soumises à validation", "Changes subject to approval", "تعديلات تخضع للموافقة")}</h3>
        <div className="form-field form-wide"><span>{t("Couleur", "Colour", "اللون")}</span><ColorPalette name="color" defaultValue={car.color ?? ""} /></div>
        <label className="form-field"><span>{t("Places", "Seats", "المقاعد")}</span><NumberInput name="seats" maxLength={2} defaultValue={car.seats ?? ""} placeholder="4" /></label>
        <label className="form-field"><span>{t("Tarif indicatif (DT)", "Indicative price (DT)", "السعر التقريبي (د.ت)")}</span><NumberInput name="price_from" maxLength={6} defaultValue={car.price_from ?? ""} placeholder={t("0 DT", "0 DT", "0 د.ت")} /></label>
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
        <label className="form-field form-wide"><span>{t("Téléphone (visible uniquement par l’équipe Far7tek)", "Phone (only visible to the Far7tek team)", "الهاتف (يظهر لفريق فرحتك فقط)")}</span><input name="phone" defaultValue={p?.phone ?? ""} dir="ltr" /></label>
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
