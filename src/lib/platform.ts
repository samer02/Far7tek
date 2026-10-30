import rolls from "@/assets/rolls-royce-ghost.jpg";
import maybach from "@/assets/maybach-s680.jpg";
import jaguar from "@/assets/jaguar-mark-ii.jpg";
import hero from "@/assets/far7tek-hero.jpg";
import { labelOf, type Lang, type Tri } from "@/lib/i18n";

export const heroImage = hero;
const local: Record<string, string> = {
  "rolls-royce-ghost": rolls,
  "maybach-s680": maybach,
  "jaguar-mark-ii": jaguar,
};
export const fallbackCarImage = (slug: string) => local[slug] ?? hero;

export const SERVICE_TYPES: { value: "wedding" | "family" | "round_trip" | "private"; label: Tri }[] = [
  { value: "wedding", label: ["Mariage / événement", "Wedding / event", "عرس / مناسبة"] },
  { value: "family", label: ["Transport familial vers une salle des fêtes", "Family transport to a venue", "نقل العائلة إلى قاعة الأفراح"] },
  { value: "round_trip", label: ["Transport aller-retour", "Round trip", "ذهاب وإياب"] },
  { value: "private", label: ["Autre transport privé", "Other private transport", "نقل خاص آخر"] },
];
export const serviceLabel = (v: string, lang: Lang = "fr") =>
  labelOf(Object.fromEntries(SERVICE_TYPES.map((s) => [s.value, s.label])), v, lang);

/** Services an owner can offer: only bride & groom transport and family transport. */
export const PARTNER_SERVICES: { value: "wedding" | "family"; label: Tri }[] = [
  { value: "wedding", label: ["Transport des mariés", "Bride & groom transport", "نقل العروسين"] },
  { value: "family", label: ["Transport familial", "Family transport", "نقل العائلات"] },
];
/** Older stored values, kept only so existing cars still show a readable label. */
const LEGACY_PARTNER_SERVICES: Record<string, Tri> = {
  event: ["Transport événementiel", "Event transport", "نقل المناسبات"],
  private: ["Transport privé avec chauffeur", "Private chauffeur", "نقل خاص مع سائق"],
};
export const partnerServiceLabel = (v: string, lang: Lang = "fr") =>
  labelOf({ ...LEGACY_PARTNER_SERVICES, ...Object.fromEntries(PARTNER_SERVICES.map((s) => [s.value, s.label])) }, v, lang);

/** Public vehicle categories, derived from the services a car offers. */
export type CarCategory = "wedding" | "family";
export const CAR_CATEGORIES: { value: CarCategory; label: Tri; short: Tri }[] = [
  { value: "wedding", label: ["Voitures des mariés", "Wedding cars", "سيارات العروسين"], short: ["Mariés", "Wedding", "العروسين"] },
  { value: "family", label: ["Transport familial", "Family transport", "نقل العائلة"], short: ["Famille", "Family", "العائلة"] },
];
const CATEGORY_SERVICES: Record<CarCategory, string[]> = { wedding: ["wedding", "event"], family: ["family", "private"] };
export const carInCategory = (services: string[] | null | undefined, cat: CarCategory) =>
  (services ?? []).some((s) => CATEGORY_SERVICES[cat].includes(s));

/** Car colour palette. The French name is stored; the swatch is the paint colour itself. */
export const CAR_COLORS: { value: string; label: Tri; hex: string }[] = [
  { value: "Blanc", label: ["Blanc", "White", "أبيض"], hex: "#f8f8f6" },
  { value: "Ivoire", label: ["Ivoire", "Ivory", "عاجي"], hex: "#efe6d2" },
  { value: "Beige", label: ["Beige", "Beige", "بيج"], hex: "#d8c3a0" },
  { value: "Champagne", label: ["Champagne", "Champagne", "شمباني"], hex: "#cdb48a" },
  { value: "Doré", label: ["Doré", "Gold", "ذهبي"], hex: "#c09a4a" },
  { value: "Argent", label: ["Argent", "Silver", "فضي"], hex: "#bfc3c7" },
  { value: "Gris", label: ["Gris", "Grey", "رمادي"], hex: "#6e7378" },
  { value: "Noir", label: ["Noir", "Black", "أسود"], hex: "#16171a" },
  { value: "Bleu", label: ["Bleu", "Blue", "أزرق"], hex: "#24427a" },
  { value: "Rouge", label: ["Rouge", "Red", "أحمر"], hex: "#b3202a" },
  { value: "Bordeaux", label: ["Bordeaux", "Burgundy", "خمري"], hex: "#6b1e2c" },
  { value: "Marron", label: ["Marron", "Brown", "بني"], hex: "#5d3b26" },
  { value: "Vert", label: ["Vert", "Green", "أخضر"], hex: "#2f5a3e" },
  { value: "Rose", label: ["Rose", "Pink", "وردي"], hex: "#e2a6b4" },
];
/** Finds the palette entry for a stored colour, also matching older free-text values like "Blanc nacré". */
export const findCarColor = (v: string | null | undefined) => {
  const s = (v ?? "").trim().toLowerCase();
  if (!s) return undefined;
  return CAR_COLORS.find((c) => c.value.toLowerCase() === s) ?? CAR_COLORS.find((c) => s.startsWith(c.value.toLowerCase()));
};
export const carColorLabel = (v: string | null | undefined, lang: Lang = "fr") => {
  const c = findCarColor(v);
  return c && c.value.toLowerCase() === (v ?? "").trim().toLowerCase() ? pickTri(c.label, lang) : (v ?? "");
};
const pickTri = (t: Tri, lang: Lang) => t[lang === "ar" ? 2 : lang === "en" ? 1 : 0];

