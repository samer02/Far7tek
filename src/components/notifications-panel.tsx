import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Bell } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useI18n } from "@/lib/i18n";

export function NotificationsPanel({ admin = false }: { admin?: boolean }) {
  const { t, dateTime } = useI18n();
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
        <h3 className="flex items-center gap-2"><Bell className="h-5 w-5 text-primary" />{t("Notifications", "Notifications", "الإشعارات")}</h3>
        <Button variant="outline" className="ref-btn" onClick={markAll}>{t("Tout marquer comme lu", "Mark all as read", "تعليم الكل كمقروء")}</Button>
      </div>
      {!data?.length ? <p className="admin-empty">{t("Aucune notification.", "No notifications.", "لا توجد إشعارات.")}</p> : data.map((n) => (
        <div key={n.id} className="note-row" style={{ opacity: n.read ? 0.6 : 1 }}>
          <strong className="text-primary">{n.title}</strong>
          <p>{n.body}</p>
          <small>{dateTime(n.created_at)}</small>
        </div>
      ))}
      <p className="mt-4 text-xs">{t(
        "Notifications internes. L’envoi par e-mail ou SMS pourra être ajouté plus tard.",
        "In-app notifications. Email or SMS delivery can be added later.",
        "إشعارات داخلية. يمكن إضافة الإرسال عبر البريد أو الرسائل القصيرة لاحقاً.",
      )}</p>
    </div>
  );
}
