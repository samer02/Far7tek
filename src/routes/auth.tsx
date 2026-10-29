import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useHydrated } from "@/lib/use-hydrated";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import logoFull from "@/assets/far7tek-logo.png";
import { useI18n } from "@/lib/i18n";

export const Route = createFileRoute("/auth")({
  validateSearch: (s: Record<string, unknown>): { redirect?: string } => {
    const r = s["redirect"];
    return typeof r === "string" && r.startsWith("/") && !r.startsWith("//") ? { redirect: r } : {};
  },
  head: () => ({
    meta: [
      { title: "Connexion — Far7tek" },
      { name: "description", content: "Connectez-vous à Far7tek pour suivre vos demandes ou accéder à votre espace partenaire." },
      { property: "og:title", content: "Connexion — Far7tek" },
      { property: "og:description", content: "Espace client, partenaire et administration Far7tek." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: AuthPage,
});

function AuthPage() {
  const { t } = useI18n();
  const { redirect } = Route.useSearch();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [mode, setMode] = useState<"in" | "up" | "forgot">("in");
  const [busy, setBusy] = useState(false);
  const hydrated = useHydrated();

  async function afterLogin() {
    await qc.invalidateQueries({ queryKey: ["auth"] });
    const { data } = await supabase.auth.getUser();
    const { data: roles } = await supabase.from("user_roles").select("role").eq("user_id", data.user!.id);
    const r = (roles ?? []).map((x) => x.role);
    navigate({ to: redirect ?? (r.includes("admin") ? "/admin" : r.includes("partner") ? "/partenaire" : "/compte") });
  }

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const email = String(f.get("email") ?? "").trim();
    const password = String(f.get("password") ?? "");
    if (!/^\S+@\S+\.\S+$/.test(email)) { toast.error(t("E-mail invalide", "Invalid email", "بريد إلكتروني غير صالح")); return; }
    setBusy(true);
    try {
      if (mode === "forgot") {
        const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/reinitialiser` });
        if (error) throw error;
        toast.success(t("Un lien de réinitialisation vous a été envoyé.", "A reset link has been sent to you.", "تم إرسال رابط إعادة التعيين إليك."));
        setMode("in");
      } else if (mode === "up") {
        if (password.length < 8) throw new Error(t("Mot de passe : 8 caractères minimum", "Password: 8 characters minimum", "كلمة المرور: 8 أحرف على الأقل"));
        const { data, error } = await supabase.auth.signUp({ email, password, options: { emailRedirectTo: window.location.origin + (redirect ?? "/compte") } });
        if (error) throw error;
        if (data.session) await afterLogin();
        else toast.success(t("Compte créé : confirmez votre adresse via l’e-mail reçu.", "Account created: confirm your address via the email you received.", "تم إنشاء الحساب: أكّد عنوانك عبر البريد المرسل إليك."));
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw new Error(t("Identifiants incorrects", "Incorrect credentials", "بيانات الدخول غير صحيحة"));
        await afterLogin();
      }
    } catch (err) {
      toast.error((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function google() {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: {
        redirectTo: window.location.origin + "/auth" + (redirect ? `?redirect=${encodeURIComponent(redirect)}` : ""),
      },
    });
    if (error) toast.error(t("Connexion Google impossible", "Google sign-in failed", "تعذّر الدخول عبر Google"));
  }

  return (
    <div className="auth-panel">
      <img className="logo-full" src={logoFull} alt="Far7tek — فرحتك تهمّنا" width={480} height={437} />
      <h1 className="mt-2">{mode === "up" ? t("Créer un compte", "Create an account", "إنشاء حساب") : mode === "forgot" ? t("Mot de passe oublié", "Forgot password", "نسيت كلمة المرور") : t("Connexion", "Sign in", "تسجيل الدخول")}</h1>
      <p>{mode === "up"
        ? t("Créez votre compte pour réserver et suivre vos demandes.", "Create your account to book and track your requests.", "أنشئ حسابك للحجز ومتابعة طلباتك.")
        : t("Clients, partenaires et administration. Partenaires : utilisez l’e-mail de votre dossier accepté.", "Clients, partners and admin. Partners: use the email from your accepted application.", "للعملاء والشركاء والإدارة. الشركاء: استعملوا البريد الإلكتروني لملفكم المقبول.")}</p>
      <form className="ref-form" onSubmit={submit}>
        <label className="form-field"><span>{t("E-mail", "Email", "البريد الإلكتروني")}</span><input name="email" type="email" autoComplete="email" required dir="ltr" /></label>
        {mode !== "forgot" && (
          <label className="form-field"><span>{t("Mot de passe", "Password", "كلمة المرور")}</span><input name="password" type="password" autoComplete={mode === "up" ? "new-password" : "current-password"} required dir="ltr" /></label>
        )}
        <Button type="submit" className="ref-btn" disabled={busy || !hydrated}>
          {busy ? t("Patientez…", "Please wait…", "يرجى الانتظار…") : mode === "up" ? t("Créer mon compte", "Create my account", "إنشاء حسابي") : mode === "forgot" ? t("Envoyer le lien", "Send the link", "إرسال الرابط") : t("Se connecter", "Sign in", "دخول")}
        </Button>
      </form>
      <div className="auth-extra">
        {mode !== "forgot" && <Button variant="outline" className="ref-btn" onClick={google}>{t("Continuer avec Google", "Continue with Google", "المتابعة عبر Google")}</Button>}
        <Button variant="link" onClick={() => setMode(mode === "up" ? "in" : "up")}>{mode === "up" ? t("J’ai déjà un compte", "I already have an account", "لدي حساب بالفعل") : t("Créer un compte client", "Create a client account", "إنشاء حساب عميل")}</Button>
        {mode === "in" && <Button variant="link" onClick={() => setMode("forgot")}>{t("Mot de passe oublié ?", "Forgot password?", "نسيت كلمة المرور؟")}</Button>}
        {mode === "forgot" && <Button variant="link" onClick={() => setMode("in")}>{t("Retour à la connexion", "Back to sign in", "العودة إلى الدخول")}</Button>}
      </div>
    </div>
  );
}
