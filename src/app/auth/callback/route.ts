import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { bootstrapFounderMaster } from "@/lib/supabase/admin";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const requestedNext = url.searchParams.get("next") ?? "/onboarding/legal";
  const next = requestedNext.startsWith("/") && !requestedNext.startsWith("//") ? requestedNext : "/onboarding/legal";
  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      const { data } = await supabase.auth.getUser();
      if (data.user) await bootstrapFounderMaster(data.user);
      return NextResponse.redirect(new URL(next, url.origin));
    }
  }
  return NextResponse.redirect(new URL("/login?erro=oauth", url.origin));
}
