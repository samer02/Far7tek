import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { ImagePlus, Plus, Sparkles, Star, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import type { Tables, TablesUpdate } from "@/integrations/supabase/types";
import { resolveCarImageUrl } from "@/lib/cars";
import { CAR_CATEGORIES, carInCategory, EQUIPMENT, FUEL_TYPES, TRANSMISSIONS, VEHICLE_TYPES, fallbackCarImage } from "@/lib/platform";
import { call, HOLDING, type Booking } from "@/lib/transport";
import { useI18n } from "@/lib/i18n";
import { ColorPalette, NumberInput } from "@/components/form-inputs";
import { ownerName, useOwners } from "@/components/admin/transport-requests";

type Car = Tables<"cars">;
type CarImage = Tables<"car_images">;
const MAX_MB = 8;

const slugify = (s: string) => s.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 60) || "vehicule";
const storageKey = (path: string) => (path.startsWith("car-images/") ? path.slice("car-images/".length) : path);

export function CarCatalog({ cars, bookings, refresh }: { cars: Car[]; bookings: Booking[]; refresh: () => void }) {
  const { t, p } = useI18n();
  const qc = useQueryClient();
  const { data: owners = [] } = useOwners();
  const [editing, setEditing] = useState<string | "new" | null>(null);
  const [q, setQ] = useState("");
  const [cat, setCat] = useState("");
  const { data: images = [] } = useQuery({
    queryKey: ["adm-car-images"],
    queryFn: () => call<CarImage[]>(supabase.from("car_images").select("*").order("sort_order")),
  });
  const reload = () => { refresh(); qc.invalidateQueries({ queryKey: ["adm-car-images"] }); qc.invalidateQueries({ queryKey: ["cars"] }); };
  const cover = (c: Car) => {
    const own = images.filter((i) => i.car_id === c.id).sort((a, b) => Number(b.is_cover) - Number(a.is_cover) || a.sort_order - b.sort_order);
    return own[0] ? resolveCarImageUrl(own[0].storage_path) : fallbackCarImage(c.slug);
  };

  async function patch(c: Car, values: TablesUpdate<"cars">, msg: string) {
    try { await call(supabase.from("cars").update({ ...values, updated_at: new Date().toISOString() }).eq("id", c.id)); toast.success(msg); reload(); }
    catch (e) { toast.error((e as Error).message); }
  }
  async function remove(c: Car) {
    if (bookings.some((b) => b.car_id === c.id && HOLDING.includes(b.status))) {
      toast.error(t("Ce véhicule a des réservations actives : dépubliez-le plutôt.", "This vehicle has active bookings: unpublish it instead.", "لهذه السيارة حجوزات نشطة: ألغِ نشرها بدلاً من ذلك."));
      return;
    }
    if (!window.confirm(t(`Supprimer définitivement « ${c.name} » et ses photos ?`, `Permanently delete “${c.name}” and its photos?`, `حذف «${c.name}» وصوره نهائياً؟`))) return;
    try {
      const paths = images.filter((i) => i.car_id === c.id && !/^https?:/.test(i.storage_path) && !i.storage_path.startsWith("proposal-images/")).map((i) => storageKey(i.storage_path));
      await call(supabase.from("cars").delete().eq("id", c.id));
      if (paths.length) await supabase.storage.from("car-images").remove(paths);
      toast.success(t("Véhicule supprimé", "Vehicle deleted", "تم حذف السيارة"));
      setEditing(null);
      reload();
    } catch (e) { toast.error((e as Error).message); }
  }

  const rows = cars
    .filter((c) => !cat || carInCategory(c.services, cat as "wedding" | "family"))
    .filter((c) => !q || `${c.name} ${c.brand} ${c.model} ${c.city ?? ""}`.toLowerCase().includes(q.toLowerCase()));
  const current = editing && editing !== "new" ? cars.find((c) => c.id === editing) : undefined;

  if (editing && editing !== "new" && !current) return <p className="registry">{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p>;
  if (editing) return <CarEditor key={editing} car={current} cars={cars} owners={owners} images={images.filter((i) => i.car_id === current?.id)} onDone={(id) => { reload(); setEditing(id); }} onClose={() => setEditing(null)} onDelete={current ? () => void remove(current) : undefined} />;

  return (
    <div className="registry">
      <div className="flex flex-wrap gap-3 mb-4 items-center">
        <input className="admin-search" placeholder={t("Rechercher un véhicule", "Search a vehicle", "ابحث عن سيارة")} value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="admin-select" value={cat} onChange={(e) => setCat(e.target.value)}>
          <option value="">{t("Toutes catégories", "All categories", "كل الفئات")}</option>
          {CAR_CATEGORIES.map((c) => <option key={c.value} value={c.value}>{p(c.label)}</option>)}
        </select>
        <Button className="ref-btn bg-primary ms-auto" onClick={() => setEditing("new")}><Plus className="h-4 w-4" />{t("Ajouter un véhicule", "Add a vehicle", "إضافة سيارة")}</Button>
      </div>
      <div className="catalog-admin-grid">
        {rows.map((c) => (
          <article key={c.id} className="catalog-admin-card">
            <img src={cover(c)} alt="" loading="lazy" />
            <div className="catalog-admin-body">
              <div className="car-meta"><span>{CAR_CATEGORIES.filter((x) => carInCategory(c.services, x.value)).map((x) => p(x.short)).join(" · ") || "—"}</span><span>{c.active ? t("Publié", "Published", "منشور") : t("Masqué", "Hidden", "مخفي")}</span></div>
              <h3>{c.name}</h3>
              <small>{[c.brand, c.model, c.year].filter(Boolean).join(" · ")} · {ownerName(owners.find((o) => o.id === c.owner_id))}</small>
              <div className="toggle-row">
                <label className="check-label"><input type="checkbox" checked={c.active} onChange={(e) => void patch(c, e.target.checked ? { active: true, validation_status: "active" } : { active: false }, e.target.checked ? t("Publié", "Published", "منشور") : t("Dépublié", "Unpublished", "أُلغي النشر"))} />{t("Publié", "Published", "منشور")}</label>
                <label className="check-label"><input type="checkbox" checked={c.featured} onChange={(e) => void patch(c, { featured: e.target.checked }, t("Mis à jour", "Updated", "تم التحديث"))} /><Star className="h-4 w-4" />{t("Coup de cœur", "Featured", "مميزة")}</label>
                <label className="check-label"><input type="checkbox" checked={c.is_new_arrival} onChange={(e) => void patch(c, { is_new_arrival: e.target.checked }, t("Mis à jour", "Updated", "تم التحديث"))} /><Sparkles className="h-4 w-4" />{t("Nouveauté", "New arrival", "وصل حديثاً")}</label>
              </div>
              <div className="action-row mt-3">
                <Button variant="outline" className="ref-btn" onClick={() => setEditing(c.id)}>{t("Modifier", "Edit", "تعديل")}</Button>
                <Button variant="ghost" className="ref-btn text-destructive" onClick={() => void remove(c)}><Trash2 className="h-4 w-4" />{t("Supprimer", "Delete", "حذف")}</Button>
              </div>
            </div>
          </article>
        ))}
      </div>
      {!rows.length && <p className="admin-empty">{t("Aucun véhicule.", "No vehicles.", "لا توجد سيارات.")}</p>}
    </div>
  );
}

function CarEditor({ car, cars, owners, images, onDone, onClose, onDelete }: {
  car: Car | undefined; cars: Car[]; owners: { id: string; first_name: string; last_name: string; email: string; phone: string | null }[]; images: CarImage[];
  onDone: (id: string) => void; onClose: () => void; onDelete: (() => void) | undefined;
}) {
  const { t, p } = useI18n();
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const err = (k: string) => errors[k] && <span className="form-error">{errors[k]}</span>;
  const sorted = [...images].sort((a, b) => Number(b.is_cover) - Number(a.is_cover) || a.sort_order - b.sort_order);

  async function save(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const s = (k: string, max = 120) => String(fd.get(k) ?? "").trim().slice(0, max);
    const n = (k: string) => { const v = s(k); return v ? Number(v) : null; };
    const services = fd.getAll("services").map(String);
    const errs: Record<string, string> = {};
    if (!s("name")) errs["name"] = t("Nom requis", "Name required", "الاسم مطلوب");
    if (!s("brand")) errs["brand"] = t("Marque requise", "Brand required", "الماركة مطلوبة");
    if (!services.length) errs["services"] = t("Choisissez au moins une catégorie", "Pick at least one category", "اختر فئة واحدة على الأقل");
    const year = n("year"), seats = n("seats"), price = n("price_from");
    if (year !== null && (year < 1900 || year > new Date().getFullYear() + 1)) errs["year"] = t("Année invalide", "Invalid year", "سنة غير صالحة");
    if (seats !== null && (seats < 1 || seats > 60)) errs["seats"] = t("1 à 60 places", "1 to 60 seats", "من 1 إلى 60 مقعداً");
    if (Object.keys(errs).length) { setErrors(errs); return; }
    setErrors({});
    const values = {
      name: s("name"), brand: s("brand", 60), model: s("model", 60), year, seats, price_from: price,
      category: s("category", 80) || VEHICLE_TYPES[0]!.value, transmission: s("transmission", 20) || null, fuel_type: s("fuel_type", 20) || null,
      color: s("color", 40) || null, city: s("city", 80) || null, services, equipment: fd.getAll("equipment").map(String),
      short_description: s("short_description", 240), description: s("description", 4000), availability: s("availability", 200),
      owner_id: s("owner_id") || null, active: fd.get("active") === "on", featured: fd.get("featured") === "on", is_new_arrival: fd.get("is_new_arrival") === "on",
    };
    setSaving(true);
    try {
      if (car) {
        await call(supabase.from("cars").update({ ...values, ...(values.active ? { validation_status: "active" } : {}), updated_at: new Date().toISOString() }).eq("id", car.id));
        toast.success(t("Véhicule enregistré", "Vehicle saved", "تم حفظ السيارة"));
        onDone(car.id);
      } else {
        const base = slugify(`${values.brand} ${values.name}`);
        const slug = cars.some((c) => c.slug === base) ? `${base}-${crypto.randomUUID().slice(0, 4)}` : base;
        const row = await call<{ id: string }>(supabase.from("cars").insert({ ...values, slug, validation_status: values.active ? "active" : "pending" }).select("id").single());
        toast.success(t("Véhicule créé — ajoutez maintenant ses photos", "Vehicle created — now add its photos", "تم إنشاء السيارة — أضف صورها الآن"));
        onDone(row.id);
      }
    } catch (e2) { toast.error((e2 as Error).message); } finally { setSaving(false); }
  }

  async function upload(files: FileList | null) {
    if (!car || !files?.length) return;
    setUploading(true);
    let order = images.reduce((m, i) => Math.max(m, i.sort_order), 0);
    let hasCover = images.some((i) => i.is_cover);
    let added = 0;
    for (const f of [...files]) {
      if (!f.type.startsWith("image/") || f.size > MAX_MB * 1024 * 1024) { toast.error(`${f.name} : ${t(`image de ${MAX_MB} Mo max.`, `images up to ${MAX_MB} MB`, `صورة حتى ${MAX_MB} ميغابايت`)}`); continue; }
      const ext = (f.name.split(".").pop() ?? "jpg").toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 5) || "jpg";
      const path = `catalog/${car.id}/${crypto.randomUUID()}.${ext}`;
      const up = await supabase.storage.from("car-images").upload(path, f, { contentType: f.type });
      if (up.error) { toast.error(`${f.name} : ${up.error.message}`); continue; }
      const { error } = await supabase.from("car_images").insert({ car_id: car.id, storage_path: path, sort_order: ++order, is_cover: !hasCover, alt_text: car.name });
      if (error) { await supabase.storage.from("car-images").remove([path]); toast.error(error.message); continue; }
      hasCover = true;
      added++;
    }
    setUploading(false);
    if (added) toast.success(t(`${added} photo(s) ajoutée(s)`, `${added} photo(s) added`, `تمت إضافة ${added} صورة`));
    onDone(car.id);
  }

  async function makeCover(img: CarImage) {
    try {
      await call(supabase.from("car_images").update({ is_cover: false }).eq("car_id", img.car_id));
      await call(supabase.from("car_images").update({ is_cover: true }).eq("id", img.id));
      onDone(img.car_id);
    } catch (e) { toast.error((e as Error).message); }
  }
  async function removeImage(img: CarImage) {
    if (!window.confirm(t("Supprimer cette photo ?", "Delete this photo?", "حذف هذه الصورة؟"))) return;
    try {
      await call(supabase.from("car_images").delete().eq("id", img.id));
      if (!/^https?:/.test(img.storage_path) && !img.storage_path.startsWith("proposal-images/")) await supabase.storage.from("car-images").remove([storageKey(img.storage_path)]);
      const rest = images.filter((i) => i.id !== img.id);
      if (img.is_cover && rest[0]) await call(supabase.from("car_images").update({ is_cover: true }).eq("id", rest[0].id));
      onDone(img.car_id);
    } catch (e) { toast.error((e as Error).message); }
  }

  return (
    <div className="dossier">
      <div className="flex flex-wrap items-center justify-between gap-3 mb-4">
        <h3>{car ? car.name : t("Nouveau véhicule", "New vehicle", "سيارة جديدة")}</h3>
        <div className="action-row">
          {onDelete && <Button variant="ghost" className="ref-btn text-destructive" onClick={onDelete}><Trash2 className="h-4 w-4" />{t("Supprimer", "Delete", "حذف")}</Button>}
          <Button variant="outline" className="ref-btn" onClick={onClose}>{t("Retour au catalogue", "Back to catalog", "العودة إلى الكتالوج")}</Button>
        </div>
      </div>

      {car && (
        <div className="form-section">
          <h4 className="mb-3 font-semibold">{t("Photos", "Photos", "الصور")} ({images.length})</h4>
          <div className="photo-manager">
            {sorted.map((img) => (
              <figure key={img.id} className={img.is_cover ? "is-cover" : ""}>
                <img src={resolveCarImageUrl(img.storage_path)} alt="" />
                <figcaption>
                  {img.is_cover ? <span>{t("Couverture", "Cover", "الغلاف")}</span> : <button type="button" onClick={() => void makeCover(img)}>{t("Définir en couverture", "Set as cover", "تعيين كغلاف")}</button>}
                  <button type="button" className="icon-btn" aria-label={t("Supprimer la photo", "Delete photo", "حذف الصورة")} onClick={() => void removeImage(img)}><Trash2 /></button>
                </figcaption>
              </figure>
            ))}
            <label className="upload-tile">
              <ImagePlus /><span>{uploading ? t("Envoi…", "Uploading…", "جارٍ الرفع…") : t("Ajouter des photos", "Add photos", "إضافة صور")}</span>
              <input type="file" accept="image/*" multiple className="sr-only" disabled={uploading} onChange={(e) => { void upload(e.target.files); e.target.value = ""; }} />
            </label>
          </div>
        </div>
      )}

      <form className="form-section" onSubmit={save} noValidate>
        <div className="ref-form">
          <label className="form-field"><span>{t("Nom affiché", "Display name", "الاسم المعروض")}</span><input name="name" defaultValue={car?.name ?? ""} maxLength={120} />{err("name")}</label>
          <label className="form-field"><span>{t("Marque", "Brand", "الماركة")}</span><input name="brand" defaultValue={car?.brand ?? ""} maxLength={60} />{err("brand")}</label>
          <label className="form-field"><span>{t("Modèle", "Model", "الطراز")}</span><input name="model" defaultValue={car?.model ?? ""} maxLength={60} /></label>
          <label className="form-field"><span>{t("Année", "Year", "السنة")}</span><NumberInput name="year" maxLength={4} defaultValue={car?.year ?? ""} placeholder="2022" />{err("year")}</label>
          <label className="form-field"><span>{t("Places", "Seats", "المقاعد")}</span><NumberInput name="seats" maxLength={2} defaultValue={car?.seats ?? ""} placeholder="4" />{err("seats")}</label>
          <label className="form-field"><span>{t("Tarif indicatif (DT)", "Indicative price (DT)", "السعر التقريبي (د.ت)")}</span><NumberInput name="price_from" maxLength={6} defaultValue={car?.price_from ?? ""} placeholder="300" /></label>
          <label className="form-field"><span>{t("Type de véhicule", "Vehicle type", "نوع السيارة")}</span>
            <select name="category" defaultValue={car?.category ?? VEHICLE_TYPES[0]!.value}>{VEHICLE_TYPES.map((v) => <option key={v.value} value={v.value}>{p(v.label)}</option>)}</select>
          </label>
          <label className="form-field"><span>{t("Boîte de vitesses", "Transmission", "ناقل الحركة")}</span>
            <select name="transmission" defaultValue={car?.transmission ?? ""}><option value="">—</option>{TRANSMISSIONS.map((v) => <option key={v.value} value={v.value}>{p(v.label)}</option>)}</select>
          </label>
          <label className="form-field"><span>{t("Carburant", "Fuel", "الوقود")}</span>
            <select name="fuel_type" defaultValue={car?.fuel_type ?? ""}><option value="">—</option>{FUEL_TYPES.map((v) => <option key={v.value} value={v.value}>{p(v.label)}</option>)}</select>
          </label>
          <label className="form-field"><span>{t("Ville", "City", "المدينة")}</span><input name="city" defaultValue={car?.city ?? ""} maxLength={80} /></label>
          <div className="form-field form-wide"><span>{t("Couleur", "Colour", "اللون")}</span><ColorPalette name="color" defaultValue={car?.color ?? ""} /></div>
          <fieldset className="form-field form-wide"><span>{t("Catégories", "Categories", "الفئات")}</span>
            <div className="flex flex-wrap gap-2">
              {CAR_CATEGORIES.map((c) => <label key={c.value} className="check-label"><input type="checkbox" name="services" value={c.value} defaultChecked={carInCategory(car?.services, c.value)} />{p(c.label)}</label>)}
            </div>{err("services")}
          </fieldset>
          <fieldset className="form-field form-wide"><span>{t("Équipements", "Equipment", "التجهيزات")}</span>
            <div className="flex flex-wrap gap-2">
              {EQUIPMENT.map((x) => <label key={x.value} className="check-label"><input type="checkbox" name="equipment" value={x.value} defaultChecked={(car?.equipment ?? []).includes(x.value)} />{p(x.label)}</label>)}
            </div>
          </fieldset>
          <label className="form-field form-wide"><span>{t("Propriétaire", "Owner", "المالك")}</span>
            <select name="owner_id" defaultValue={car?.owner_id ?? ""}>
              <option value="">{t("Aucun (flotte Far7tek)", "None (Far7tek fleet)", "بدون (أسطول فرحتك)")}</option>
              {owners.map((o) => <option key={o.id} value={o.id}>{ownerName(o)}{o.phone ? ` · ${o.phone}` : ""}</option>)}
            </select>
          </label>
          <label className="form-field form-wide"><span>{t("Accroche", "Short description", "وصف قصير")}</span><input name="short_description" defaultValue={car?.short_description ?? ""} maxLength={240} /></label>
          <label className="form-field form-wide"><span>{t("Description", "Description", "الوصف")}</span><textarea name="description" defaultValue={car?.description ?? ""} maxLength={4000} /></label>
          <label className="form-field form-wide"><span>{t("Texte de disponibilité affiché", "Displayed availability text", "نص التوفر المعروض")}</span><input name="availability" defaultValue={car?.availability ?? ""} maxLength={200} /></label>
          <div className="form-wide flex flex-wrap gap-2">
            <label className="check-label"><input type="checkbox" name="active" defaultChecked={car?.active ?? false} />{t("Publié dans le catalogue", "Published in the catalog", "منشور في الكتالوج")}</label>
            <label className="check-label"><input type="checkbox" name="featured" defaultChecked={car?.featured ?? false} /><Star className="h-4 w-4" />{t("Coup de cœur", "Featured", "مميزة")}</label>
            <label className="check-label"><input type="checkbox" name="is_new_arrival" defaultChecked={car?.is_new_arrival ?? !car} /><Sparkles className="h-4 w-4" />{t("Nouveauté", "New arrival", "وصل حديثاً")}</label>
          </div>
        </div>
        <Button className="ref-btn bg-primary mt-6" disabled={saving}>{saving ? t("Enregistrement…", "Saving…", "جارٍ الحفظ…") : car ? t("Enregistrer", "Save", "حفظ") : t("Créer le véhicule", "Create vehicle", "إنشاء السيارة")}</Button>
      </form>
    </div>
  );
}
