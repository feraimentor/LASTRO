"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient, getVerifiedUser } from "@/lib/supabase/server";

export async function consumeInvitationAction(formData:FormData){const user=await getVerifiedUser();if(!user)redirect("/login");const token=z.string().min(20).max(500).parse(formData.get("token"));const supabase=await createClient();const{data,error}=await supabase.rpc("consume_access_invitation",{p_token:token});if(error)throw new Error("Convite inválido, expirado, já utilizado ou destinado a outra conta Google.");const result=(data as Array<{invitation_type:string;report_id:string|null}>|null)?.[0];if(result?.invitation_type==="case_participant"&&result.report_id)redirect(`/casos/${result.report_id}`);redirect("/dashboard")}
