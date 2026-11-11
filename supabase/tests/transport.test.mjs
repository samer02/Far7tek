// End-to-end database test of the transport workflow, permissions and GPS rules.
// Runs the real setup_external_db.sql + migrations in an in-process Postgres (PGlite) with a
// minimal stand-in for Supabase's auth/storage schemas. Usage: npm run test:db
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { uuid_ossp } from "@electric-sql/pglite/contrib/uuid_ossp";
import { btree_gist } from "@electric-sql/pglite/contrib/btree_gist";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const read = (p) => readFileSync(join(root, p), "utf8");

const SUPABASE_STUB = `
CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN; CREATE ROLE service_role NOLOGIN BYPASSRLS;
CREATE SCHEMA auth; CREATE SCHEMA storage;
CREATE TABLE auth.users (id uuid PRIMARY KEY, email text, email_confirmed_at timestamptz, created_at timestamptz DEFAULT now(), last_sign_in_at timestamptz);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon') $$;
CREATE TABLE storage.buckets (id text PRIMARY KEY, name text, public boolean);
CREATE TABLE storage.objects (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text, name text);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA public, auth, storage TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated;
CREATE PUBLICATION supabase_realtime;
`;

const db = new PGlite({ extensions: { pgcrypto, uuid_ossp, btree_gist } });
let passed = 0;
let failed = 0;
const ok = (cond, name, extra = "") => {
  if (cond) { passed++; console.log(`  ✓ ${name}`); }
  else { failed++; console.log(`  ✗ ${name} ${extra}`); }
};

const U = {
  admin: "00000000-0000-0000-0000-0000000000a1",
  owner: "00000000-0000-0000-0000-0000000000b1",
  owner2: "00000000-0000-0000-0000-0000000000b2",
  client: "00000000-0000-0000-0000-0000000000c1",
  client2: "00000000-0000-0000-0000-0000000000c2",
  stranger: "00000000-0000-0000-0000-0000000000d1",
};

/** Run a query as a given user (null = anonymous visitor), like PostgREST does. */
async function as(user, sql, params = []) {
  await db.exec(`SET ROLE ${user ? "authenticated" : "anon"}; SELECT set_config('request.jwt.claim.sub', '${user ?? ""}', false), set_config('request.jwt.claim.role', '${user ? "authenticated" : "anon"}', false);`);
  try { return await db.query(sql, params); }
  finally { await db.exec(`RESET ROLE; SELECT set_config('request.jwt.claim.sub', '', false);`); }
}
async function fails(user, sql, params, pattern, name) {
  try { await as(user, sql, params); ok(false, name, "(expected an error)"); }
  catch (e) { ok(pattern ? new RegExp(pattern, "i").test(e.message) : true, name, `got: ${e.message}`); }
}
const one = async (user, sql, params) => (await as(user, sql, params)).rows[0];
const val = async (user, sql, params) => Object.values((await one(user, sql, params)) ?? {})[0];

console.log("Schema");
await db.exec(SUPABASE_STUB);
await db.exec(read("supabase/setup_external_db.sql"));
await db.exec(read("drizzle/migrations/0000_admin_partner_actions_as_db_functions.sql"));
await db.exec(read("drizzle/migrations/0001_transport_management.sql"));
await db.exec(read("drizzle/migrations/0001_transport_management.sql"));
ok(true, "setup + migrations apply, and the transport migration re-runs cleanly");
const pub = await db.query(`SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime' ORDER BY 1`);
ok(pub.rows.map((r) => r.tablename).join(",") === "booking_requests,journey_events,journey_stages,live_locations", "realtime publication covers journey tables");

