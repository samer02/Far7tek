import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { BOOKING_STATUS, fmtDate, serviceLabel } from "@/lib/platform";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";

export const Route = createFileRoute("/_authenticated/compte")({
  head: () => ({ meta: [{ title: "Mes demandes — Cortège & Cérémonie" }, { name: "robots", content: "noindex" }] }),
  component: Account,
});

function Account() {
  const { data: auth } = useAuth();
  const { data, isLoading } = useQuery({
    queryKey: ["my-requests", auth?.userId],
    enabled: !!auth?.userId,
    queryFn: async () => {
      const { data } = await supabase
        .from("booking_requests")
        .select("*, trip_status_history(status,note,created_at)")
        .eq("client_id", auth!.userId!)
        .order("created_at", { ascending: false });
      return data ?? [];
    },
  });
  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header">
          <div>
            <span className="eyebrow">Espace client</span>
            <h1>Mes demandes</h1>
            <p>{auth?.email}</p>
          </div>
          <div className="admin-actions"><Button asChild className="ref-btn"><Link to="/reserver">Nouvelle demande</Link></Button></div>
        </div>
        {isLoading ? <p>Chargement…</p> : !data?.length ? (
          <div className="registry admin-empty">Aucune demande pour le moment.</div>
        ) : (
          <div className="admin-list-grid">
            {data.map((r) => (
              <div key={r.id} className="admin-list-card">
                <div className="car-meta"><span>Réf. {r.reference}</span><StatusPill label={BOOKING_STATUS[r.status] ?? r.status} /></div>
                <h3>{serviceLabel(r.service_type)}</h3>
                <p>{fmtDate(r.wedding_date)} · départ {r.wedding_time.slice(0, 5)}{r.return_time ? ` · retour ${r.return_time.slice(0, 5)}` : ""}</p>
                <p>{r.pickup_address} → {r.venue}<br />{r.passengers} passager(s) · {r.trip_type === "round_trip" ? "Aller-retour" : "Aller simple"}</p>
                <details>
                  <summary className="tile-link">Historique</summary>
                  {[...r.trip_status_history].sort((a, b) => a.created_at.localeCompare(b.created_at)).map((h, i) => (
                    <div key={i} className="note-row"><small>{new Date(h.created_at).toLocaleString("fr-FR")}</small> {BOOKING_STATUS[h.status] ?? h.status} {h.note && `— ${h.note}`}</div>
                  ))}
                </details>
              </div>
            ))}
          </div>
        )}
        <div className="mt-10"><NotificationsPanel /></div>
      </div>
    </section>
  );
}
