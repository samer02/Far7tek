import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/reinitialiser")({
  head: () => ({
    meta: [
      { title: "Choisir mon mot de passe — Cortège & Cérémonie" },
      { name: "description", content: "Définissez votre mot de passe pour accéder à votre espace." },
      { property: "og:title", content: "Choisir mon mot de passe" },
      { property: "og:description", content: "Activation sécurisée de votre compte." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
  component: ResetPage,
});

function ResetPage() {
  const [busy, setBusy] = useState(false);
  const navigate = useNavigate();
  const qc = useQueryClient();
  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const p = String(f.get("password")), c = String(f.get("confirm"));
    if (p.length < 8) return toast.error("8 caractères minimum");
    if (p !== c) return toast.error("Les mots de passe ne correspondent pas");
    setBusy(true);
    const { error } = await supabase.auth.updateUser({ password: p });
    setBusy(false);
    if (error) return toast.error("Lien expiré ou invalide. Demandez un nouveau lien depuis la page de connexion.");
    toast.success("Mot de passe enregistré");
    await qc.invalidateQueries({ queryKey: ["auth"] });
    navigate({ to: "/auth" });
  }
  return (
    <div className="auth-panel">
      <span className="eyebrow">Sécurité du compte</span>
      <h1>Choisir mon mot de passe</h1>
      <p>Ce mot de passe vous permettra d’accéder à votre espace.</p>
      <form className="ref-form" onSubmit={submit}>
        <label className="form-field"><span>Nouveau mot de passe</span><input name="password" type="password" autoComplete="new-password" required /></label>
        <label className="form-field"><span>Confirmation</span><input name="confirm" type="password" autoComplete="new-password" required /></label>
        <Button type="submit" className="ref-btn" disabled={busy}>{busy ? "Enregistrement…" : "Enregistrer"}</Button>
      </form>
    </div>
  );
}