await db.exec(`
  INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('${U.admin}', 'admin@test.tn', now()), ('${U.owner}', 'owner@test.tn', now()), ('${U.owner2}', 'owner2@test.tn', now()),
    ('${U.client}', 'client@test.tn', now()), ('${U.client2}', 'client2@test.tn', now()), ('${U.stranger}', 'x@test.tn', now());
  INSERT INTO public.user_roles (user_id, role) VALUES ('${U.admin}', 'admin'), ('${U.owner}', 'partner'), ('${U.owner2}', 'partner');
  INSERT INTO public.profiles (id, first_name, last_name, phone) VALUES
    ('${U.owner}', 'Sami', 'Ben Ali', '+216 20 111 222'), ('${U.owner2}', 'Lina', 'Trabelsi', '+216 98 333 444');
`);

console.log("Catalog (admin)");
const wedding = await val(U.admin, `INSERT INTO cars (name, brand, model, slug, year, category, services, seats, owner_id, transmission, fuel_type, equipment, is_new_arrival, featured, active, city)
  VALUES ('Mercedes Classe S', 'Mercedes', 'Classe S', 'mercedes-s-test', 2023, 'Berline de prestige', '{wedding}', 4, $1, 'automatic', 'diesel', '{air_conditioning,flower_decoration}', true, true, true, 'Tunis') RETURNING id`, [U.owner]);
const family = await val(U.admin, `INSERT INTO cars (name, brand, model, slug, year, category, services, seats, owner_id, transmission, fuel_type, active, city)
  VALUES ('Mercedes Vito', 'Mercedes', 'Vito', 'vito-test', 2021, 'Van / minibus', '{family}', 8, $1, 'manual', 'diesel', true, 'Sfax') RETURNING id`, [U.owner2]);
ok(!!wedding && !!family, "admin creates a wedding car and a family car");
await fails(U.owner, `INSERT INTO cars (name, brand, model, slug, category) VALUES ('x','x','x','x','x')`, [], "row-level security", "owners cannot create catalog cars");
await as(U.admin, `UPDATE cars SET active = false WHERE id = $1`, [family]);
ok((await as(null, `SELECT id FROM cars WHERE id = $1`, [family])).rows.length === 0, "unpublished car is hidden from the public");
await as(U.admin, `UPDATE cars SET active = true WHERE id = $1`, [family]);
ok(Number(await val(null, `SELECT count(*) FROM audit_log`).catch(() => -1)) === -1, "public cannot read the audit log");
ok(Number(await val(U.admin, `SELECT count(*) FROM audit_log WHERE entity = 'car'`)) >= 4, "catalog changes are audited");

console.log("Phone privacy");
const carCols = (await as(null, `SELECT * FROM cars WHERE id = $1`, [wedding])).fields.map((f) => f.name);
ok(!carCols.some((c) => /phone|email/.test(c)), "public car rows carry no phone or e-mail column");
ok((await as(null, `SELECT * FROM profiles`)).rows.length === 0, "anonymous visitors read no profile");
ok((await as(U.client, `SELECT * FROM profiles`)).rows.length === 0, "clients cannot read owner profiles");
ok((await as(U.admin, `SELECT phone FROM profiles WHERE id = $1`, [U.owner])).rows[0]?.phone === "+216 20 111 222", "admin reads the owner's private phone");
ok((await as(U.admin, `SELECT * FROM admin_list_owners()`)).rows.some((r) => r.phone === "+216 20 111 222"), "admin_list_owners returns owner contacts");
await fails(U.client, `SELECT * FROM admin_list_owners()`, [], "administrateurs", "clients cannot list owner contacts");
await fails(null, `SELECT * FROM admin_list_owners()`, [], "permission denied", "anonymous cannot call admin functions");

console.log("Availability");
await as(U.owner, `SELECT owner_set_availability_mode($1, 'schedule')`, [wedding]);
// Every day 08:00-23:00 except Tuesday; plus a full unavailable date 40 days ahead.
await as(U.owner, `INSERT INTO car_availability_rules (car_id, kind, available, weekday, start_time, end_time)
  SELECT $1, 'weekly', true, d, '00:00', '24:00' FROM generate_series(0, 6) d WHERE d <> 2`, [wedding]);
