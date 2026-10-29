import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { z } from "zod";
import { CheckCircle2, Car, MapPin, User } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { fetchCars } from "@/lib/cars";
import { SERVICE_TYPES, VEHICLE_TYPES } from "@/lib/platform";
import { useI18n } from "@/lib/i18n";

export const Route = createFileRoute("/reserver")({
  validateSearch: (s: Record<string, unknown>): { car?: string } => (typeof s["car"] === "string" ? { car: s["car"] } : {}),
  head: () => ({
    meta: [
      { title: "Réserver une voiture avec chauffeur — Far7tek" },
      { name: "description", content: "Demandez une voiture avec chauffeur pour un mariage, un transport familial ou un aller-retour avec Far7tek." },
      { property: "og:title", content: "Réserver une voiture avec chauffeur — Far7tek" },
      { property: "og:description", content: "Mariage, transport familial vers la salle des fêtes, aller-retour." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Booking,
});

type T = (fr: string, en: string, ar: string) => string;

function makeSchema(t: T) {
  return z
    .object({
      first_name: z.string().trim().min(1, t("Prénom requis", "First name required", "الاسم مطلوب")).max(80),
      last_name: z.string().trim().min(1, t("Nom requis", "Last name required", "اللقب مطلوب")).max(80),
      phone: z.string().trim().regex(/^[+0-9 .()-]{6,20}$/, t("Téléphone invalide", "Invalid phone", "رقم هاتف غير صالح")),
      service_type: z.enum(["wedding", "family", "round_trip", "private"]),
      city: z.string().trim().min(1, t("Ville requise", "City required", "المدينة مطلوبة")).max(80),
      pickup_address: z.string().trim().min(3, t("Adresse de départ requise", "Pick-up address required", "عنوان الانطلاق مطلوب")).max(250),
      destination_type: z.string().min(1),
      venue: z.string().trim().min(3, t("Destination requise", "Destination required", "الوجهة مطلوبة")).max(250),
      wedding_date: z.string().min(1, t("Date requise", "Date required", "التاريخ مطلوب")),
      wedding_time: z.string().min(1, t("Heure de départ requise", "Departure time required", "ساعة الانطلاق مطلوبة")),
      return_time: z.string().optional(),
      passengers: z.coerce.number().int().min(1, t("Au moins 1 passager", "At least 1 passenger", "راكب واحد على الأقل")).max(60),
      vehicle_type: z.string().max(80),
      trip_type: z.enum(["one_way", "round_trip"]),
      car_name: z.string().max(120),
      message: z.string().trim().max(1500),
    })
    .refine((d) => d.trip_type === "one_way" || !!d.return_time, { message: t("Heure de retour requise pour un aller-retour", "Return time required for a round trip", "ساعة العودة مطلوبة للذهاب والإياب"), path: ["return_time"] })
    .refine((d) => d.wedding_date >= new Date().toISOString().slice(0, 10), { message: t("La date doit être à venir", "Date must be in the future", "يجب أن يكون التاريخ قادماً"), path: ["wedding_date"] });
}

function Booking() {
  const { t, p } = useI18n();
  const { car } = Route.useSearch();
  const { data: auth, isLoading } = useAuth();
  const { data: cars } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const qc = useQueryClient();
  const [service, setService] = useState("wedding");
  const [trip, setTrip] = useState("one_way");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<string | null>(null);
  const schema = useMemo(() => makeSchema(t), [t]);

  const isRound = service === "round_trip" || trip === "round_trip";
  const selected = cars?.find((c) => c.slug === car);
  const none = t("Sans préférence", "No preference", "بدون تفضيل");

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const raw = Object.fromEntries(new FormData(e.currentTarget));
    if (service === "round_trip") raw["trip_type"] = "round_trip";
    const parsed = schema.safeParse(raw);
    if (!parsed.success) {
      setErrors(Object.fromEntries(parsed.error.issues.map((i) => [i.path[0], i.message])));
      return;
    }
    setErrors({});
    setBusy(true);
    const d = parsed.data;
    const { data: row, error } = await supabase
      .from("booking_requests")
      .insert({
        ...d,
        return_time: d.trip_type === "round_trip" ? (d.return_time ?? null) : null,
        car_name: d.car_name || "Sans préférence",
        car_id: cars?.find((c) => c.name === d.car_name)?.id ?? null,
        email: auth!.email ?? "",
        client_id: auth!.userId,
        status: "pending",
      })
      .select("reference")
      .single();
    setBusy(false);
    if (error) { setErrors({ form: t("L’envoi a échoué, merci de réessayer.", "Sending failed, please try again.", "فشل الإرسال، يرجى المحاولة مجدداً.") }); return; }
    qc.invalidateQueries({ queryKey: ["my-requests"] });
    setDone(row.reference);
  }

  const err = (k: string) => errors[k] && <span className="form-error">{errors[k]}</span>;

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading center">
          <span className="eyebrow">{t("Réservation", "Booking", "الحجز")}</span>
          <h1>{t("Réserver une voiture avec chauffeur", "Book a car with a driver", "احجز سيارة مع سائق")}</h1>
          <p>{t(
            "Mariage, transport de vos proches vers la salle des fêtes ou trajet privé : décrivez votre besoin, un responsable vous recontacte.",
            "Wedding, family transport to the venue or a private trip: tell us what you need and a manager will get back to you.",
            "عرس، نقل العائلة إلى قاعة الأفراح أو رحلة خاصة: صف حاجتك وسيتصل بك مسؤول.",
          )}</p>
        </div>
        <div className="form-panel">
          {done ? (
            <div className="confirmation">
              <CheckCircle2 />
              <h3>{t("Votre demande a bien été envoyée.", "Your request has been sent.", "تم إرسال طلبك بنجاح.")}</h3>
              <p>
                {t("Référence", "Reference", "المرجع")} <strong className="text-primary">{done}</strong>.{" "}
                {t(
                  "Notre équipe vous contactera dans un délai maximum de 24 heures pour confirmer votre demande.",
                  "Our team will contact you within 24 hours at most to confirm your request.",
                  "سيتواصل معك فريقنا خلال 24 ساعة كحد أقصى لتأكيد طلبك.",
                )}
              </p>
              <div className="action-row justify-center mt-6">
                <Button asChild className="ref-btn"><Link to="/compte">{t("Suivre ma demande", "Track my request", "تتبع طلبي")}</Link></Button>
              </div>
            </div>
          ) : isLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : !auth?.userId ? (
            <div className="confirmation">
              <User />
              <h3>{t("Connectez-vous pour réserver", "Sign in to book", "سجّل الدخول للحجز")}</h3>
              <p>{t("Un compte vous permet de suivre le statut de votre demande à tout moment.", "An account lets you follow your request status at any time.", "يتيح لك الحساب متابعة حالة طلبك في أي وقت.")}</p>
              <div className="action-row justify-center mt-6">
                <Button asChild className="ref-btn"><Link to="/auth" search={{ redirect: "/reserver" }}>{t("Se connecter ou créer un compte", "Sign in or create an account", "دخول أو إنشاء حساب")}</Link></Button>
              </div>
            </div>
          ) : (
            <form onSubmit={submit} noValidate>
              <div className="form-section">
                <h3><Car />{t("Le service", "The service", "الخدمة")}</h3>
                <div className="ref-form">
                  <label className="form-field form-wide"><span>{t("Type de service", "Service type", "نوع الخدمة")}</span>
                    <select name="service_type" value={service} onChange={(e) => setService(e.target.value)}>
                      {SERVICE_TYPES.map((s) => <option key={s.value} value={s.value}>{p(s.label)}</option>)}
                    </select>
                  </label>
                  {service !== "round_trip" && (
                    <label className="form-field"><span>{t("Nombre de trajets", "Trips", "عدد الرحلات")}</span>
                      <select name="trip_type" value={trip} onChange={(e) => setTrip(e.target.value)}>
                        <option value="one_way">{t("Aller simple", "One way", "ذهاب فقط")}</option>
                        <option value="round_trip">{t("Aller-retour", "Round trip", "ذهاب وإياب")}</option>
                      </select>
                    </label>
                  )}
                  <label className="form-field"><span>{t("Nombre de passagers", "Passengers", "عدد الركاب")}</span><input name="passengers" type="number" min={1} defaultValue={service === "wedding" ? 2 : 4} />{err("passengers")}</label>
                  <label className="form-field"><span>{t("Type de voiture souhaité", "Preferred car type", "نوع السيارة المفضل")}</span>
                    <select name="vehicle_type" defaultValue={selected?.category ?? ""}>
                      <option value="">{none}</option>
                      {VEHICLE_TYPES.map((v) => <option key={v.value} value={v.value}>{p(v.label)}</option>)}
                    </select>
                  </label>
                  <label className="form-field"><span>{t("Véhicule précis (facultatif)", "Specific vehicle (optional)", "سيارة محددة (اختياري)")}</span>
                    <select name="car_name" defaultValue={selected?.name ?? ""}>
                      <option value="">{none}</option>
                      {(cars ?? []).map((c) => <option key={c.id} value={c.name}>{c.name}</option>)}
                    </select>
                  </label>
                </div>
              </div>
              <div className="form-section">
                <h3><MapPin />{t("Trajet et horaires", "Route and times", "المسار والمواعيد")}</h3>
                <div className="ref-form">
                  <label className="form-field form-wide"><span>{t("Adresse de départ", "Pick-up address", "عنوان الانطلاق")}</span><input name="pickup_address" placeholder={service === "wedding" ? t("Domicile ou lieu de préparation", "Home or preparation venue", "الدار أو مكان التحضير") : t("Votre domicile", "Your home", "دارك")} />{err("pickup_address")}</label>
                  <label className="form-field"><span>{t("Destination", "Destination", "الوجهة")}</span>
                    <select name="destination_type" defaultValue={service === "family" || service === "round_trip" ? "salle" : "autre"}>
                      <option value="salle">{t("Salle des fêtes", "Wedding venue", "قاعة الأفراح")}</option>
                      <option value="mairie">{t("Mairie / lieu de cérémonie", "Town hall / ceremony", "البلدية / مكان الحفل")}</option>
                      <option value="domicile">{t("Domicile", "Home", "الدار")}</option>
                      <option value="autre">{t("Autre lieu", "Other place", "مكان آخر")}</option>
                    </select>
                  </label>
                  <label className="form-field"><span>{t("Ville", "City", "المدينة")}</span><input name="city" />{err("city")}</label>
                  <label className="form-field form-wide"><span>{t("Adresse de destination", "Destination address", "عنوان الوجهة")}</span><input name="venue" placeholder={t("Nom et adresse de la salle ou du lieu", "Venue name and address", "اسم وعنوان القاعة أو المكان")} />{err("venue")}</label>
                  <label className="form-field"><span>{t("Date du service", "Service date", "تاريخ الخدمة")}</span><input name="wedding_date" type="date" />{err("wedding_date")}</label>
                  <label className="form-field"><span>{t("Heure de départ", "Departure time", "ساعة الانطلاق")}</span><input name="wedding_time" type="time" />{err("wedding_time")}</label>
                  {isRound && (
                    <label className="form-field"><span>{t("Heure de retour", "Return time", "ساعة العودة")}</span><input name="return_time" type="time" />{err("return_time")}</label>
                  )}
                </div>
              </div>
              <div className="form-section">
                <h3><User />{t("Vos coordonnées", "Your details", "معلوماتك")}</h3>
                <div className="ref-form">
                  <label className="form-field"><span>{t("Prénom", "First name", "الاسم")}</span><input name="first_name" autoComplete="given-name" />{err("first_name")}</label>
                  <label className="form-field"><span>{t("Nom", "Last name", "اللقب")}</span><input name="last_name" autoComplete="family-name" />{err("last_name")}</label>
                  <label className="form-field"><span>{t("Téléphone", "Phone", "الهاتف")}</span><input name="phone" type="tel" autoComplete="tel" dir="ltr" />{err("phone")}</label>
                  <label className="form-field"><span>{t("E-mail", "Email", "البريد الإلكتروني")}</span><input value={auth.email ?? ""} disabled dir="ltr" /></label>
                  <label className="form-field form-wide"><span>{t("Informations supplémentaires", "Additional information", "معلومات إضافية")}</span><textarea name="message" placeholder={t("Décoration, sièges enfants, arrêts intermédiaires…", "Decoration, child seats, extra stops…", "تزيين، مقاعد أطفال، توقفات إضافية…")} /></label>
                </div>
              </div>
              {err("form")}
              <Button type="submit" className="ref-btn mt-8 w-full" disabled={busy}>{busy ? t("Envoi en cours…", "Sending…", "جارٍ الإرسال…") : t("Envoyer ma demande", "Send my request", "أرسل طلبي")}</Button>
            </form>
          )}
        </div>
      </div>
    </section>
  );
}
