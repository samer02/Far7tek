import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { z } from "zod";
import { CheckCircle2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { fetchCars } from "@/lib/cars";
import { SERVICE_TYPES, VEHICLE_TYPES } from "@/lib/platform";

export const Route = createFileRoute("/reserver")({
  validateSearch: (s: Record<string, unknown>): { car?: string } => (typeof s["car"] === "string" ? { car: s["car"] } : {}),
  head: () => ({
    meta: [
      { title: "Réserver une voiture avec chauffeur — Cortège & Cérémonie" },
      { name: "description", content: "Demandez une voiture avec chauffeur pour un mariage, un transport familial ou un aller-retour." },
      { property: "og:title", content: "Réserver une voiture avec chauffeur" },
      { property: "og:description", content: "Mariage, transport familial vers la salle des fêtes, aller-retour." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Booking,
});

const schema = z
  .object({
    first_name: z.string().trim().min(1, "Prénom requis").max(80),
    last_name: z.string().trim().min(1, "Nom requis").max(80),
    phone: z.string().trim().regex(/^[+0-9 .()-]{6,20}$/, "Téléphone invalide"),
    service_type: z.enum(["wedding", "family", "round_trip", "private"]),
    city: z.string().trim().min(1, "Ville requise").max(80),
    pickup_address: z.string().trim().min(3, "Adresse de départ requise").max(250),
    destination_type: z.string().min(1),
    venue: z.string().trim().min(3, "Destination requise").max(250),
    wedding_date: z.string().min(1, "Date requise"),
    wedding_time: z.string().min(1, "Heure de départ requise"),
    return_time: z.string().optional(),
    passengers: z.coerce.number().int().min(1, "Au moins 1 passager").max(60),
    vehicle_type: z.string().max(80),
    trip_type: z.enum(["one_way", "round_trip"]),
    car_name: z.string().max(120),
    message: z.string().trim().max(1500),
  })
  .refine((d) => d.trip_type === "one_way" || !!d.return_time, { message: "Heure de retour requise pour un aller-retour", path: ["return_time"] })
  .refine((d) => d.wedding_date >= new Date().toISOString().slice(0, 10), { message: "La date doit être à venir", path: ["wedding_date"] });

function Booking() {
  const { car } = Route.useSearch();
  const { data: auth, isLoading } = useAuth();
  const { data: cars } = useQuery({ queryKey: ["cars"], queryFn: () => fetchCars() });
  const qc = useQueryClient();
  const [service, setService] = useState("wedding");
  const [trip, setTrip] = useState("one_way");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<string | null>(null);

  const isRound = service === "round_trip" || trip === "round_trip";
  const selected = cars?.find((c) => c.slug === car);

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
    if (error) { setErrors({ form: "L’envoi a échoué, merci de réessayer." }); return; }
    qc.invalidateQueries({ queryKey: ["my-requests"] });
    setDone(row.reference);
  }

  const err = (k: string) => errors[k] && <span className="form-error">{errors[k]}</span>;

  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="section-heading center">
          <span className="eyebrow">Réservation</span>
          <h1>Réserver une voiture avec chauffeur</h1>
          <p>Mariage, transport de vos proches vers la salle des fêtes ou trajet privé : décrivez votre besoin, un responsable vous recontacte.</p>
        </div>
        <div className="form-panel">
          {done ? (
            <div className="confirmation">
              <CheckCircle2 />
              <h3>Demande envoyée</h3>
              <p>Votre demande <strong className="text-primary">{done}</strong> a bien été transmise. Un responsable vous contactera rapidement pour la confirmer.</p>
              <div className="action-row justify-center mt-6">
                <Button asChild className="ref-btn"><Link to="/compte">Suivre ma demande</Link></Button>
              </div>
            </div>
          ) : isLoading ? <p>Chargement…</p> : !auth?.userId ? (
            <div className="confirmation">
              <h3>Connectez-vous pour réserver</h3>
              <p>Un compte vous permet de suivre le statut de votre demande à tout moment.</p>
              <div className="action-row justify-center mt-6">
                <Button asChild className="ref-btn"><Link to="/auth" search={{ redirect: "/reserver" }}>Se connecter ou créer un compte</Link></Button>
              </div>
            </div>
          ) : (
            <form onSubmit={submit} noValidate>
              <div className="form-section">
                <h3>Le service</h3>
                <div className="ref-form">
                  <label className="form-field form-wide"><span>Type de service</span>
                    <select name="service_type" value={service} onChange={(e) => setService(e.target.value)}>
                      {SERVICE_TYPES.map((s) => <option key={s.value} value={s.value}>{s.label}</option>)}
                    </select>
                  </label>
                  {service !== "round_trip" && (
                    <label className="form-field"><span>Nombre de trajets</span>
                      <select name="trip_type" value={trip} onChange={(e) => setTrip(e.target.value)}>
                        <option value="one_way">Aller simple</option>
                        <option value="round_trip">Aller-retour</option>
                      </select>
                    </label>
                  )}
                  <label className="form-field"><span>Nombre de passagers</span><input name="passengers" type="number" min={1} defaultValue={service === "wedding" ? 2 : 4} />{err("passengers")}</label>
                  <label className="form-field"><span>Type de voiture souhaité</span>
                    <select name="vehicle_type" defaultValue={selected?.category ?? ""}>
                      <option value="">Sans préférence</option>
                      {VEHICLE_TYPES.map((v) => <option key={v}>{v}</option>)}
                    </select>
                  </label>
                  <label className="form-field"><span>Véhicule précis (facultatif)</span>
                    <select name="car_name" defaultValue={selected?.name ?? ""}>
                      <option value="">Sans préférence</option>
                      {(cars ?? []).map((c) => <option key={c.id}>{c.name}</option>)}
                    </select>
                  </label>
                </div>
              </div>
              <div className="form-section">
                <h3>Trajet et horaires</h3>
                <div className="ref-form">
                  <label className="form-field form-wide"><span>Adresse de départ</span><input name="pickup_address" placeholder={service === "wedding" ? "Domicile ou lieu de préparation" : "Votre domicile"} />{err("pickup_address")}</label>
                  <label className="form-field"><span>Destination</span>
                    <select name="destination_type" defaultValue={service === "family" || service === "round_trip" ? "salle" : "autre"}>
                      <option value="salle">Salle des fêtes</option>
                      <option value="mairie">Mairie / lieu de cérémonie</option>
                      <option value="domicile">Domicile</option>
                      <option value="autre">Autre lieu</option>
                    </select>
                  </label>
                  <label className="form-field"><span>Ville</span><input name="city" />{err("city")}</label>
                  <label className="form-field form-wide"><span>Adresse de destination</span><input name="venue" placeholder="Nom et adresse de la salle ou du lieu" />{err("venue")}</label>
                  <label className="form-field"><span>Date du service</span><input name="wedding_date" type="date" />{err("wedding_date")}</label>
                  <label className="form-field"><span>Heure de départ</span><input name="wedding_time" type="time" />{err("wedding_time")}</label>
                  {isRound && (
                    <label className="form-field"><span>Heure de retour</span><input name="return_time" type="time" />{err("return_time")}</label>
                  )}
                </div>
              </div>
              <div className="form-section">
                <h3>Vos coordonnées</h3>
                <div className="ref-form">
                  <label className="form-field"><span>Prénom</span><input name="first_name" />{err("first_name")}</label>
                  <label className="form-field"><span>Nom</span><input name="last_name" />{err("last_name")}</label>
                  <label className="form-field"><span>Téléphone</span><input name="phone" type="tel" />{err("phone")}</label>
                  <label className="form-field"><span>E-mail</span><input value={auth.email ?? ""} disabled /></label>
                  <label className="form-field form-wide"><span>Informations supplémentaires</span><textarea name="message" placeholder="Décoration, sièges enfants, arrêts intermédiaires…" /></label>
                </div>
              </div>
              {err("form")}
              <Button type="submit" className="ref-btn mt-6 w-full" disabled={busy}>{busy ? "Envoi en cours…" : "Envoyer ma demande"}</Button>
            </form>
          )}
        </div>
      </div>
    </section>
  );
}