await as(U.owner, `INSERT INTO car_availability_rules (car_id, kind, available, weekday) VALUES ($1, 'weekly', false, 2)`, [wedding]);
await as(U.owner, `INSERT INTO car_availability_rules (car_id, kind, available, date_from, date_to) VALUES ($1, 'dates', false, (now() AT TIME ZONE 'Africa/Tunis')::date + 40, (now() AT TIME ZONE 'Africa/Tunis')::date + 40)`, [wedding]);
await fails(U.stranger, `INSERT INTO car_availability_rules (car_id, kind, available, weekday) VALUES ($1, 'weekly', true, 1)`, [wedding], "row-level security", "other users cannot edit an owner's schedule");
await fails(U.owner2, `SELECT owner_set_availability_mode($1, 'always')`, [wedding], "introuvable", "owners cannot change another owner's car");
await fails(null, `SELECT * FROM car_availability_rules`, [], "permission denied", "anonymous cannot read schedules");
await fails(U.owner, `INSERT INTO car_availability_rules (car_id, kind, available, weekday, start_time, end_time) VALUES ($1, 'weekly', true, 1, '18:00', '08:00')`, [wedding], "car_availability_hours", "inverted hours are rejected");
const tuesday = await val(null, `SELECT d FROM generate_series((now() AT TIME ZONE 'Africa/Tunis')::date + 3, (now() AT TIME ZONE 'Africa/Tunis')::date + 10, '1 day') d WHERE extract(dow FROM d) = 2 LIMIT 1`);
const tues = new Date(tuesday).toISOString().slice(0, 10);
ok(await val(U.client, `SELECT car_window_status($1, ($2::date + time '10:00') AT TIME ZONE 'Africa/Tunis', ($2::date + time '12:00') AT TIME ZONE 'Africa/Tunis')`, [wedding, tues]) === "unavailable", "weekly unavailable day is detected");

console.log("Client request");
const day = (n) => `(now() AT TIME ZONE 'Africa/Tunis')::date + ${n}`;
const futureDate = await val(null, `SELECT d::text FROM generate_series(${day(3)}, ${day(12)}, '1 day') d WHERE extract(dow FROM d) NOT IN (2) LIMIT 1`);
const req = (over = {}) => JSON.stringify({
  category: "wedding", car_id: wedding, date: futureDate, time: "15:00", round_trip: true, return_time: "23:30", passengers: 2,
  first_name: "Amel", last_name: "Client", phone: "+216 55 000 111", city: "Tunis",
  pickup_address: "Rue de Marseille, Tunis", pickup_lat: 36.8, pickup_lng: 10.18,
  destination_address: "Salle des fêtes, La Marsa", destination_lat: 36.88, destination_lng: 10.32,
  stops: [{ address: "Fleuriste, Lac 2", lat: 36.84, lng: 10.27 }], requirements: "Décoration blanche", client_notes: "Appeler après 18h", contact_extra: "Frère : 22 000 000",
  ...over,
});
const r1 = await val(U.client, `SELECT transport_submit_request($1::jsonb)`, [req()]);
ok(/^F7-[0-9A-F]{6}$/.test(r1.reference) && r1.availability === "available", "request saved with a unique reference", JSON.stringify(r1));
const b1 = r1.id;
const row1 = await one(U.client, `SELECT status, owner_id, category, stops, service_start_at, service_end_at FROM booking_requests WHERE id = $1`, [b1]);
ok(row1.status === "pending" && row1.owner_id === U.owner && row1.category === "wedding", "status Pending, linked to car owner");
ok((await as(U.client, `SELECT stage_no, label FROM journey_stages WHERE booking_request_id = $1 ORDER BY stage_no`, [b1])).rows.map((r) => r.label).join(",") === "Aller,Retour", "round trip creates Part 1 and Part 2");
ok(Number(await val(U.admin, `SELECT count(*) FROM notifications WHERE audience = 'admin' AND title = 'Nouvelle demande de transport'`)) === 1, "admin is notified");
await fails(U.client, `SELECT transport_submit_request($1::jsonb)`, [req({ pickup_lat: null })], "carte", "coordinates are required");
await fails(U.client, `SELECT transport_submit_request($1::jsonb)`, [req({ passengers: 9 })], "passagers", "seat capacity is enforced");
await fails(U.client, `SELECT transport_submit_request($1::jsonb)`, [req({ category: "family" })], "service", "car must offer the requested category");
await fails(U.client, `SELECT transport_submit_request($1::jsonb)`, [req({ date: "2020-01-01" })], "venir", "past dates are rejected");
await fails(null, `SELECT transport_submit_request($1::jsonb)`, [req()], "permission denied", "anonymous cannot submit");
ok((await as(U.stranger, `SELECT * FROM booking_requests WHERE id = $1`, [b1])).rows.length === 0, "other users cannot read the request");
ok((await as(U.owner, `SELECT * FROM booking_requests WHERE id = $1`, [b1])).rows.length === 0, "owner has no direct access to the client's row (phone)");
ok((await val(U.owner, `SELECT owner_transport_operations()`)).length === 0, "owner does not see unapproved requests");
ok((await as(U.owner, `SELECT * FROM journey_stages WHERE booking_request_id = $1`, [b1])).rows.length === 0, "owner cannot read stages before approval");

