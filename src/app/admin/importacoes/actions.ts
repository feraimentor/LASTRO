"use server";

import ExcelJS from "exceljs";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requirePermission } from "@/lib/community";
import {
  historicalImportColumns,
  serializeHistoricalRow,
  validateHistoricalRows,
} from "@/lib/import-schema";
import { createClient } from "@/lib/supabase/server";

const MAX_FILE_BYTES=5*1024*1024;
const batchSchema=z.object({source_name:z.string().trim().min(2).max(200)});

function parseCsv(text:string){
  const rows:string[][]=[];let row:string[]=[];let field="";let quoted=false;
  const input=text.replace(/^\uFEFF/,"");
  for(let i=0;i<input.length;i++){
    const char=input[i];
    if(quoted){
      if(char==='"'&&input[i+1]==='"'){field+='"';i++;}
      else if(char==='"'){quoted=false;}
      else field+=char;
    }else if(char==='"'){quoted=true;}
    else if(char===","){row.push(field);field="";}
    else if(char==="\n"){row.push(field.replace(/\r$/, ""));rows.push(row);row=[];field="";}
    else field+=char;
  }
  if(quoted)throw new Error("CSV inválido: campo entre aspas não foi fechado.");
  if(field!==""||row.length){row.push(field.replace(/\r$/, ""));rows.push(row);}
  return rows.filter(values=>values.some(value=>value.trim()!==""));
}

function rowsToObjects(rows:string[][]){
  if(rows.length<2)throw new Error("O arquivo deve conter cabeçalho e ao menos uma linha de dados.");
  const headers=rows[0].map(value=>value.trim());
  if(headers.join("\u0000")!==historicalImportColumns.join("\u0000")){
    throw new Error(`Cabeçalho incompatível. Use exatamente: ${historicalImportColumns.join(", ")}`);
  }
  if(rows.length-1>1000)throw new Error("Cada lote aceita no máximo 1.000 registros.");
  return rows.slice(1).map((values,index)=>{
    if(values.length>historicalImportColumns.length)throw new Error(`Linha ${index+2}: existem colunas além do template.`);
    return Object.fromEntries(historicalImportColumns.map((column,columnIndex)=>[column,values[columnIndex]??""]));
  });
}

async function parseXlsx(file:File){
  const workbook=new ExcelJS.Workbook();
  const contents=Buffer.from(await file.arrayBuffer());
  await workbook.xlsx.load(contents as unknown as Parameters<typeof workbook.xlsx.load>[0]);
  const sheet=workbook.worksheets[0];
  if(!sheet)throw new Error("A planilha não contém abas.");
  const rows:string[][]=[];
  sheet.eachRow({includeEmpty:false},row=>{
    const values:string[]=[];
    for(let index=1;index<=historicalImportColumns.length+1;index++){
      const value=row.getCell(index).value;
      if(value instanceof Date)values.push(value.toISOString());
      else values.push(row.getCell(index).text.trim());
    }
    while(values.at(-1)==="")values.pop();
    rows.push(values);
  });
  return rowsToObjects(rows);
}

async function stage(sourceName:string,sourceType:"manual"|"csv"|"xlsx",rows:unknown[]){
  const results=validateHistoricalRows(rows);
  const items=results.map(result=>result.valid
    ?{payload:serializeHistoricalRow(result.data),errors:[]}
    :{payload:rows[result.index]??{},errors:result.errors});
  const supabase=await createClient();
  const{data:batchId,error:batchError}=await supabase.rpc("create_import_batch",{p_source_name:sourceName,p_source_type:sourceType});
  if(batchError||!batchId)throw new Error(batchError?.message??"Não foi possível criar o lote.");
  const{error:stageError}=await supabase.rpc("stage_import_items",{p_batch_id:batchId,p_items:items});
  if(stageError)throw new Error(stageError.message);
}

export async function uploadImportAction(formData:FormData){
  await requirePermission("historical_import.manage");
  const{source_name}=batchSchema.parse(Object.fromEntries(formData));
  const file=formData.get("file");
  if(!(file instanceof File)||file.size===0)throw new Error("Selecione um arquivo CSV ou XLSX.");
  if(file.size>MAX_FILE_BYTES)throw new Error("O arquivo excede o limite de 5 MB.");
  const extension=file.name.toLowerCase().split(".").at(-1);
  if(extension!=="csv"&&extension!=="xlsx")throw new Error("Formato não aceito. Envie CSV ou XLSX estruturado.");
  const rows=extension==="csv"?rowsToObjects(parseCsv(await file.text())):await parseXlsx(file);
  await stage(source_name,extension,rows);
  revalidatePath("/admin/importacoes");
}

export async function createManualImportAction(formData:FormData){
  await requirePermission("historical_import.manage");
  const{source_name}=batchSchema.parse(Object.fromEntries(formData));
  const raw=z.string().trim().min(2).max(50000).parse(formData.get("payload"));
  let payload:unknown;
  try{payload=JSON.parse(raw);}catch{throw new Error("O registro manual precisa ser um objeto JSON válido.");}
  if(Array.isArray(payload))throw new Error("A criação manual aceita um registro por vez.");
  await stage(source_name,"manual",[payload]);
  revalidatePath("/admin/importacoes");
}

export async function reviewImportItemAction(formData:FormData){
  await requirePermission("historical_import.manage");
  const data=z.object({
    item_id:z.string().uuid(),state:z.enum(["approved","ignored","needs_edit"]),
    reason:z.string().trim().min(5).max(1000),edited_payload:z.string().trim().max(50000).optional(),
  }).parse(Object.fromEntries(formData));
  const supabase=await createClient();
  let edited:Record<string,unknown>|null=null;
  if(data.edited_payload){
    try{edited=JSON.parse(data.edited_payload) as Record<string,unknown>;}catch{throw new Error("A correção precisa ser um objeto JSON válido.");}
    if(!edited||Array.isArray(edited)||typeof edited!=="object")throw new Error("A correção precisa ser um objeto JSON.");
  }
  if(data.state==="approved"&&edited){
    const{data:item,error}=await supabase.from("import_staging_items").select("payload,historical_source_id").eq("id",data.item_id).single();
    if(error||!item)throw new Error(error?.message??"Item não encontrado.");
    if(!item.historical_source_id){
      const candidate={...(item.payload as Record<string,unknown>),...edited};
      delete candidate._source_actor_hash;delete candidate._raw_source_text;
      const validation=validateHistoricalRows([candidate])[0];
      if(!validation.valid)throw new Error(`A correção ainda é inválida: ${validation.errors.join("; ")}`);
      edited=serializeHistoricalRow(validation.data);
    }
  }
  const{error}=await supabase.rpc("review_import_item",{
    p_item_id:data.item_id,p_state:data.state,p_edited_payload:edited,p_reason:data.reason,
  });
  if(error)throw new Error(error.message);
  revalidatePath("/admin/importacoes");
}

export async function publishImportItemAction(formData:FormData){
  await requirePermission("historical_import.manage");
  const data=z.object({item_id:z.string().uuid(),target_issue_id:z.preprocess(value=>value===""?null:value,z.string().uuid().nullable())}).parse(Object.fromEntries(formData));
  const supabase=await createClient();
  const{error}=await supabase.rpc("publish_import_item",{p_item_id:data.item_id,p_target_issue_id:data.target_issue_id});
  if(error)throw new Error(error.message);
  revalidatePath("/admin/importacoes");
}
