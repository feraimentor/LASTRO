"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { createClient, getVerifiedUser } from "@/lib/supabase/server";

export async function recordPartyStatementAction(formData:FormData){const user=await getVerifiedUser();if(!user)throw new Error("authentication_required");const data=z.object({report_id:z.string().uuid(),case_grant_id:z.string().uuid(),occurred_at:z.string().min(1),body:z.string().trim().min(5).max(10000),action_informed:z.string().trim().max(1000).optional()}).parse(Object.fromEntries(formData));const supabase=await createClient();const{error}=await supabase.rpc("record_response",{p_report_id:data.report_id,p_response_type:"party_statement",p_attributed_to:null,p_channel:null,p_occurred_at:new Date(`${data.occurred_at}:00-03:00`).toISOString(),p_body:data.body,p_action_informed:data.action_informed||null,p_official_representation_id:null,p_case_grant_id:data.case_grant_id,p_commitment:null});if(error)throw new Error(error.message);revalidatePath(`/casos/${data.report_id}`)}
