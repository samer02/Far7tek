import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { z } from "zod";
import { CheckCircle2, ImagePlus, User, Car, Camera } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { PARTNER_SERVICES, VEHICLE_TYPES } from "@/lib/platform";

export const Route = createFileRoute("/devenir-partenaire")({
  head: () => ({
    meta: [
      { title: "Devenir partenaire — Proposer ma voiture | Cortège & Cérémonie" },
      { name: "description", content: "Propriétaire d’une voiture de prestige ou familiale ? Rejoignez notre réseau de partenaires chauffeurs." },
      { property: "og:title", content: "Devenir partenaire — Proposer ma voiture" },
      { property: "og:description", content: "Soumettez votre véhicule pour les mariages et le transport de personnes." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: PartnerApply,
});

const schema = z.object({
  first_name: z.string().trim().min(1, "Prénom requis").max(80),
  last_name: z.string().trim().min(1, "Nom requis").max(80),
  phone: z.string().trim().regex(/^[+0-9 .()-]{6,20}$/, "Téléphone invalide"),
  email: z.string().trim().email("E-mail invalide").max(255),
  city: z.string().trim().min(1, "Ville requise").max(80),
  address: z.string().trim().min(3, "Adresse requise").max(250),
  extra_info: z.string().trim().max(1000),
  brand: z.string().trim().min(1, "Marque requise").max(60),
  model: z.string().trim().min(1, "Modèle requis").max(60),
  year: z.coerce.number().int().min(1920, "Année invalide").max(new Date().getFullYear() + 1, "Année invalide"),
  color: z.string().trim().min(1, "Couleur requise").max(40),
  vehicle_type: z.string().min(1, "Type requis"),
  seats: z.coerce.number().int().min(1).max(60),
  vehicle_condition: z.string().min(1, "État requis"),
  availability: z.string().trim().min(2, "Disponibilités requises").max(300),
  desired_rate: z.coerce.number().min(0).max(100000).default(0),
  description: z.string().trim().min(20, "Décrivez le véhicule (20 caractères min.)").max(2000),
});

type Kind = "main" | "exterior" | "interior" | "document";
const MAX = 8 * 1024 * 1024;

function PartnerApply() {
  const [files, setFiles] = useState<{ kind: Kind; file: File; url: string }[]>([]);
  const [services, setServices] = useState<string[]>([]);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  function add(kind: Kind, list: FileList | null) {
    if (!list) return;
    const ok = [...list].filter((f) => f.size <= MAX && (kind === "document" || f.type.startsWith("image/")));
    if (ok.length < list.length) setErrors((e) => ({ ...e, files: "Certains fichiers ont été ignorés (image, 8 Mo max)." }));
    const mapped = ok.map((file) => ({ kind, file, url: URL.createObjectURL(file) }));
    setFiles((cur) => (kind === "main" ? [...cur.filter((f) => f.kind !== "main"), ...mapped.slice(0, 1)] : [...cur, ...mapped]));
  }

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const parsed = schema.safeParse(Object.fromEntries(new FormData(e.currentTarget)));
    const errs: Record<string, string> = {};
    if (!parsed.success) parsed.error.issues.forEach((i) => (errs[i.path[0] as string] = i.message));
    if (!services.length) errs["services"] = "Choisissez au moins un service";
    if (!files.some((f) => f.kind === "main")) errs["files"] = "La photo principale est requise";
    setErrors(errs);
    if (Object.keys(errs).length || !parsed.success) return;
    setBusy(true);
    const id = crypto.randomUUID();
    const { error } = await supabase.from("car_proposals").insert({ id, ...parsed.data, services, travel_zone: parsed.data.city, schedules: parsed.data.availability, status: "pending" });
    if (error) { setBusy(false); setErrors({ form: "L’envoi a échoué, merci de réessayer." }); return; }
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
        <h3>Dossier envoyé</h3>
        <p>Merci ! Votre dossier est en attente et sera examiné par notre équipe. Si votre candidature est acceptée, vous recevrez par e-mail une invitation pour créer votre mot de passe et accéder à votre espace partenaire.</p>
      </div></div></section>
    );

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading center">
          <span className="eyebrow">Propriétaires</span>
          <h1>Devenir partenaire</h1>
          <p>Votre voiture convient aux mariages ou au transport de personnes ? Soumettez votre dossier, notre équipe l’examine sous quelques jours.</p>
        </div>
        <form className="form-panel" onSubmit={submit} noValidate>
          <div className="form-section">
            <h3><User />Vos informations</h3>
            <div className="ref-form">
              <label className="form-field"><span>Prénom</span><input name="first_name" />{err("first_name")}</label>
              <label className="form-field"><span>Nom</span><input name="last_name" />{err("last_name")}</label>
              <label className="form-field"><span>Téléphone</span><input name="phone" type="tel" />{err("phone")}</label>
              <label className="form-field"><span>E-mail</span><input name="email" type="email" />{err("email")}</label>
              <label className="form-field"><span>Ville</span><input name="city" />{err("city")}</label>
              <label className="form-field"><span>Adresse</span><input name="address" />{err("address")}</label>
              <label className="form-field form-wide"><span>Informations complémentaires</span><textarea name="extra_info" /></label>
            </div>
          </div>
          <div className="form-section">
            <h3><Car />Le véhicule</h3>
            <div className="ref-form">
              <label className="form-field"><span>Marque</span><input name="brand" />{err("brand")}</label>
              <label className="form-field"><span>Modèle</span><input name="model" />{err("model")}</label>
              <label className="form-field"><span>Année</span><input name="year" type="number" />{err("year")}</label>
              <label className="form-field"><span>Couleur</span><input name="color" />{err("color")}</label>
              <label className="form-field"><span>Type de véhicule</span>
                <select name="vehicle_type" defaultValue="">{["", ...VEHICLE_TYPES].map((v) => <option key={v} value={v}>{v || "Choisir…"}</option>)}</select>{err("vehicle_type")}
              </label>
              <label className="form-field"><span>Nombre de places</span><input name="seats" type="number" min={1} defaultValue={4} />{err("seats")}</label>
              <label className="form-field"><span>État du véhicule</span>
                <select name="vehicle_condition" defaultValue="">{["", "Excellent", "Très bon", "Bon"].map((v) => <option key={v} value={v}>{v || "Choisir…"}</option>)}</select>{err("vehicle_condition")}
              </label>
              <label className="form-field"><span>Tarif indicatif (€, facultatif)</span><input name="desired_rate" type="number" min={0} defaultValue={0} /></label>
              <div className="form-field form-wide"><span>Services proposés</span>
                <div className="flex flex-wrap gap-4">
                  {PARTNER_SERVICES.map((s) => (
                    <label key={s.value} className="check-label">
                      <input type="checkbox" checked={services.includes(s.value)} onChange={(e) => setServices((cur) => (e.target.checked ? [...cur, s.value] : cur.filter((x) => x !== s.value)))} />
                      {s.label}
                    </label>
                  ))}
                </div>{err("services")}
              </div>
              <label className="form-field form-wide"><span>Disponibilités</span><input name="availability" placeholder="Ex. week-ends, soirées, toute l’année" />{err("availability")}</label>
              <label className="form-field form-wide"><span>Description du véhicule</span><textarea name="description" />{err("description")}</label>
            </div>
          </div>
          <div className="form-section">
            <h3><Camera />Photos et documents</h3>
            <div className="upload-tiles">
              {tile("main", "Photo principale", false)}
              {tile("exterior", "Photos extérieures")}
              {tile("interior", "Photos intérieures")}
              {tile("document", "Documents (carte grise, assurance)")}
            </div>
            {err("files")}
            {files.length > 0 && (
              <div className="admin-photo-strip">
                {files.map((f, i) => (
                  <figure key={f.url} className="relative">
                    {f.file.type.startsWith("image/") ? <img src={f.url} alt={f.kind} /> : <div className="note-row">PDF</div>}
                    <figcaption className="text-[9px] uppercase">{f.kind === "main" ? "Principale" : f.kind === "exterior" ? "Extérieur" : f.kind === "interior" ? "Intérieur" : "Document"}</figcaption>
                    <button type="button" className="text-[9px] text-destructive" onClick={() => setFiles((c) => c.filter((_, j) => j !== i))}>Retirer</button>
                  </figure>
                ))}
              </div>
            )}
          </div>
          {err("form")}
          <Button type="submit" className="ref-btn mt-6 w-full" disabled={busy}>{busy ? "Envoi du dossier…" : "Envoyer mon dossier"}</Button>
        </form>
      </div>
    </section>
  );
}
