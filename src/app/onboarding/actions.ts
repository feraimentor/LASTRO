"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient, getVerifiedUser } from "@/lib/supabase/server";

export async function acceptCurrentLegalDocuments(formData: FormData) {
  const user = await getVerifiedUser();
  if (!user) redirect("/login");
  const confirmed = formData.getAll("accept").map(String);
  if (confirmed.length !== 3) throw new Error("Os três aceites são obrigatórios.");
  const supabase = await createClient();
  const { error } = await supabase.rpc("accept_current_legal_documents");
  if (error) throw new Error("Não foi possível registrar os aceites vigentes.");
  const requestedNext = String(formData.get("next") ?? "/onboarding/profile");
  const next = requestedNext.startsWith("/") && !requestedNext.startsWith("//") ? requestedNext : "/onboarding/profile";
  redirect(next);
}

const profileSchema = z.object({
  firstName: z.string().trim().min(2).max(80), lastName: z.string().trim().min(2).max(80),
  displayName: z.string().trim().min(2).max(100), identity: z.enum(["identified", "protected", "protected_with_block"]),
  relation: z.enum(["resident_owner", "nonresident_owner", "tenant", "authorized_resident", "owner_representative"]),
  currentlyResides: z.enum(["yes", "no"]),
  whatsapp: z.string().trim().max(30).optional(),
});

export async function saveProfile(formData: FormData) {
  const user = await getVerifiedUser(); if (!user) redirect("/login");
  const data = profileSchema.parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("save_profile", {
    p_first_name: data.firstName, p_last_name: data.lastName, p_display_name: data.displayName,
    p_identity: data.identity, p_relation: data.relation,
    p_currently_resides: data.currentlyResides === "yes", p_whatsapp: data.whatsapp || null,
  });
  if (error) throw new Error("Não foi possível salvar o perfil.");
  redirect("/onboarding/unit");
}

const unitSchema = z.object({
  blockId: z.coerce.number().int().min(1).max(14), unitId: z.string().uuid().optional().or(z.literal("")),
  requestedUnit: z.string().trim().max(30).optional(), currentlyResides: z.enum(["yes", "no"]),
}).refine((value) => Boolean(value.unitId || value.requestedUnit), { message: "Selecione ou informe a unidade." });

export async function requestVerification(formData: FormData) {
  const user = await getVerifiedUser(); if (!user) redirect("/login");
  const data = unitSchema.parse(Object.fromEntries(formData));
  const supabase = await createClient();
  const { error } = await supabase.rpc("submit_verification_request", {
    p_block_id: data.blockId, p_unit_id: data.unitId || null,
    p_requested_unit: data.unitId ? null : data.requestedUnit,
    p_currently_resides: data.currentlyResides === "yes",
  });
  if (error) throw new Error("Não foi possível enviar a solicitação.");
  redirect("/onboarding/pending");
}
