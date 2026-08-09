"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export function GoogleSignIn({ nextPath = "/onboarding/legal" }: { nextPath?: string }) {
  const [error, setError] = useState<string>();
  const [pending, setPending] = useState(false);
  async function signIn() {
    setPending(true); setError(undefined);
    try {
      const safeNext = nextPath.startsWith("/") && !nextPath.startsWith("//") ? nextPath : "/onboarding/legal";
      const redirectTo = `${window.location.origin}/auth/callback?next=${encodeURIComponent(safeNext)}`;
      const { error: authError } = await createClient().auth.signInWithOAuth({ provider: "google", options: { redirectTo } });
      if (authError) throw authError;
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Não foi possível iniciar o acesso.");
      setPending(false);
    }
  }
  return <div>
    <button type="button" disabled={pending} onClick={signIn} className="min-h-12 w-full rounded-lg bg-forest px-5 py-3 font-bold text-white disabled:opacity-60">
      {pending ? "Abrindo o Google…" : "Continuar com Google"}
    </button>
    {error && <p role="alert" className="mt-3 rounded-lg bg-[#fbeaea] p-3 text-sm text-danger">{error}</p>}
  </div>;
}
