import { createFileRoute, Link } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useAuth } from "@/lib/use-auth";
import { BOOKING_STATUS, HISTORY_STATUS, serviceLabel } from "@/lib/platform";
import { labelOf, useI18n } from "@/lib/i18n";
import { StatusPill } from "@/components/site-chrome";
import { NotificationsPanel } from "@/components/notifications-panel";

export const Route = createFileRoute("/_authenticated/compte")({
  head: () => ({ meta: [{ title: "Mes demandes — Far7tek" }, { name: "robots", content: "noindex" }] }),
  component: Account,
});

function Account() {
  const { t, lang, date, dateTime } = useI18n();
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
  const st = (s: string) => labelOf(BOOKING_STATUS, s, lang);
  return (
    <section className="section-ref">
      <div className="container-ref">
        <div className="admin-header">
          <div>
            <span className="eyebrow">{t("Espace client", "Client area", "فضاء العميل")}</span>
            <h1>{t("Mes demandes", "My requests", "طلباتي")}</h1>
            <p dir="ltr" className="text-start">{auth?.email}</p>
          </div>
          <div className="admin-actions"><Button asChild className="ref-btn"><Link to="/reserver">{t("Nouvelle demande", "New request", "طلب جديد")}</Link></Button></div>
        </div>
        {isLoading ? <p>{t("Chargement…", "Loading…", "جارٍ التحميل…")}</p> : !data?.length ? (
          <div className="registry admin-empty">{t("Aucune demande pour le moment.", "No requests yet.", "لا توجد طلبات حالياً.")}</div>
        ) : (
          <div className="admin-list-grid">
            {data.map((r) => (
              <div key={r.id} className="admin-list-card">
                <div className="car-meta"><span>{t("Réf.", "Ref.", "مرجع")} {r.reference}</span><StatusPill label={st(r.status)} /></div>
                <h3>{serviceLabel(r.service_type, lang)}</h3>
                <p>{date(r.wedding_date)} · {t("départ", "departure", "الانطلاق")} {r.wedding_time.slice(0, 5)}{r.return_time ? ` · ${t("retour", "return", "العودة")} ${r.return_time.slice(0, 5)}` : ""}</p>
                <p>{r.pickup_address} → {r.venue}<br />{r.passengers} {t("passager(s)", "passenger(s)", "راكب")} · {r.trip_type === "round_trip" ? t("Aller-retour", "Round trip", "ذهاب وإياب") : t("Aller simple", "One way", "ذهاب فقط")}</p>
                <details>
                  <summary className="tile-link cursor-pointer">{t("Historique", "History", "السجل")}</summary>
                  {[...r.trip_status_history].sort((a, b) => a.created_at.localeCompare(b.created_at)).map((h, i) => (
                    <div key={i} className="note-row"><small>{dateTime(h.created_at)}</small> {labelOf(HISTORY_STATUS, h.status, lang)} {h.note && `— ${h.note}`}</div>
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
