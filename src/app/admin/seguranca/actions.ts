"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";

const incidentSchema=z.object({
  incident_id:z.preprocess(value=>value===""?null:value,z.string().uuid().nullable()),
  severity:z.enum(["low","medium","high","critical"]),status:z.enum(["detected","contained","investigating","remediating","recovered","closed"]),
  summary:z.string().trim().min(10).max(1000),systems:z.string().trim().max(1000),data_categories:z.string().trim().max(1000),
  containment:z.string().trim().max(5000).optional(),remediation:z.string().trim().max(5000).optional(),decision_notes:z.string().trim().max(5000).optional(),
  notifications_required:z.enum(["","true","false"]),notification_decision:z.string().trim().max(2000).optional(),occurred_at:z.string().optional(),
});
const list=(value:string)=>value.split(",").map(item=>item.trim()).filter(Boolean).slice(0,30);
const localDateTime=z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/);
function saoPauloIso(value:string){
  const[date,time]=value.split("T");const[year,month,day]=date.split("-").map(Number);const[hour,minute]=time.split(":").map(Number);const guess=Date.UTC(year,month-1,day,hour,minute);
  const parts=Object.fromEntries(new Intl.DateTimeFormat("en-US",{timeZone:"America/Sao_Paulo",year:"numeric",month:"2-digit",day:"2-digit",hour:"2-digit",minute:"2-digit",hourCycle:"h23"}).formatToParts(new Date(guess)).filter(part=>part.type!=="literal").map(part=>[part.type,Number(part.value)]));
  const offset=Date.UTC(parts.year,parts.month-1,parts.day,parts.hour,parts.minute)-guess;return new Date(guess-offset).toISOString();
}

export async function manageIncidentAction(formData:FormData){
  await requirePermission("settings.manage");
  const data=incidentSchema.parse(Object.fromEntries(formData));
  const payload={...data,incident_id:undefined,occurred_at:data.occurred_at?saoPauloIso(localDateTime.parse(data.occurred_at)):"",systems:list(data.systems),data_categories:list(data.data_categories),detected_at:new Date().toISOString(),notifications_required:data.notifications_required===""?null:data.notifications_required==="true"};
  const supabase=await createClient();const{error}=await supabase.rpc("manage_security_incident",{p_incident_id:data.incident_id,p_payload:payload});
  if(error)throw new Error(error.message);revalidatePath("/admin/seguranca");
}

export async function recordRestoreDrillAction(formData:FormData){
  await requirePermission("settings.manage");
  const data=z.object({environment:z.enum(["development","staging","preview"]),backup_started_at:localDateTime,restored_at:localDateTime,evidence_reference:z.string().trim().min(5).max(500),rpo_minutes:z.coerce.number().int().min(0),rto_minutes:z.coerce.number().int().min(0),notes:z.string().trim().max(2000).optional()}).parse(Object.fromEntries(formData));
  const flags=["database_verified","storage_inventory_verified","legal_hashes_verified","rls_verified"] as const;
  const payload={...data,backup_started_at:saoPauloIso(data.backup_started_at),restored_at:saoPauloIso(data.restored_at),...Object.fromEntries(flags.map(flag=>[flag,formData.get(flag)==="on"]))};
  const supabase=await createClient();const{error}=await supabase.rpc("record_restore_drill",{p_payload:payload});
  if(error)throw new Error(error.message);revalidatePath("/admin/seguranca");
}
