import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";
import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";

type Ctx = { supabase: any; userId: string };

async function assertAdmin(ctx: Ctx) {
  const { data } = await ctx.supabase.rpc("has_role", { _user_id: ctx.userId, _role: "admin" });
  if (!data) throw new Error("Accès réservé aux administrateurs");
  const { supabaseAdmin } = await import("@/integrations/supabase/client.server");
  return supabaseAdmin;
}

async function findUserByEmail(admin: any, email: string) {
  for (let page = 1; page < 50; page++) {
    const { data } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    const u = data?.users?.find((x: any) => x.email?.toLowerCase() === email.toLowerCase());
    if (u) return u;
    if (!data?.users || data.users.length < 200) return null;
  }
  return null;
}

export const approvePartner = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ id: z.string().uuid(), origin: z.string().url() }).parse(d))
  .handler(async ({ data, context }) => {
    const admin = await assertAdmin(context as Ctx);
    const { data: p, error } = await admin.from("car_proposals").select("*").eq("id", data.id).single();
    if (error || !p) throw new Error("Dossier introuvable");
    if (p.status === "approved") return { ok: true, invited: false };

    // Secure invitation: the owner chooses their own password via the e-mailed link.
    let invited = false;
    let user = await findUserByEmail(admin, p.email);
    if (!user) {
      const inv = await admin.auth.admin.inviteUserByEmail(p.email, {
        redirectTo: `${data.origin}/reinitialiser`,
        data: { first_name: p.first_name, last_name: p.last_name },
      });
      if (inv.error) throw new Error("Invitation impossible : " + inv.error.message);
      user = inv.data.user;
      invited = true;
    }
    const uid = user!.id;
    await admin.from("user_roles").upsert({ user_id: uid, role: "partner" }, { onConflict: "user_id,role" });
    await admin.from("profiles").upsert({ id: uid, first_name: p.first_name, last_name: p.last_name, phone: p.phone });

    const slug = `${p.brand}-${p.model}-${p.id.slice(0, 6)}`.toLowerCase().normalize("NFD").replace(/[^a-z0-9]+/g, "-");
    const { data: car, error: carErr } = await admin
      .from("cars")
      .insert({
        name: `${p.brand} ${p.model}`, brand: p.brand, model: p.model, slug, year: p.year, color: p.color,
        category: p.vehicle_type, short_description: p.description.slice(0, 140), description: p.description,
        price_from: p.desired_rate || null, availability: p.availability, active: false, validation_status: "pending",
        owner_id: uid, seats: p.seats, city: p.city, services: p.services,
      })
      .select("id")
      .single();
    if (carErr) throw new Error(carErr.message);

    const { data: imgs } = await admin.from("proposal_images").select("*").eq("proposal_id", p.id);
    let order = 0;
    for (const img of imgs ?? []) {
      if (img.kind === "document") continue;
      const dest = `${uid}/${car.id}/${img.storage_path.split("/").pop()}`;
      const cp = await admin.storage.from("proposal-images").copy(img.storage_path, dest, { destinationBucket: "car-images" });
      if (!cp.error) {
        await admin.from("car_images").insert({ car_id: car.id, storage_path: dest, is_cover: img.kind === "main", sort_order: order++ });
      }
    }

    await admin.from("car_proposals").update({ status: "approved", partner_user_id: uid, car_id: car.id }).eq("id", p.id);
    await admin.from("notifications").insert({
      user_id: uid, title: "Dossier accepté",
      body: "Bienvenue parmi nos partenaires. Votre véhicule sera publié après validation finale.", link: "/partenaire",
    });
    return { ok: true, invited };
  });

export const reviewPartner = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) =>
    z.object({ id: z.string().uuid(), action: z.enum(["reject", "info", "reviewing"]), message: z.string().trim().max(1000).default("") }).parse(d),
  )
  .handler(async ({ data, context }) => {
    const admin = await assertAdmin(context as Ctx);
    if (data.action !== "reviewing" && !data.message) throw new Error("Merci d’indiquer un motif ou un message");
    const patch =
      data.action === "reject" ? { status: "rejected", rejection_reason: data.message }
      : data.action === "info" ? { status: "info_requested", info_request: data.message }
      : { status: "reviewing" };
    const { error } = await admin.from("car_proposals").update(patch as any).eq("id", data.id);
    if (error) throw new Error(error.message);
    return { ok: true };
  });

