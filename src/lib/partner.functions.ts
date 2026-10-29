import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import { canPartnerMoveTo } from "@/lib/platform";

async function adminClient() {
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  return supabaseAdmin;
}

export const respondAssignment = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ id: z.string().uuid(), accept: z.boolean(), reason: z.string().trim().max(500).default("") }).parse(d))
  .handler(async ({ data, context }) => {
    // RLS: a partner can only read their own assignments.
    const { data: a } = await context.supabase.from("trip_assignments").select("*").eq("id", data.id).maybeSingle();
    if (!a || a.partner_id !== context.userId) throw new Error("Demande introuvable");
    if (a.status !== "proposed") throw new Error("Demande déjà traitée");
    if (!data.accept && !data.reason) throw new Error("Merci d’indiquer un motif de refus");
    const admin = await adminClient();
    await admin.from("trip_assignments").update({ status: data.accept ? "accepted" : "rejected", rejection_reason: data.accept ? null : data.reason, updated_at: new Date().toISOString() }).eq("id", a.id);
    if (data.accept) await admin.from("booking_requests").update({ status: "accepted" }).eq("id", a.booking_request_id);
    await admin.from("trip_status_history").insert({ booking_request_id: a.booking_request_id, status: data.accept ? "accepted" : "partner_rejected", changed_by: context.userId, note: data.reason });
    await admin.from("notifications").insert({ audience: "admin", title: data.accept ? "Trajet accepté par un partenaire" : "Trajet refusé par un partenaire", body: data.reason, link: "/admin" });
    if (data.accept) {
      const { data: b } = await admin.from("booking_requests").select("client_id,reference").eq("id", a.booking_request_id).single();
      if (b?.client_id) await admin.from("notifications").insert({ user_id: b.client_id, title: "Chauffeur trouvé", body: `Votre demande ${b.reference} a été acceptée.`, link: "/compte" });
    }
    return { ok: true };
  });

export const updateTripStatus = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ bookingId: z.string().uuid(), status: z.enum(["confirmed", "in_progress", "completed", "cancelled"]) }).parse(d))
  .handler(async ({ data, context }) => {
    const { data: b } = await context.supabase.from("booking_requests").select("id,status,client_id,reference").eq("id", data.bookingId).maybeSingle();
    if (!b) throw new Error("Demande introuvable");
    const { data: a } = await context.supabase.from("trip_assignments").select("status").eq("booking_request_id", b.id).eq("partner_id", context.userId).eq("status", "accepted").maybeSingle();
    if (!a) throw new Error("Vous devez d’abord accepter cette demande");
    if (!canPartnerMoveTo(b.status, data.status)) throw new Error("Changement de statut non autorisé");
    const admin = await adminClient();
    await admin.from("booking_requests").update({ status: data.status }).eq("id", b.id);
    await admin.from("trip_status_history").insert({ booking_request_id: b.id, status: data.status, changed_by: context.userId });
    if (b.client_id) await admin.from("notifications").insert({ user_id: b.client_id, title: "Mise à jour de votre trajet", body: `Demande ${b.reference} mise à jour.`, link: "/compte" });
    await admin.from("notifications").insert({ audience: "admin", title: "Statut de trajet modifié", body: `${b.reference} → ${data.status}`, link: "/admin" });
    return { ok: true };
  });

export const updateCarAvailability = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ carId: z.string().uuid(), availability: z.string().trim().min(1).max(300) }).parse(d))
  .handler(async ({ data, context }) => {
    const { data: car } = await context.supabase.from("cars").select("id,owner_id").eq("id", data.carId).maybeSingle();
    if (!car || car.owner_id !== context.userId) throw new Error("Véhicule introuvable");
    const admin = await adminClient();
    await admin.from("cars").update({ availability: data.availability }).eq("id", car.id);
    return { ok: true };
  });

export const addCarPhoto = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ carId: z.string().uuid(), path: z.string().min(3).max(300) }).parse(d))
  .handler(async ({ data, context }) => {
    const { data: car } = await context.supabase.from("cars").select("id,owner_id,name").eq("id", data.carId).maybeSingle();
    if (!car || car.owner_id !== context.userId || !data.path.startsWith(`${context.userId}/`)) throw new Error("Non autorisé");
    const admin = await adminClient();
    await admin.from("car_images").insert({ car_id: car.id, storage_path: data.path, sort_order: 50 });
    await admin.from("notifications").insert({ audience: "admin", title: "Nouvelle photo partenaire", body: car.name, link: "/admin" });
    return { ok: true };
  });
