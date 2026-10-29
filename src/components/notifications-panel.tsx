import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";

export function NotificationsPanel({ admin = false }: { admin?: boolean }) {
  const qc = useQueryClient();
  const { data } = useQuery({
    queryKey: ["notifications", admin],
    queryFn: async () => {
      let q = supabase.from("notifications").select("*").order("created_at", { ascending: false }).limit(50);
      q = admin ? q.eq("audience", "admin") : q.eq("audience", "user");
      const { data } = await q;
      return data ?? [];
    },
  });
  async function markAll() {
    const ids = (data ?? []).filter((n) => !n.read).map((n) => n.id);
    if (ids.length) await supabase.from("notifications").update({ read: true }).in("id", ids);
    qc.invalidateQueries({ queryKey: ["notifications"] });
  }
  return (
    <div className="registry">
      <div className="registry-toolbar">
        <h3>Notifications</h3>
        <Button variant="outline" className="ref-btn" onClick={markAll}>Tout marquer comme lu</Button>
      </div>
      {!data?.length ? <p className="admin-empty">Aucune notification.</p> : data.map((n) => (
        <div key={n.id} className="note-row" style={{ opacity: n.read ? 0.6 : 1 }}>
          <strong className="text-primary">{n.title}</strong>
          <p>{n.body}</p>
          <small>{new Date(n.created_at).toLocaleString("fr-FR")}</small>
        </div>
      ))}
      <p className="mt-4 text-[10px]">Notifications internes. L’envoi par e-mail ou SMS pourra être ajouté plus tard.</p>
    </div>
  );
}
