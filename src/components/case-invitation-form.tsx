"use client";

import { useState } from "react";

export function CaseInvitationForm({ reportId }: { reportId:string }){
  const[url,setUrl]=useState<string>();const[error,setError]=useState<string>();const[pending,setPending]=useState(false);
  async function submit(formData:FormData){setPending(true);setError(undefined);const response=await fetch("/api/invitations/case",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({reportId,email:String(formData.get("email")??"")})});const body=await response.json() as {invitationUrl?:string;error?:string};if(!response.ok||!body.invitationUrl)setError("Não foi possível criar o convite.");else setUrl(body.invitationUrl);setPending(false)}
  return <form action={submit} className="grid gap-3 rounded-xl border bg-white p-5"><h2 className="text-lg font-bold">Convidar parte citada para este caso</h2><p className="text-sm text-[#666861]">O convite é vinculado ao e-mail Google, expira em 7 dias e só pode ser usado uma vez.</p><input className="min-h-11 rounded-lg border px-3" type="email" name="email" required placeholder="E-mail Google da parte"/><button disabled={pending} className="min-h-11 rounded-lg bg-forest px-4 font-bold text-white">{pending?"Criando…":"Criar convite de caso"}</button>{url&&<div role="status" className="rounded-lg bg-forest-soft p-3"><p className="text-sm font-semibold">Copie agora; o token não será exibido novamente:</p><input readOnly value={url} className="mt-2 w-full rounded border bg-white p-2 text-xs"/></div>}{error&&<p role="alert" className="text-danger">{error}</p>}</form>
}
