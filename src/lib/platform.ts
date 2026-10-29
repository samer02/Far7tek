import rolls from "@/assets/rolls-royce-ghost.jpg";
import maybach from "@/assets/maybach-s680.jpg";
import jaguar from "@/assets/jaguar-mark-ii.jpg";
import hero from "@/assets/cortege-hero.jpg";

export const heroImage = hero;
const local: Record<string, string> = {
  "rolls-royce-ghost": rolls,
  "maybach-s680": maybach,
  "jaguar-mark-ii": jaguar,
};
export const fallbackCarImage = (slug: string) => local[slug] ?? hero;

export const SERVICE_TYPES = [
  { value: "wedding", label: "Mariage / événement" },
  { value: "family", label: "Transport familial vers une salle des fêtes" },
  { value: "round_trip", label: "Transport aller-retour" },
  { value: "private", label: "Autre transport privé" },
] as const;
export const serviceLabel = (v: string) => SERVICE_TYPES.find((s) => s.value === v)?.label ?? v;

export const PARTNER_SERVICES = [
  { value: "wedding", label: "Transport des mariés" },
  { value: "family", label: "Transport familial" },
  { value: "event", label: "Transport événementiel" },
  { value: "private", label: "Transport privé avec chauffeur" },
] as const;
export const partnerServiceLabel = (v: string) => PARTNER_SERVICES.find((s) => s.value === v)?.label ?? v;

export const VEHICLE_TYPES = ["Berline de prestige", "Voiture de collection", "Limousine", "Van / minibus", "SUV", "Cabriolet"];

export const BOOKING_STATUS: Record<string, string> = {
  new: "Nouvelle",
  pending: "En attente",
  contacted: "Contacté",
  accepted: "Acceptée",
  rejected: "Refusée",
  confirmed: "Confirmée",
  in_progress: "En cours",
  completed: "Terminée",
  cancelled: "Annulée",
};
export const PROPOSAL_STATUS: Record<string, string> = {
  new: "Nouveau",
  pending: "En attente",
  reviewing: "En étude",
  info_requested: "Compléments demandés",
  approved: "Accepté",
  accepted: "Accepté",
  rejected: "Refusé",
};
export const ASSIGNMENT_STATUS: Record<string, string> = {
  proposed: "Proposée",
  accepted: "Acceptée",
  rejected: "Refusée",
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

export const fmtDate = (d: string) => new Date(d).toLocaleDateString("fr-FR");
