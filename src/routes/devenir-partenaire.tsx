import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { z } from "zod";
import { CheckCircle2, ImagePlus, User, Car, Camera } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { PARTNER_SERVICES, VEHICLE_TYPES } from "@/lib/platform";
import { useI18n } from "@/lib/i18n";

export const Route = createFileRoute("/devenir-partenaire")({
  head: () => ({
    meta: [
      { title: "Devenir partenaire — Proposer ma voiture | Far7tek" },
      { name: "description", content: "Propriétaire d’une voiture de prestige ou familiale ? Rejoignez le réseau de partenaires Far7tek." },
      { property: "og:title", content: "Devenir partenaire Far7tek — Proposer ma voiture" },
      { property: "og:description", content: "Soumettez votre véhicule pour les mariages et le transport de personnes." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: PartnerApply,
});

type T = (fr: string, en: string, ar: string) => string;

function makeSchema(t: T) {
  return z.object({
    first_name: z.string().trim().min(1, t("Prénom requis", "First name required", "الاسم مطلوب")).max(80),
    last_name: z.string().trim().min(1, t("Nom requis", "Last name required", "اللقب مطلوب")).max(80),
    phone: z.string().trim().regex(/^[+0-9 .()-]{6,20}$/, t("Téléphone invalide", "Invalid phone", "رقم هاتف غير صالح")),
    email: z.string().trim().email(t("E-mail invalide", "Invalid email", "بريد إلكتروني غير صالح")).max(255),
    city: z.string().trim().min(1, t("Ville requise", "City required", "المدينة مطلوبة")).max(80),
    address: z.string().trim().min(3, t("Adresse requise", "Address required", "العنوان مطلوب")).max(250),
    extra_info: z.string().trim().max(1000),
    brand: z.string().trim().min(1, t("Marque requise", "Brand required", "العلامة مطلوبة")).max(60),
    model: z.string().trim().min(1, t("Modèle requis", "Model required", "الطراز مطلوب")).max(60),
    year: z.coerce.number().int().min(1920, t("Année invalide", "Invalid year", "سنة غير صالحة")).max(new Date().getFullYear() + 1, t("Année invalide", "Invalid year", "سنة غير صالحة")),
    color: z.string().trim().min(1, t("Couleur requise", "Colour required", "اللون مطلوب")).max(40),
    vehicle_type: z.string().min(1, t("Type requis", "Type required", "النوع مطلوب")),
    seats: z.coerce.number().int().min(1).max(60),
    vehicle_condition: z.string().min(1, t("État requis", "Condition required", "الحالة مطلوبة")),
    availability: z.string().trim().min(2, t("Disponibilités requises", "Availability required", "التوفر مطلوب")).max(300),
    desired_rate: z.coerce.number().min(0).max(100000).default(0),
    description: z.string().trim().min(20, t("Décrivez le véhicule (20 caractères min.)", "Describe the vehicle (20 characters min.)", "صف السيارة (20 حرفاً على الأقل)")).max(2000),
  });
}

type Kind = "main" | "exterior" | "interior" | "document";
const MAX = 8 * 1024 * 1024;

function PartnerApply() {
  const { t, p } = useI18n();
  const schema = useMemo(() => makeSchema(t), [t]);
  const [files, setFiles] = useState<{ kind: Kind; file: File; url: string }[]>([]);
  const [services, setServices] = useState<string[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  const conditions = [
    ["Excellent", t("Excellent", "Excellent", "ممتازة")],
    ["Très bon", t("Très bon", "Very good", "جيدة جداً")],
    ["Bon", t("Bon", "Good", "جيدة")],
  ] as const;

  function add(kind: Kind, list: FileList | null) {
    if (!list) return;
    const ok = [...list].filter((f) => f.size <= MAX && (kind === "document" || f.type.startsWith("image/")));
    if (ok.length < list.length) setErrors((e) => ({ ...e, files: t("Certains fichiers ont été ignorés (image, 8 Mo max).", "Some files were skipped (images, 8 MB max).", "تم تجاهل بعض الملفات (صور، 8 ميغابايت كحد أقصى).") }));
    const mapped = ok.map((file) => ({ kind, file, url: URL.createObjectURL(file) }));
    setFiles((cur) => (kind === "main" ? [...cur.filter((f) => f.kind !== "main"), ...mapped.slice(0, 1)] : [...cur, ...mapped]));
  }

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const parsed = schema.safeParse(Object.fromEntries(new FormData(e.currentTarget)));
    const errs: Record<string, string> = {};
    if (!parsed.success) parsed.error.issues.forEach((i) => (errs[i.path[0] as string] = i.message));
    if (!services.length) errs["services"] = t("Choisissez au moins un service", "Choose at least one service", "اختر خدمة واحدة على الأقل");
    if (!files.some((f) => f.kind === "main")) errs["files"] = t("La photo principale est requise", "The main photo is required", "الصورة الرئيسية مطلوبة");
    setErrors(errs);
    if (Object.keys(errs).length || !parsed.success) return;
    setBusy(true);
    const id = crypto.randomUUID();
    const { error } = await supabase.from("car_proposals").insert({ id, ...parsed.data, services, travel_zone: parsed.data.city, schedules: parsed.data.availability, status: "pending" });
    if (error) { setBusy(false); setErrors({ form: t("L’envoi a échoué, merci de réessayer.", "Sending failed, please try again.", "فشل الإرسال، يرجى المحاولة مجدداً.") }); return; }
    for (const f of files) {
      const ext = f.file.name.split(".").pop()?.toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
      const path = `${id}/${f.kind}-${crypto.randomUUID()}.${ext}`;
      const up = await supabase.storage.from("proposal-images").upload(path, f.file, { contentType: f.file.type });
      if (!up.error) await supabase.from("proposal_images").insert({ proposal_id: id, storage_path: path, kind: f.kind });
    }
    setBusy(false);
    setDone(true);
  }

  const err = (k: string) => errors[k] && <span className="form-error">{errors[k]}</span>;
  const kindLabel = (k: Kind) =>
    k === "main" ? t("Principale", "Main", "رئيسية") : k === "exterior" ? t("Extérieur", "Exterior", "خارجية") : k === "interior" ? t("Intérieur", "Interior", "داخلية") : t("Document", "Document", "وثيقة");
  const tile = (kind: Kind, label: string, multiple = true) => (
    <label className="upload-tile">
      <input type="file" className="sr-only" accept={kind === "document" ? "image/*,application/pdf" : "image/*"} multiple={multiple} onChange={(e) => add(kind, e.target.files)} />
      <ImagePlus /><span>{label}</span>
    </label>
  );

  if (done)
    return (
      <section className="section-ref"><div className="container-ref"><div className="form-panel confirmation">
        <CheckCircle2 />
        <h3>{t("Dossier envoyé", "Application sent", "تم إرسال الملف")}</h3>
        <p>{t(
          "Merci ! Votre dossier est en attente et sera examiné par notre équipe. Si votre candidature est acceptée, vous recevrez par e-mail une invitation pour créer votre mot de passe et accéder à votre espace partenaire.",
          "Thank you! Your application is pending and will be reviewed by our team. If it is accepted, you will receive an email invitation to create your password and access your partner area.",
          "شكراً! ملفك قيد الانتظار وسيدرسه فريقنا. في حال قبوله، ستصلك دعوة عبر البريد الإلكتروني لإنشاء كلمة المرور والدخول إلى فضاء الشريك.",
        )}</p>
      </div></div></section>
    );

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading center">
          <span className="eyebrow">{t("Propriétaires", "Owners", "الملاك")}</span>
          <h1>{t("Devenir partenaire", "Become a partner", "كن شريكاً")}</h1>
          <p>{t(
            "Votre voiture convient aux mariages ou au transport de personnes ? Soumettez votre dossier, notre équipe l’examine sous quelques jours.",
            "Is your car suited to weddings or passenger transport? Send your application and our team will review it within a few days.",
            "هل سيارتك مناسبة للأعراس أو لنقل الأشخاص؟ أرسل ملفك وسيدرسه فريقنا خلال أيام.",
          )}</p>
        </div>
        <form className="form-panel" onSubmit={submit} noValidate>
          <div className="form-section">
            <h3><User />{t("Vos informations", "Your details", "معلوماتك")}</h3>
            <div className="ref-form">
              <label className="form-field"><span>{t("Prénom", "First name", "الاسم")}</span><input name="first_name" />{err("first_name")}</label>
              <label className="form-field"><span>{t("Nom", "Last name", "اللقب")}</span><input name="last_name" />{err("last_name")}</label>
              <label className="form-field"><span>{t("Téléphone", "Phone", "الهاتف")}</span><input name="phone" type="tel" dir="ltr" />{err("phone")}</label>
              <label className="form-field"><span>{t("E-mail", "Email", "البريد الإلكتروني")}</span><input name="email" type="email" dir="ltr" />{err("email")}</label>
              <label className="form-field"><span>{t("Ville", "City", "المدينة")}</span><input name="city" />{err("city")}</label>
              <label className="form-field"><span>{t("Adresse", "Address", "العنوان")}</span><input name="address" />{err("address")}</label>
              <label className="form-field form-wide"><span>{t("Informations complémentaires", "Additional information", "معلومات إضافية")}</span><textarea name="extra_info" /></label>
            </div>
          </div>
          <div className="form-section">
            <h3><Car />{t("Le véhicule", "The vehicle", "السيارة")}</h3>
            <div className="ref-form">
              <label className="form-field"><span>{t("Marque", "Brand", "العلامة")}</span><input name="brand" />{err("brand")}</label>
              <label className="form-field"><span>{t("Modèle", "Model", "الطراز")}</span><input name="model" />{err("model")}</label>
              <label className="form-field"><span>{t("Année", "Year", "السنة")}</span><input name="year" type="number" />{err("year")}</label>
              <label className="form-field"><span>{t("Couleur", "Colour", "اللون")}</span><input name="color" />{err("color")}</label>
              <label className="form-field"><span>{t("Type de véhicule", "Vehicle type", "نوع السيارة")}</span>
                <select name="vehicle_type" defaultValue="">
                  <option value="">{t("Choisir…", "Choose…", "اختر…")}</option>
                  {VEHICLE_TYPES.map((v) => <option key={v.value} value={v.value}>{p(v.label)}</option>)}
                </select>{err("vehicle_type")}
              </label>
              <label className="form-field"><span>{t("Nombre de places", "Seats", "عدد المقاعد")}</span><input name="seats" type="number" min={1} defaultValue={4} />{err("seats")}</label>
              <label className="form-field"><span>{t("État du véhicule", "Condition", "حالة السيارة")}</span>
                <select name="vehicle_condition" defaultValue="">
                  <option value="">{t("Choisir…", "Choose…", "اختر…")}</option>
                  {conditions.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
                </select>{err("vehicle_condition")}
              </label>
              <label className="form-field"><span>{t("Tarif indicatif (DT, facultatif)", "Indicative price (DT, optional)", "السعر التقريبي (د.ت، اختياري)")}</span><input name="desired_rate" type="number" min={0} defaultValue={0} /></label>
              <div className="form-field form-wide"><span>{t("Services proposés", "Services offered", "الخدمات المقترحة")}</span>
                <div className="flex flex-wrap gap-3">
                  {PARTNER_SERVICES.map((s) => (
                    <label key={s.value} className="check-label">
                      <input type="checkbox" checked={services.includes(s.value)} onChange={(e) => setServices((cur) => (e.target.checked ? [...cur, s.value] : cur.filter((x) => x !== s.value)))} />
                      {p(s.label)}
                    </label>
                  ))}
                </div>{err("services")}
              </div>
              <label className="form-field form-wide"><span>{t("Disponibilités", "Availability", "التوفر")}</span><input name="availability" placeholder={t("Ex. week-ends, soirées, toute l’année", "E.g. weekends, evenings, all year", "مثلاً: عطل نهاية الأسبوع، الأمسيات، طوال السنة")} />{err("availability")}</label>
              <label className="form-field form-wide"><span>{t("Description du véhicule", "Vehicle description", "وصف السيارة")}</span><textarea name="description" />{err("description")}</label>
            </div>
          </div>
          <div className="form-section">
            <h3><Camera />{t("Photos et documents", "Photos and documents", "الصور والوثائق")}</h3>
            <div className="upload-tiles">
              {tile("main", t("Photo principale", "Main photo", "الصورة الرئيسية"), false)}
              {tile("exterior", t("Photos extérieures", "Exterior photos", "صور خارجية"))}
              {tile("interior", t("Photos intérieures", "Interior photos", "صور داخلية"))}
              {tile("document", t("Documents (carte grise, assurance)", "Documents (registration, insurance)", "وثائق (البطاقة الرمادية، التأمين)"))}
            </div>
            {err("files")}
            {files.length > 0 && (
              <div className="admin-photo-strip">
                {files.map((f, i) => (
                  <figure key={f.url} className="relative grid gap-1">
                    {f.file.type.startsWith("image/") ? <img src={f.url} alt={kindLabel(f.kind)} /> : <div className="note-row">PDF</div>}
                    <figcaption className="text-xs font-semibold">{kindLabel(f.kind)}</figcaption>
                    <button type="button" className="text-xs text-destructive text-start" onClick={() => setFiles((c) => c.filter((_, j) => j !== i))}>{t("Retirer", "Remove", "إزالة")}</button>
                  </figure>
                ))}
              </div>
            )}
          </div>
          {err("form")}
          <Button type="submit" className="ref-btn mt-8 w-full" disabled={busy}>{busy ? t("Envoi du dossier…", "Sending…", "جارٍ الإرسال…") : t("Envoyer mon dossier", "Send my application", "أرسل ملفي")}</Button>
        </form>
      </div>
    </section>
  );
}
