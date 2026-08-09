import { z } from "zod";

export const historicalImportColumns=[
  "source_name","source_type","source_reference","occurred_at","source_actor_key","record_type","title",
  "raw_source_text","published_summary","category_slug","subcategory_slug","suggested_category_text",
  "suggested_subcategory_text","location_labels","scope","urgency","historical_outcome","known_response_text",
  "known_response_at","commitment_text","commitment_due_at","provenance_notes",
] as const;

const optionalText=(max:number)=>z.preprocess(value=>value===""||value==null?undefined:value,z.string().trim().max(max).optional());
const optionalDate=z.preprocess(value=>value===""||value==null?undefined:value,z.coerce.date().optional());

export const historicalImportRowSchema=z.object({
  source_name:z.string().trim().min(2).max(200),source_type:z.enum(["minutes","email","letter","notice","manual_note","other"]),
  source_reference:optionalText(300),occurred_at:z.coerce.date(),source_actor_key:optionalText(160),
  record_type:z.enum(["complaint","maintenance_request","possible_irregularity","information_request","suggestion","safety_risk"]),
  title:z.string().trim().min(8).max(180),raw_source_text:optionalText(10000),published_summary:z.string().trim().min(20).max(2000),
  category_slug:z.string().trim().min(1).max(120),subcategory_slug:optionalText(120),suggested_category_text:optionalText(120),suggested_subcategory_text:optionalText(120),
  location_labels:optionalText(1000),scope:z.enum(["unit","multiple_units","block","multiple_blocks","common_area","whole_condo","unknown"]),
  urgency:z.enum(["routine","attention","urgent","possible_immediate_risk"]),
  historical_outcome:z.enum(["resolved","partially_resolved","unresolved","promise_only","no_longer_applicable","outcome_unknown"]),
  known_response_text:optionalText(2000),known_response_at:optionalDate,commitment_text:optionalText(2000),commitment_due_at:optionalDate,
  provenance_notes:z.string().trim().min(2).max(2000),
}).strict();

export type HistoricalImportRow=z.infer<typeof historicalImportRowSchema>;
export function serializeHistoricalRow(row:HistoricalImportRow){return{...row,occurred_at:row.occurred_at.toISOString(),known_response_at:row.known_response_at?.toISOString(),commitment_due_at:row.commitment_due_at?.toISOString()}}
export function validateHistoricalRows(rows:unknown[]){return rows.map((row,index)=>{const result=historicalImportRowSchema.safeParse(row);return result.success?{index,valid:true as const,data:result.data}:{index,valid:false as const,errors:result.error.issues.map(issue=>`${issue.path.join(".")}: ${issue.message}`)}})}