console.log("Admin approval and conflicts");
const r2 = await val(U.client2, `SELECT transport_submit_request($1::jsonb)`, [req({ time: "16:00", round_trip: false, return_time: "", first_name: "Rim" })]);
ok(!!r2.id, "a second, overlapping request can still be submitted while the first is pending");
await as(U.admin, `SELECT admin_transport_set_status($1, 'under_review', '')`, [b1]);
await as(U.admin, `SELECT admin_transport_log_contact($1, 'owner')`, [b1]);
const ap = await val(U.admin, `SELECT admin_transport_set_status($1, 'approved', 'Accord du propriétaire par téléphone')`, [b1]);
ok(ap.status === "approved", "admin approves after phone coordination");
await fails(U.admin, `SELECT admin_transport_set_status($1, 'approved', '')`, [r2.id], "Conflit", "approving an overlapping request on the same car is refused");
await fails(U.admin, `SELECT admin_transport_set_status($1, 'rejected', '')`, [r2.id], "motif", "rejection requires a reason");
await as(U.admin, `SELECT admin_transport_set_status($1, 'rejected', 'Véhicule déjà réservé')`, [r2.id]);
ok((await one(U.client2, `SELECT status, decision_note FROM booking_requests WHERE id = $1`, [r2.id])).decision_note === "Véhicule déjà réservé", "client sees the rejection reason");
await fails(U.admin, `SELECT admin_transport_set_status($1, 'in_progress', '')`, [b1], "non autorisée", "admin approval cannot jump to In Progress");
const r3 = await val(U.client2, `SELECT transport_submit_request($1::jsonb)`, [req({ date: tues, round_trip: false, return_time: "" })]);
ok(r3.availability === "unavailable", "submission reports an unavailable slot");
await fails(U.admin, `SELECT admin_transport_set_status($1, 'approved', '')`, [r3.id], "indisponible", "approval respects the owner's schedule");
const forced = await val(U.admin, `SELECT admin_transport_set_status($1, 'approved', 'Exception validée', true)`, [r3.id]);
ok(forced.status === "approved", "admin can force after explicit agreement");
await as(U.admin, `SELECT admin_transport_set_status($1, 'cancelled', '')`, [r3.id]);
await fails(U.client, `SELECT admin_transport_set_status($1, 'confirmed', '')`, [b1], "administrateurs", "clients cannot change statuses");

