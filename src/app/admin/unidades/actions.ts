"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requirePermission } from "@/lib/community";
import { createClient } from "@/lib/supabase/server";
export async function createUnitAction(formData:FormData){await requirePermission("units.manage");const d=z.object({block_id:z.coerce.number().int().min(1).max(14),unit_label:z.string().trim().min(1).max(30)}).parse(Object.fromEntries(formData));const s=await createClient();const{error}=await s.rpc("create_condo_unit",{p_block_id:d.block_id,p_unit_label:d.unit_label});if(error)throw new Error("Não foi possível criar a unidade.");revalidatePath("/admin/unidades")}
