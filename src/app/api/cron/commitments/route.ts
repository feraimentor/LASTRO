import { NextRequest, NextResponse } from "next/server";
import { correlationId, logEvent } from "@/lib/observability";
import { createAdminClient } from "@/lib/supabase/admin";

export async function POST(request:NextRequest){
  const requestId=correlationId(request);const startedAt=new Date().toISOString();const route="/api/cron/commitments";
  const respond=(body:Record<string,unknown>,status=200)=>NextResponse.json(body,{status,headers:{"x-request-id":requestId}});
  const expected=process.env.CRON_SECRET;
  if(!expected||request.headers.get("authorization")!==`Bearer ${expected}`){logEvent("warn",{correlationId:requestId,route,operation:"authorize",errorCode:"unauthorized"});return respond({error:"unauthorized"},401)}
  const supabase=createAdminClient();if(!supabase)return respond({error:"server_configuration_missing"},503);
  const{data,error}=await supabase.rpc("mark_overdue_commitments");
  if(error){logEvent("error",{correlationId:requestId,route,operation:"mark_overdue",errorCode:"commitment_update_failed"});await Promise.all([supabase.rpc("record_job_result",{p_job_name:"commitment_deadlines",p_status:"failed",p_attempted:0,p_succeeded:0,p_error_code:"commitment_update_failed",p_correlation_id:requestId,p_started_at:startedAt}),supabase.rpc("record_operational_failure",{p_correlation_id:requestId,p_route:route,p_operation:"mark_overdue",p_error_code:"commitment_update_failed",p_safe_metadata:{}})]);return respond({error:"update_failed"},500)}
  const updated=Number(data??0);await supabase.rpc("record_job_result",{p_job_name:"commitment_deadlines",p_status:"succeeded",p_attempted:updated,p_succeeded:updated,p_error_code:null,p_correlation_id:requestId,p_started_at:startedAt});logEvent("info",{correlationId:requestId,route,operation:"mark_overdue",metadata:{updated}});return respond({updated});
}

// Cloudflare invokes POST through the custom scheduled handler. Keep GET
// available for authenticated operational replays from a trusted runner.
export const GET = POST;