console.log("Owner confirmation");
await as(U.admin, `SELECT admin_transport_set_status($1, 'awaiting_owner', '')`, [b1]);
let ops = await val(U.owner, `SELECT owner_transport_operations()`);
const op1 = ops.find((o) => o.id === b1);
ok(op1?.status === "awaiting_owner" && op1.client_phone === null && op1.client_name === "Amel Client", "owner sees the booking, client phone withheld until confirmed");
ok(!JSON.stringify(ops).includes("Appeler après 18h"), "client's private note to the admin is never shared with the owner");
await fails(U.owner2, `SELECT owner_respond_booking($1, true, '')`, [b1], "introuvable", "another owner cannot confirm");
await as(U.owner, `SELECT owner_respond_booking($1, true, '')`, [b1]);
ops = await val(U.owner, `SELECT owner_transport_operations()`);
const op1c = ops.find((o) => o.id === b1);
ok(op1c?.status === "confirmed" && op1c.client_phone === "+216 55 000 111", "confirmed: owner now gets client contact");
await fails(U.client, `SELECT journey_start_stage(id) FROM journey_stages WHERE booking_request_id = '${b1}' AND stage_no = 1`, [], "Trop tôt|propriétaire", "journey cannot start days ahead / by client");
await fails(U.owner, `SELECT journey_start_stage(id) FROM journey_stages WHERE booking_request_id = '${b1}' AND stage_no = 1`, [], "Trop tôt", "owner cannot start more than 12 h early");
let excl = "";
try {
  await db.exec(`UPDATE booking_requests SET status = 'confirmed', service_start_at = (SELECT service_start_at FROM booking_requests WHERE id = '${b1}'),
    service_end_at = (SELECT service_end_at FROM booking_requests WHERE id = '${b1}'), car_id = '${wedding}' WHERE id = '${r2.id}'`);
} catch (e) { excl = e.message; }
ok(/booking_requests_no_overlap/.test(excl), "database exclusion constraint blocks two confirmed bookings on one car", excl);

