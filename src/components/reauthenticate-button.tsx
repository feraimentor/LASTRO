"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export function ReauthenticateButton({ nextPath }: { nextPath: string }) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string>();

  async function reauthenticate() {
    setPending(true);
    setError(undefined);
    const redirectTo = `${window.location.origin}/auth/callback?next=${encodeURIComponent(nextPath)}`;
    const { error: authError } = await createClient().auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo, queryParams: { prompt: "select_account" } },
    });
    if (authError) {
      setError("Não foi possível confirmar sua conta Google.");
      setPending(false);
    }
  }

  return <div>
    <button type="button" onClick={reauthenticate} disabled={pending} className="rounded-lg border border-forest px-4 py-2 font-semibold text-forest disabled:opacity-60">
      {pending ? "Abrindo Google…" : "Confirmar conta Google novamente"}
    </button>
    {error && <p role="alert" className="mt-2 text-sm text-danger">{error}</p>}
  </div>;
}