export const setCarValidation = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ carId: z.string().uuid(), status: z.enum(["active", "disabled", "pending"]) }).parse(d))
  .handler(async ({ data, context }) => {
    const admin = await assertAdmin(context as Ctx);
    const { data: car } = await admin.from("cars").update({ validation_status: data.status, active: data.status === "active" }).eq("id", data.carId).select("owner_id,name").single();
    if (car?.owner_id) {
      await admin.from("notifications").insert({
        user_id: car.owner_id, title: data.status === "active" ? "Véhicule publié" : "Véhicule mis à jour",
        body: `${car.name} : ${data.status === "active" ? "visible sur la plateforme" : "non publié"}.`, link: "/partenaire",
      });
    }
    return { ok: true };
  });

export const assignTrip = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ bookingId: z.string().uuid(), partnerId: z.string().uuid(), carId: z.string().uuid().nullable() }).parse(d))
  .handler(async ({ data, context }) => {
    const admin = await assertAdmin(context as Ctx);
    const { data: existing } = await admin.from("trip_assignments").select("id").eq("booking_request_id", data.bookingId).neq("status", "rejected");
    if (existing && existing.length) throw new Error("Cette demande est déjà attribuée");
    const { error } = await admin.from("trip_assignments").insert({ booking_request_id: data.bookingId, partner_id: data.partnerId, car_id: data.carId });
    if (error) throw new Error(error.message);
    const { data: b } = await admin.from("booking_requests").select("reference").eq("id", data.bookingId).single();
    await admin.from("trip_status_history").insert({ booking_request_id: data.bookingId, status: "assigned", changed_by: context.userId, note: "Attribuée à un partenaire" });
    await admin.from("notifications").insert({ user_id: data.partnerId, title: "Nouvelle demande attribuée", body: `Demande ${b?.reference ?? ""} à traiter.`, link: "/partenaire" });
    return { ok: true };
  });

export const setBookingStatus = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) =>
    z.object({
      id: z.string().uuid(),
      status: z.enum(["pending", "contacted", "accepted", "rejected", "confirmed", "in_progress", "completed", "cancelled"]),
      note: z.string().max(500).default(""),
    }).parse(d),
  )
  .handler(async ({ data, context }) => {
    const admin = await assertAdmin(context as Ctx);
    const { data: b, error } = await admin.from("booking_requests").update({ status: data.status as any }).eq("id", data.id).select("client_id,reference").single();
    if (error) throw new Error(error.message);
    await admin.from("trip_status_history").insert({ booking_request_id: data.id, status: data.status, changed_by: context.userId, note: data.note });
    if (b?.client_id) {
      await admin.from("notifications").insert({ user_id: b.client_id, title: "Mise à jour de votre demande", body: `Demande ${b.reference} : nouveau statut.`, link: "/compte" });
    }
    return { ok: true };
  });

export const reviewChangeRequest = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .inputValidator((d: unknown) => z.object({ id: z.string().uuid(), approve: z.boolean() }).parse(d))
  .handler(async ({ data, context }) => {
    const admin = await assertAdmin(context as Ctx);
    const { data: cr } = await admin.from("vehicle_change_requests").select("*").eq("id", data.id).single();
    if (!cr) throw new Error("Introuvable");
    if (data.approve) {
      const allowed = ["name", "color", "year", "seats", "description", "short_description", "price_from", "city", "category"];
      const patch: Record<string, unknown> = {};
      for (const k of allowed) if (k in (cr.changes as any)) (patch as any)[k] = (cr.changes as any)[k];
      await admin.from("cars").update(patch as any).eq("id", cr.car_id);
    }
    await admin.from("vehicle_change_requests").update({ status: data.approve ? "approved" : "rejected" }).eq("id", cr.id);
    await admin.from("notifications").insert({ user_id: cr.partner_id, title: data.approve ? "Modification validée" : "Modification refusée", body: "Votre demande de modification du véhicule a été traitée.", link: "/partenaire" });
    return { ok: true };
  });

export const listClients = createServerFn({ method: "POST" })
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }) => {
    const admin = await assertAdmin(context as Ctx);
    const { data } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
    const { data: roles } = await admin.from("user_roles").select("user_id,role");
    const { data: reqs } = await admin.from("booking_requests").select("client_id");
    return (data?.users ?? []).map((u: any) => ({
      id: u.id as string,
      email: (u.email ?? "") as string,
      created_at: u.created_at as string,
      last_sign_in_at: (u.last_sign_in_at ?? null) as string | null,
      roles: (roles ?? []).filter((r: any) => r.user_id === u.id).map((r: any) => r.role as string),
      requests: (reqs ?? []).filter((r: any) => r.client_id === u.id).length,
    }));
  });