console.log("Live operation");
// Move the confirmed booking to start in 30 minutes so it can be run now.
await db.exec(`UPDATE booking_requests SET service_start_at = now() + interval '30 minutes', service_end_at = now() + interval '9 hours' WHERE id = '${b1}'`);
const s1 = await val(U.owner, `SELECT id FROM journey_stages WHERE booking_request_id = $1 AND stage_no = 1`, [b1]);
const s2 = await val(U.owner, `SELECT id FROM journey_stages WHERE booking_request_id = $1 AND stage_no = 2`, [b1]);
const pushNA = await val(U.owner, `SELECT journey_push_location($1, 36.8, 10.18, 10)`, [b1]);
ok(pushNA.accepted === false && pushNA.reason === "not_active", "no GPS is accepted before the operation starts");
await fails(U.owner, `SELECT journey_start_stage($1)`, [s2], "précédente", "Part 2 cannot start before Part 1");
await fails(U.client, `SELECT journey_start_stage($1)`, [s1], "propriétaire", "client cannot start a stage");
await fails(U.stranger, `SELECT journey_push_location($1, 36.8, 10.18, 10)`, [b1], "autorisé", "strangers cannot push GPS");
const st1 = await val(U.owner, `SELECT journey_start_stage($1, 36.8001, 10.1801, 8)`, [s1]);
const st1b = await val(U.owner, `SELECT journey_start_stage($1, 36.9, 10.2, 8)`, [s1]);
ok(st1.already === false && st1b.already === true && st1b.stage.start_lat === 36.8001, "duplicate Start is idempotent and keeps the first record");
ok((await one(U.client, `SELECT status FROM booking_requests WHERE id = $1`, [b1])).status === "in_progress", "booking moves to In Progress on Part 1 start");
ok(Number(await val(U.admin, `SELECT count(*) FROM journey_events WHERE booking_request_id = $1 AND event_type = 'stage_started'`, [b1])) === 1, "a single start event is stored");
await fails(U.owner, `SELECT journey_start_stage($1)`, [s2], "précédente|en cours", "no second simultaneous stage");
let p = await val(U.owner, `SELECT journey_push_location($1, 36.8010, 10.1810, 12, 90, 11)`, [b1]);
ok(p.reason === "throttled", "updates closer than 2 s are throttled");
await db.exec(`UPDATE live_locations SET received_at = now() - interval '10 seconds', recorded_at = now() - interval '10 seconds' WHERE booking_request_id = '${b1}'`);
p = await val(U.owner, `SELECT journey_push_location($1, 36.8010, 10.1810, 12, 90, 11)`, [b1]);
ok(p.accepted === true, "owner GPS update accepted during the active stage");
await db.exec(`UPDATE live_locations SET received_at = now() - interval '10 seconds' WHERE booking_request_id = '${b1}'`);
p = await val(U.owner, `SELECT journey_push_location($1, 37.5, 11.0, 10)`, [b1]);
ok(p.accepted === false && p.reason === "implausible", "teleport-like jumps are rejected");
p = await val(U.owner, `SELECT journey_push_location($1, 36.82, 10.2, 5000)`, [b1]);
ok(p.accepted === false && p.reason === "inaccurate", "very inaccurate readings are rejected");
ok((await one(U.admin, `SELECT lat, tracking FROM live_locations WHERE booking_request_id = $1`, [b1])).lat === 36.801, "admin sees the live position");
ok((await as(U.client, `SELECT lat FROM live_locations WHERE booking_request_id = $1`, [b1])).rows.length === 1, "client sees their own running operation");
ok((await as(U.stranger, `SELECT lat FROM live_locations`)).rows.length === 0, "other users see no location");
ok((await as(U.owner2, `SELECT * FROM gps_location_updates`)).rows.length === 0, "other owners see no GPS history");
await fails(U.owner, `INSERT INTO live_locations (booking_request_id, lat, lng) VALUES ('${b1}', 1, 1)`, [], "permission denied", "locations cannot be written directly");
await fails(U.owner, `UPDATE journey_stages SET status = 'completed' WHERE id = '${s1}'`, [], "permission denied", "stages cannot be edited directly");
const stop = await val(U.owner, `SELECT journey_mark_stop($1, 0, 36.84, 10.27)`, [s1]);
ok(stop.already === false && (await val(U.client, `SELECT stops->0->>'reached_at' FROM journey_stages WHERE id = $1`, [s1])) != null, "intermediate stop marked as reached");
const sig1 = await val(U.client, `SELECT journey_client_signal($1, 'completion_requested')`, [s1]);
const sig2 = await val(U.client, `SELECT journey_client_signal($1, 'completion_requested')`, [s1]);
ok(sig1.already === false && sig2.already === true, "client completion request is recorded once");
const e1 = await val(U.owner, `SELECT journey_end_stage($1, 36.88, 10.32, 6)`, [s1]);
const e1b = await val(U.owner, `SELECT journey_end_stage($1, 30, 10, 6)`, [s1]);
ok(e1.operation_completed === false && e1b.already === true && e1b.stage.end_lat === 36.88, "Part 1 ends once; duplicate End is ignored");
ok((await one(U.admin, `SELECT tracking FROM live_locations WHERE booking_request_id = $1`, [b1])).tracking === false, "tracking pauses between stages");
await db.exec(`UPDATE live_locations SET received_at = now() - interval '10 seconds' WHERE booking_request_id = '${b1}'`);
p = await val(U.owner, `SELECT journey_push_location($1, 36.88, 10.32, 6)`, [b1]);
ok(p.accepted === false && p.reason === "no_active_stage", "no GPS accepted between Part 1 and Part 2");
await val(U.owner, `SELECT journey_start_stage($1, 36.8801, 10.3201, 7)`, [s2]);
await db.exec(`UPDATE live_locations SET received_at = now() - interval '10 seconds', recorded_at = now() - interval '60 seconds' WHERE booking_request_id = '${b1}'`);
p = await val(U.owner, `SELECT journey_push_location($1, 36.8790, 10.3190, 9)`, [b1]);
ok(p.accepted === true && (await one(U.admin, `SELECT lat, tracking FROM live_locations WHERE booking_request_id = $1`, [b1])).lat === 36.879, "Part 2 resumes live updates");
const e2 = await val(U.owner, `SELECT journey_end_stage($1, 36.8, 10.18, 5)`, [s2]);
ok(e2.operation_completed === true, "ending Part 2 completes the operation");
const fin = await as(U.client, `SELECT stage_no, status, started_at, ended_at, start_lat, end_lat, started_by FROM journey_stages WHERE booking_request_id = $1 ORDER BY stage_no`, [b1]);
ok(fin.rows.length === 2 && fin.rows.every((r) => r.status === "completed" && r.started_at && r.ended_at && r.started_by === U.owner) && fin.rows[0].start_lat === 36.8001, "both stages keep their own start/end history");
ok((await one(U.client, `SELECT status FROM booking_requests WHERE id = $1`, [b1])).status === "completed", "client sees Completed");
p = await val(U.owner, `SELECT journey_push_location($1, 36.8, 10.18, 5)`, [b1]);
ok(p.accepted === false && p.reason === "not_active", "GPS tracking stops after completion");
ok((await as(U.client, `SELECT * FROM live_locations WHERE booking_request_id = $1`, [b1])).rows.length === 0, "client loses live-location access after completion");
const last = await one(U.admin, `SELECT lat, tracking, received_at FROM live_locations WHERE booking_request_id = $1`, [b1]);
ok(last.tracking === false && last.lat === 36.8 && !!last.received_at, "admin keeps the last known position with its timestamp");
ok(Number(await val(U.admin, `SELECT count(*) FROM gps_location_updates WHERE booking_request_id = $1`, [b1])) === 6, "GPS history stored (stage start/end + accepted updates)");
ok(Number(await val(U.client, `SELECT count(*) FROM notifications WHERE user_id = $1 AND title = 'Transport terminé'`, [U.client])) === 1, "client notified of completion");
await fails(U.client, `SELECT transport_client_cancel($1, 'x')`, [b1], "plus être annulée", "completed requests cannot be cancelled");
ok(Number(await val(U.admin, `SELECT count(*) FROM audit_log WHERE entity = 'booking_request' AND entity_id = $1`, [b1])) >= 5, "important actions are audited");

