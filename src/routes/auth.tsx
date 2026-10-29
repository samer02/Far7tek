import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";
import { lovable } from "@/integrations/lovable";

export const Route = createFileRoute("/auth")({
  validateSearch: (s: Record<string, unknown>) => ({
    redirect: typeof s.redirect === "string" && s.redirect.startsWith("/") && !s.redirect.startsWith("//") ? s.redirect : undefined,
  }),
  head: () => ({
    meta: [
      { title: "Connexion — Cortège & Cérémonie" },
      { name: "description", content: "Connectez-vous pour suivre vos demandes ou accéder à votre espace partenaire." },
      { property: "og:title", content: "Connexion — Cortège & Cérémonie" },
      { property: "og:description", content: "Espace client, partenaire et administration." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: AuthPage,
});

function AuthPage() {
  const { redirect } = Route.useSearch();
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [mode, setMode] = useState<"in" | "up" | "forgot">("in");
  const [busy, setBusy] = useState(false);

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
    if (!/^\S+@\S+\.\S+$/.test(email)) return toast.error("E-mail invalide");
    setBusy(true);
    try {
      if (mode === "forgot") {
        const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/reinitialiser` });
        if (error) throw error;
        toast.success("Un lien de réinitialisation vous a été envoyé.");
        setMode("in");
      } else if (mode === "up") {
        if (password.length < 8) throw new Error("Mot de passe : 8 caractères minimum");
        const { data, error } = await supabase.auth.signUp({ email, password, options: { emailRedirectTo: window.location.origin + (redirect ?? "/compte") } });
        if (error) throw error;
        if (data.session) await afterLogin();
        else toast.success("Compte créé : confirmez votre adresse via l’e-mail reçu.");
      } else {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw new Error("Identifiants incorrects");
        await afterLogin();
      }
    } catch (err) {
      toast.error((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function google() {
    const r = await lovable.auth.signInWithOAuth("google", { redirect_uri: window.location.origin + "/auth" + (redirect ? `?redirect=${encodeURIComponent(redirect)}` : "") });
    if (r.error) toast.error("Connexion Google impossible");
    else if (!r.redirected) await afterLogin();
  }

  return (
    <div className="auth-panel">
      <span className="eyebrow">Espace client · Partenaire · Administration</span>
      <h1>{mode === "up" ? "Créer un compte" : mode === "forgot" ? "Mot de passe oublié" : "Connexion"}</h1>
      <p>{mode === "up" ? "Créez votre compte pour réserver et suivre vos demandes." : "Partenaires : utilisez l’e-mail de votre dossier accepté."}</p>
      <form className="ref-form" onSubmit={submit}>
        <label className="form-field"><span>E-mail</span><input name="email" type="email" autoComplete="email" required /></label>
        {mode !== "forgot" && (
          <label className="form-field"><span>Mot de passe</span><input name="password" type="password" autoComplete={mode === "up" ? "new-password" : "current-password"} required /></label>
        )}
        <Button type="submit" className="ref-btn" disabled={busy}>{busy ? "Patientez…" : mode === "up" ? "Créer mon compte" : mode === "forgot" ? "Envoyer le lien" : "Se connecter"}</Button>
      </form>
      <div className="auth-extra">
        {mode !== "forgot" && <Button variant="outline" className="ref-btn" onClick={google}>Continuer avec Google</Button>}
        <Button variant="link" onClick={() => setMode(mode === "up" ? "in" : "up")}>{mode === "up" ? "J’ai déjà un compte" : "Créer un compte client"}</Button>
        {mode === "in" && <Button variant="link" onClick={() => setMode("forgot")}>Mot de passe oublié ?</Button>}
      </div>
    </div>
  );
}
