import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { z } from "zod";
import { CalendarClock, Car, CheckCircle2, Heart, MapPin, MessageSquareText, User, Users } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useHydrated } from "@/lib/use-hydrated";
import { useAuth } from "@/lib/use-auth";
import { fetchCars } from "@/lib/cars";
import { CAR_CATEGORIES, carInCategory, primaryCategory, type CarCategory } from "@/lib/platform";
import { call, tunisDay, tunisInstant } from "@/lib/transport";
import { LocationPicker, type Journey } from "@/components/transport/location-picker";
import { NumberInput } from "@/components/form-inputs";
import { useI18n } from "@/lib/i18n";

type Search = { car?: string; type?: CarCategory };

export const Route = createFileRoute("/reserver")({
  validateSearch: (s: Record<string, unknown>): Search => ({
    ...(typeof s["car"] === "string" ? { car: s["car"] } : {}),
    ...(s["type"] === "wedding" || s["type"] === "family" ? { type: s["type"] } : {}),
  }),
  head: () => ({
    meta: [
      { title: "Demande de transport avec chauffeur — Far7tek" },
      { name: "description", content: "Demandez une voiture des mariés ou un transport familial avec chauffeur. Notre équipe valide la disponibilité avant confirmation." },
      { property: "og:title", content: "Demande de transport avec chauffeur — Far7tek" },
      { property: "og:description", content: "Voiture des mariés, transport familial, aller-retour vers la salle des fêtes." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Booking,
});

type T = (fr: string, en: string, ar: string) => string;
const ICONS = { wedding: Heart, family: Users } as const;

function makeSchema(t: T) {
  return z
    .object({
      first_name: z.string().trim().min(1, t("Prénom requis", "First name required", "الاسم مطلوب")).max(80),
      last_name: z.string().trim().min(1, t("Nom requis", "Last name required", "اللقب مطلوب")).max(80),
      phone: z.string().trim().regex(/^[+0-9 .()-]{6,20}$/, t("Téléphone invalide", "Invalid phone", "رقم هاتف غير صالح")),
      contact_extra: z.string().trim().max(300),
      city: z.string().trim().min(1, t("Ville requise", "City required", "المدينة مطلوبة")).max(80),
      destination_type: z.string().min(1),
      date: z.string().min(1, t("Date requise", "Date required", "التاريخ مطلوب")),
      time: z.string().min(1, t("Heure de départ requise", "Departure time required", "ساعة الانطلاق مطلوبة")),
      return_time: z.string().optional(),
      round_trip: z.boolean(),
      passengers: z.coerce.number().int().min(1, t("Au moins 1 passager", "At least 1 passenger", "راكب واحد على الأقل")).max(60, t("60 passagers maximum", "60 passengers maximum", "60 راكباً كحد أقصى")),
      requirements: z.string().trim().max(1500),
      client_notes: z.string().trim().max(1500),
    })
    .refine((d) => !d.round_trip || !!d.return_time, { message: t("Heure de retour requise pour un aller-retour", "Return time required for a round trip", "ساعة العودة مطلوبة للذهاب والإياب"), path: ["return_time"] })
    .refine((d) => d.date >= tunisDay(new Date()), { message: t("La date doit être à venir", "Date must be in the future", "يجب أن يكون التاريخ قادماً"), path: ["date"] });
}

function Booking() {
  const { t, p } = useI18n();
  const search = Route.useSearch();
  const { data: auth, isLoading } = useAuth();
  const { data: cars } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const { data: profile, isLoading: profileLoading } = useQuery({
    queryKey: ["my-profile", auth?.userId],
    enabled: !!auth?.userId,
    queryFn: async () => (await supabase.from("profiles").select("first_name,last_name,phone").eq("id", auth!.userId!).maybeSingle()).data,
  });
  const qc = useQueryClient();
  const hydrated = useHydrated();
  const preset = cars?.find((c) => c.slug === search.car);
  const [category, setCategory] = useState<CarCategory | null>(search.type ?? null);
  const cat: CarCategory = category ?? primaryCategory(preset?.services) ?? "wedding";
  const [carId, setCarId] = useState<string | null>(null);
  const chosenId = carId ?? (preset && carInCategory(preset.services, cat) ? preset.id : "");
  const car = cars?.find((c) => c.id === chosenId) ?? null;
  const [round, setRound] = useState(false);
  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  const [ret, setRet] = useState("");
  const [journey, setJourney] = useState<Journey>({ pickup: null, destination: null, stops: [] });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<string | null>(null);
  const schema = useMemo(() => makeSchema(t), [t]);
  const options = (cars ?? []).filter((c) => carInCategory(c.services, cat));

  const window_ = useMemo(() => {
    if (!date || !time || (round && !ret)) return null;
    const start = tunisInstant(date, time);
    let end: string;
    if (round) {
      const back = new Date(tunisInstant(date, ret));
      if (ret <= time) back.setUTCDate(back.getUTCDate() + 1);
      end = new Date(back.getTime() + 90 * 60_000).toISOString();
    } else end = new Date(new Date(start).getTime() + 3 * 3_600_000).toISOString();
    return { start, end };
  }, [date, time, ret, round]);
  const { data: availability } = useQuery({
    queryKey: ["window-status", chosenId, window_?.start, window_?.end],
    enabled: !!chosenId && !!window_ && !!auth?.userId,
    queryFn: () => call<string>(supabase.rpc("car_window_status", { _car: chosenId, _start: window_!.start, _end: window_!.end })),
  });

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (busy) return;
    const raw = { ...Object.fromEntries(new FormData(e.currentTarget)), round_trip: round, date, time, return_time: ret };
    const parsed = schema.safeParse(raw);
    const errs: Record<string, string> = parsed.success ? {} : Object.fromEntries(parsed.error.issues.map((i) => [String(i.path[0]), i.message]));
    if (!journey.pickup) errs["pickup"] = t("Placez le point de départ sur la carte", "Place the pick-up point on the map", "حدد نقطة الانطلاق على الخريطة");
    if (!journey.destination) errs["destination"] = t("Placez la destination sur la carte", "Place the destination on the map", "حدد الوجهة على الخريطة");
    if (parsed.success && car?.seats && parsed.data.passengers > car.seats)
      errs["passengers"] = t(`Ce véhicule a ${car.seats} places`, `This vehicle has ${car.seats} seats`, `هذه السيارة تتسع لـ ${car.seats} مقاعد`);
    if (availability === "booked") errs["form"] = t("Ce véhicule est déjà réservé sur ce créneau. Choisissez un autre horaire ou véhicule.", "This vehicle is already booked for that time. Pick another time or vehicle.", "هذه السيارة محجوزة في هذا الموعد. اختر وقتاً أو سيارة أخرى.");
    if (!parsed.success || Object.keys(errs).length) { setErrors(errs); return; }
    setErrors({});
    setBusy(true);
    const d = parsed.data;
    try {
      const res = await call<{ reference: string }>(supabase.rpc("transport_submit_request", {
        _data: {
          category: cat, car_id: chosenId || null, date: d.date, time: d.time, round_trip: d.round_trip, return_time: d.round_trip ? d.return_time ?? "" : "",
          passengers: d.passengers, first_name: d.first_name, last_name: d.last_name, phone: d.phone, city: d.city,
          pickup_address: journey.pickup!.address, pickup_lat: journey.pickup!.lat, pickup_lng: journey.pickup!.lng,
          destination_address: journey.destination!.address, destination_lat: journey.destination!.lat, destination_lng: journey.destination!.lng,
          destination_type: d.destination_type, stops: journey.stops.map((s) => ({ address: s.address, lat: s.lat, lng: s.lng })),
          requirements: d.requirements, client_notes: d.client_notes, contact_extra: d.contact_extra,
        },
      }));
      qc.invalidateQueries({ queryKey: ["my-requests"] });
      setDone(res.reference);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      setErrors({ form: (err as Error).message || t("L’envoi a échoué, merci de réessayer.", "Sending failed, please try again.", "فشل الإرسال، يرجى المحاولة مجدداً.") });
    } finally {
      setBusy(false);
    }
  }

  const err = (k: string) => errors[k] && <span className="form-error">{errors[k]}</span>;
  const pickCategory = (c: CarCategory) => { setCategory(c); if (car && !carInCategory(car.services, c)) setCarId(""); };

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading center">
          <span className="eyebrow">{t("Demande de transport", "Transport request", "طلب نقل")}</span>
          <h1>{t("Demander une voiture avec chauffeur", "Request a car with a driver", "اطلب سيارة مع سائق")}</h1>
          <p>{t(
            "Décrivez votre besoin : notre équipe vérifie la disponibilité avec le propriétaire, puis valide votre demande. Rien n’est réservé avant cette validation.",
            "Describe what you need: our team checks availability with the owner, then approves your request. Nothing is booked before that.",
            "صف حاجتك: يتحقق فريقنا من التوفر مع المالك ثم يوافق على طلبك. لا يتم أي حجز قبل ذلك.",
          )}</p>
        </div>
        <div className="form-panel form-panel-wide">
          {done ? (
            <div className="confirmation">
              <CheckCircle2 />
              <h3>{t("Votre demande a bien été envoyée.", "Your request has been sent.", "تم إرسال طلبك بنجاح.")}</h3>
              <p>
                {t("Référence", "Reference", "المرجع")} <strong className="text-primary">{done}</strong>.{" "}
                {t(
                  "Elle est en attente de validation. Vous suivrez chaque étape (étude, validation, confirmation, trajet) depuis votre espace.",
                  "It is pending review. You can follow every step (review, approval, confirmation, journey) from your account.",
                  "الطلب قيد المراجعة. يمكنك متابعة كل مرحلة (المراجعة، الموافقة، التأكيد، الرحلة) من حسابك.",
                )}
              </p>
              <div className="action-row justify-center mt-6">
                <Button asChild className="ref-btn"><Link to="/compte">{t("Suivre ma demande", "Track my request", "تتبع طلبي")}</Link></Button>
              </div>
            </div>
          ) : isLoading || (auth?.userId && profileLoading) ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : !auth?.userId ? (
            <div className="confirmation">
              <User />
              <h3>{t("Connectez-vous pour faire une demande", "Sign in to send a request", "سجّل الدخول لإرسال طلب")}</h3>
              <p>{t("Un compte vous permet de suivre le statut de votre demande et votre trajet à tout moment.", "An account lets you follow your request and your journey at any time.", "يتيح لك الحساب متابعة طلبك ورحلتك في أي وقت.")}</p>
              <div className="action-row justify-center mt-6">
                <Button asChild className="ref-btn"><Link to="/auth" search={{ redirect: "/reserver" }}>{t("Se connecter ou créer un compte", "Sign in or create an account", "دخول أو إنشاء حساب")}</Link></Button>
              </div>
            </div>
          ) : (
            <form onSubmit={submit} noValidate>
              <div className="form-section">
                <h3><Car />{t("Catégorie et véhicule", "Category and vehicle", "الفئة والسيارة")}</h3>
                <div className="cat-choice" role="radiogroup" aria-label={t("Catégorie", "Category", "الفئة")}>
                  {CAR_CATEGORIES.map((c) => {
                    const Icon = ICONS[c.value];
                    return (
                      <button key={c.value} type="button" role="radio" aria-checked={cat === c.value} data-cat={c.value} onClick={() => pickCategory(c.value)}>
                        <Icon /><strong>{p(c.label)}</strong>
                      </button>
                    );
                  })}
                </div>
                <div className="ref-form mt-5">
                  <label className="form-field form-wide"><span>{t("Véhicule souhaité", "Preferred vehicle", "السيارة المطلوبة")}</span>
                    <select value={chosenId} onChange={(e) => setCarId(e.target.value)}>
                      <option value="">{t("Sans préférence — l’équipe propose un véhicule", "No preference — the team will suggest one", "بدون تفضيل — سيقترح الفريق سيارة")}</option>
                      {options.map((c) => <option key={c.id} value={c.id}>{c.name}{c.seats ? ` · ${c.seats} ${t("places", "seats", "مقاعد")}` : ""}</option>)}
                    </select>
                  </label>
                  {car && (
                    <div className="form-wide picked-car">
                      <img src={car.images[0]} alt="" />
                      <div>
                        <strong>{car.name}</strong>
                        <small>{[car.brand, car.model, car.year].filter(Boolean).join(" · ")}{car.seats ? ` · ${car.seats} ${t("places", "seats", "مقاعد")}` : ""}</small>
                        <Link to="/vehicules/$slug" params={{ slug: car.slug }} className="tile-link !mt-1">{t("Voir la fiche", "View details", "عرض التفاصيل")}</Link>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              <div className="form-section">
                <h3><CalendarClock />{t("Date et horaires", "Date and times", "التاريخ والمواعيد")}</h3>
                <div className="ref-form">
                  <label className="form-field"><span>{t("Date du service", "Service date", "تاريخ الخدمة")}</span><input type="date" min={hydrated ? tunisDay(new Date()) : undefined} value={date} onChange={(e) => setDate(e.target.value)} />{err("date")}</label>
                  <label className="form-field"><span>{t("Heure de départ", "Departure time", "ساعة الانطلاق")}</span><input type="time" value={time} onChange={(e) => setTime(e.target.value)} />{err("time")}</label>
                  <label className="form-field"><span>{t("Trajet", "Trip", "الرحلة")}</span>
                    <select value={round ? "round_trip" : "one_way"} onChange={(e) => setRound(e.target.value === "round_trip")}>
                      <option value="one_way">{t("Aller simple", "One way", "ذهاب فقط")}</option>
                      <option value="round_trip">{t("Aller-retour (2 parties)", "Round trip (2 parts)", "ذهاب وإياب (جزءان)")}</option>
                    </select>
                  </label>
                  {round && <label className="form-field"><span>{t("Heure du retour", "Return time", "ساعة العودة")}</span><input type="time" value={ret} onChange={(e) => setRet(e.target.value)} />{err("return_time")}</label>}
                  <label className="form-field"><span>{t("Nombre de passagers", "Passengers", "عدد الركاب")}</span><NumberInput name="passengers" maxLength={2} placeholder={cat === "wedding" ? "2" : "4"} />{err("passengers")}</label>
                  {chosenId && window_ && availability && (
                    <div className={`avail-note form-wide is-${availability}`} role="status">
                      {availability === "available" ? t("Le véhicule semble disponible sur ce créneau. La disponibilité sera confirmée par notre équipe.", "The vehicle looks available for this slot. Our team will confirm it.", "تبدو السيارة متاحة في هذا الموعد. سيؤكد فريقنا ذلك.")
                        : availability === "booked" ? t("Ce véhicule est déjà réservé sur ce créneau.", "This vehicle is already booked for this slot.", "هذه السيارة محجوزة في هذا الموعد.")
                        : availability === "unavailable" ? t("Le propriétaire n’a pas indiqué de disponibilité sur ce créneau. Vous pouvez envoyer la demande : l’équipe vérifiera ou proposera une alternative.", "The owner hasn't marked this slot as available. You can still send the request: the team will check or suggest an alternative.", "لم يحدد المالك توفراً في هذا الموعد. يمكنك إرسال الطلب وسيتحقق الفريق أو يقترح بديلاً.")
                        : t("Disponibilité à confirmer par l’équipe.", "Availability to be confirmed by the team.", "التوفر سيؤكده الفريق.")}
                    </div>
                  )}
                </div>
              </div>

              <div className="form-section">
                <h3><MapPin />{t("Itinéraire", "Route", "المسار")}</h3>
                <LocationPicker value={journey} onChange={setJourney} errors={errors} />
                <div className="ref-form mt-5">
                  <label className="form-field"><span>{t("Type de destination", "Destination type", "نوع الوجهة")}</span>
                    <select name="destination_type" defaultValue={cat === "family" ? "salle" : "autre"}>
                      <option value="salle">{t("Salle des fêtes", "Wedding venue", "قاعة الأفراح")}</option>
                      <option value="mairie">{t("Mairie / lieu de cérémonie", "Town hall / ceremony", "البلدية / مكان الحفل")}</option>
                      <option value="domicile">{t("Domicile", "Home", "الدار")}</option>
                      <option value="autre">{t("Autre lieu", "Other place", "مكان آخر")}</option>
                    </select>
                  </label>
                  <label className="form-field"><span>{t("Ville", "City", "المدينة")}</span><input name="city" maxLength={80} />{err("city")}</label>
                </div>
              </div>

              <div className="form-section">
                <h3><MessageSquareText />{t("Besoins et remarques", "Requirements and notes", "المتطلبات والملاحظات")}</h3>
                <div className="ref-form">
                  <label className="form-field form-wide"><span>{t("Besoins particuliers", "Special requirements", "متطلبات خاصة")}</span>
                    <textarea name="requirements" maxLength={1500} placeholder={t("Décoration florale, rubans, siège enfant, musique…", "Flower decoration, ribbons, child seat, music…", "تزيين بالورود، أشرطة، مقعد أطفال، موسيقى…")} />{err("requirements")}
                  </label>
                  <label className="form-field form-wide"><span>{t("Note pour l’équipe Far7tek (non transmise au propriétaire)", "Note for the Far7tek team (not shared with the owner)", "ملاحظة لفريق فرحتك (لا تُرسل إلى المالك)")}</span>
                    <textarea name="client_notes" maxLength={1500} />{err("client_notes")}
                  </label>
                </div>
              </div>

              <div className="form-section">
                <h3><User />{t("Vos coordonnées", "Your details", "معلوماتك")}</h3>
                <div className="ref-form">
                  <label className="form-field"><span>{t("Prénom", "First name", "الاسم")}</span><input name="first_name" autoComplete="given-name" defaultValue={profile?.first_name ?? ""} />{err("first_name")}</label>
                  <label className="form-field"><span>{t("Nom", "Last name", "اللقب")}</span><input name="last_name" autoComplete="family-name" defaultValue={profile?.last_name ?? ""} />{err("last_name")}</label>
                  <label className="form-field"><span>{t("Téléphone", "Phone", "الهاتف")}</span><input name="phone" type="tel" autoComplete="tel" dir="ltr" defaultValue={profile?.phone ?? ""} />{err("phone")}</label>
                  <label className="form-field"><span>{t("E-mail", "Email", "البريد الإلكتروني")}</span><input value={auth.email ?? ""} disabled dir="ltr" /></label>
                  <label className="form-field form-wide"><span>{t("Autre contact le jour J (facultatif)", "Other contact on the day (optional)", "جهة اتصال أخرى يوم الحفل (اختياري)")}</span>
                    <input name="contact_extra" maxLength={300} placeholder={t("Nom et téléphone d’un proche", "Name and phone of a relative", "اسم وهاتف أحد الأقارب")} />{err("contact_extra")}
                  </label>
                </div>
              </div>
              {err("form")}
              <Button type="submit" className="ref-btn bg-primary mt-8 w-full" disabled={busy || !hydrated || availability === "booked"}>
                {busy ? t("Envoi en cours…", "Sending…", "جارٍ الإرسال…") : t("Envoyer ma demande", "Send my request", "أرسل طلبي")}
              </Button>
            </form>
          )}
        </div>
      </div>
    </section>
  );
}
