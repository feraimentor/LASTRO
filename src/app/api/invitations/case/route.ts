import { createHash, randomBytes } from "node:crypto";
import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient, getVerifiedUser } from "@/lib/supabase/server";

export async function POST(request: Request) {
  const user = await getVerifiedUser();
  if (!user) return NextResponse.json({ error: "authentication_required" }, { status: 401 });
  const parsed = z.object({ reportId:z.string().uuid(),email:z.string().trim().email().max(254) }).safeParse(await request.json());
  if (!parsed.success) return NextResponse.json({ error:"invalid_request" },{status:400});
  const token=randomBytes(32).toString("base64url");
  const hash=(value:string)=>createHash("sha256").update(value,"utf8").digest("hex");
  const supabase=await createClient();
  const {error}=await supabase.rpc("create_access_invitation",{
    p_email_hash:hash(parsed.data.email.toLowerCase()),p_token_hash:hash(token),p_invitation_type:"case_participant",
    p_report_id:parsed.data.reportId,p_expires_at:new Date(Date.now()+7*24*60*60*1000).toISOString(),p_metadata:{},
  });
  if(error)return NextResponse.json({error:error.message},{status:403});
  return NextResponse.json({ invitationUrl:`${new URL(request.url).origin}/convite?token=${encodeURIComponent(token)}` });
}