console.log("Client cancellation");
const r4 = await val(U.client, `SELECT transport_submit_request($1::jsonb)`, [req({ car_id: family, category: "family", passengers: 6, round_trip: false, return_time: "" })]);
await as(U.client, `SELECT transport_client_cancel($1, 'Changement de programme')`, [r4.id]);
ok((await one(U.client, `SELECT status FROM booking_requests WHERE id = $1`, [r4.id])).status === "cancelled", "client cancels a pending request");
await fails(U.stranger, `SELECT transport_client_cancel($1, 'x')`, [b1], "introuvable", "others cannot cancel");

console.log("Catalog deletion guard");
const r5 = await val(U.client, `SELECT transport_submit_request($1::jsonb)`, [req({ car_id: family, category: "family", passengers: 6, round_trip: false, return_time: "", time: "10:00" })]);
await as(U.admin, `SELECT admin_transport_set_status($1, 'approved', '')`, [r5.id]);
await fails(U.admin, `DELETE FROM cars WHERE id = $1`, [family], "réservations actives", "a car holding an approved booking cannot be deleted");
await as(U.admin, `SELECT admin_transport_set_status($1, 'cancelled', '')`, [r5.id]);
await as(U.admin, `DELETE FROM cars WHERE id = $1`, [family]);
ok((await as(U.admin, `SELECT id FROM cars WHERE id = $1`, [family])).rows.length === 0, "the car can be deleted once no booking holds it");

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