/** Stored values stay in French; only the displayed label changes. */
export const VEHICLE_TYPES: { value: string; label: Tri }[] = [
  { value: "Berline de prestige", label: ["Berline de prestige", "Luxury sedan", "سيارة فاخرة"] },
  { value: "Voiture de collection", label: ["Voiture de collection", "Classic car", "سيارة كلاسيكية"] },
  { value: "Limousine", label: ["Limousine", "Limousine", "ليموزين"] },
  { value: "Van / minibus", label: ["Van / minibus", "Van / minibus", "فان / حافلة صغيرة"] },
  { value: "SUV", label: ["SUV", "SUV", "سيارة دفع رباعي"] },
  { value: "Cabriolet", label: ["Cabriolet", "Convertible", "سيارة مكشوفة"] },
];
export const vehicleTypeLabel = (v: string, lang: Lang = "fr") =>
  labelOf(Object.fromEntries(VEHICLE_TYPES.map((s) => [s.value, s.label])), v, lang);

export const BOOKING_STATUS: Record<string, Tri> = {
  new: ["Nouvelle", "New", "جديد"],
  pending: ["En attente", "Pending", "قيد الانتظار"],
  contacted: ["Contacté", "Contacted", "تم التواصل"],
  accepted: ["Acceptée", "Accepted", "مقبول"],
  rejected: ["Refusée", "Declined", "مرفوض"],
  confirmed: ["Confirmée", "Confirmed", "مؤكد"],
  in_progress: ["En cours", "In progress", "جارٍ"],
  completed: ["Terminée", "Completed", "منتهٍ"],
  cancelled: ["Annulée", "Cancelled", "ملغى"],
};
/** Labels for the request history timeline (includes internal events). */
export const HISTORY_STATUS: Record<string, Tri> = {
  ...BOOKING_STATUS,
  assigned: ["Attribuée à un chauffeur", "Assigned to a driver", "أُسند إلى سائق"],
};
export const PROPOSAL_STATUS: Record<string, Tri> = {
  new: ["Nouveau", "New", "جديد"],
  pending: ["En attente", "Pending", "قيد الانتظار"],
  reviewing: ["En étude", "Under review", "قيد الدراسة"],
  info_requested: ["Compléments demandés", "Info requested", "مطلوب معلومات إضافية"],
  approved: ["Accepté", "Approved", "مقبول"],
  accepted: ["Accepté", "Approved", "مقبول"],
  rejected: ["Refusé", "Declined", "مرفوض"],
};
export const ASSIGNMENT_STATUS: Record<string, Tri> = {
  proposed: ["Proposée", "Offered", "معروض"],
  accepted: ["Acceptée", "Accepted", "مقبول"],
  rejected: ["Refusée", "Declined", "مرفوض"],
};
export const CAR_VALIDATION: Record<string, Tri> = {
  pending: ["En attente de validation", "Awaiting approval", "بانتظار الموافقة"],
  active: ["Publié", "Published", "منشور"],
  disabled: ["Désactivé", "Disabled", "معطّل"],
};

/** Trip statuses a partner may set once a request is assigned to them. */
export const PARTNER_TRIP_TRANSITIONS: Record<string, string[]> = {
  accepted: ["confirmed", "cancelled"],
  confirmed: ["in_progress", "cancelled"],
  in_progress: ["completed"],
};
export const canPartnerMoveTo = (from: string, to: string) =>
  (PARTNER_TRIP_TRANSITIONS[from] ?? []).includes(to);

/** Simple matching score used to suggest partners for a request (ready for auto-assignment later). */
export function matchScore(
  req: { city: string; passengers: number; vehicle_type: string; service_type: string },
  car: { city: string | null; seats: number | null; category: string; services: string[] },
) {
  if (car.seats != null && car.seats < req.passengers) return -1;
  let s = 0;
  if (car.city && car.city.trim().toLowerCase() === req.city.trim().toLowerCase()) s += 3;
  if (req.vehicle_type && car.category === req.vehicle_type) s += 2;
  const svc = req.service_type === "round_trip" ? "family" : req.service_type;
  if (car.services.includes(svc)) s += 2;
  return s;
}

/** Prices are in Tunisian dinars. */
export const fmtPrice = (n: number, lang: Lang = "fr") => (lang === "ar" ? `${n} د.ت` : `${n} DT`);

export const fmtDate = (d: string) => new Date(d).toLocaleDateString("fr-FR");
