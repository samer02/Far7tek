import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useHydrated } from "@/lib/use-hydrated";
import { toast } from "sonner";
import { KeyRound } from "lucide-react";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { useI18n } from "@/lib/i18n";

export const Route = createFileRoute("/reinitialiser")({
  head: () => ({
    meta: [
      { title: "Choisir mon mot de passe — Far7tek" },
      { name: "description", content: "Définissez votre mot de passe pour accéder à votre espace Far7tek." },
      { property: "og:title", content: "Choisir mon mot de passe — Far7tek" },
      { property: "og:description", content: "Activation sécurisée de votre compte Far7tek." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ResetPage,
});

function ResetPage() {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  const hydrated = useHydrated();
  const navigate = useNavigate();
  const qc = useQueryClient();
  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const p = String(f.get("password")), c = String(f.get("confirm"));
    if (p.length < 8) { toast.error(t("8 caractères minimum", "8 characters minimum", "8 أحرف على الأقل")); return; }
    if (p !== c) { toast.error(t("Les mots de passe ne correspondent pas", "Passwords do not match", "كلمتا المرور غير متطابقتين")); return; }
    setBusy(true);
    const { data, error } = await supabase.auth.updateUser({ password: p });
    if (error || !data.user) {
      setBusy(false);
      toast.error(t("Lien expiré ou invalide. Demandez un nouveau lien depuis la page de connexion.", "Link expired or invalid. Request a new one from the sign-in page.", "الرابط منتهي أو غير صالح. اطلب رابطاً جديداً من صفحة الدخول."));
      return;
    }
    const { data: roles } = await supabase.from("user_roles").select("role").eq("user_id", data.user.id);
    const r = (roles ?? []).map((x) => x.role);
    setBusy(false);
    toast.success(t("Mot de passe enregistré", "Password saved", "تم حفظ كلمة المرور"));
    await qc.invalidateQueries({ queryKey: ["auth"] });
    navigate({ to: r.includes("admin") ? "/admin" : r.includes("partner") ? "/partenaire" : "/compte" });
  }
  return (
    <div className="auth-panel">
      <span className="eyebrow"><KeyRound className="h-3.5 w-3.5" />{t("Sécurité du compte", "Account security", "أمان الحساب")}</span>
      <h1>{t("Choisir mon mot de passe", "Choose my password", "اختر كلمة المرور")}</h1>
      <p>{t("Ce mot de passe vous permettra d’accéder à votre espace.", "You will use this password to access your area.", "ستستعمل كلمة المرور هذه للدخول إلى فضائك.")}</p>
      <form className="ref-form" onSubmit={submit}>
        <label className="form-field"><span>{t("Nouveau mot de passe", "New password", "كلمة المرور الجديدة")}</span><input name="password" type="password" autoComplete="new-password" required dir="ltr" /></label>
        <label className="form-field"><span>{t("Confirmation", "Confirm", "تأكيد")}</span><input name="confirm" type="password" autoComplete="new-password" required dir="ltr" /></label>
        <Button type="submit" className="ref-btn" disabled={busy || !hydrated}>{busy ? t("Enregistrement…", "Saving…", "جارٍ الحفظ…") : t("Enregistrer", "Save", "حفظ")}</Button>
      </form>
    </div>
  );
}
