import { randomUUID } from "node:crypto";

const forbiddenKeys=new Set(["authorization","token","secret","password","raw_source_text","content","document","email","phone","whatsapp"]);
type SafeValue=string|number|boolean|null;
export type SafeMetadata=Record<string,SafeValue>;

export function sanitizeLogMetadata(input:Record<string,unknown>={}){
  return Object.fromEntries(Object.entries(input).flatMap(([key,value])=>{
    if(forbiddenKeys.has(key.toLowerCase())||!["string","number","boolean"].includes(typeof value)&&value!==null)return[];
    return[[key,typeof value==="string"?value.slice(0,200):value as SafeValue]];
  })) as SafeMetadata;
}

export function correlationId(request?:Request){
  const candidate=request?.headers.get("x-request-id");
  return candidate&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(candidate)?candidate:randomUUID();
}

export function logEvent(level:"info"|"warn"|"error",event:{correlationId:string;route:string;operation:string;errorCode?:string;userId?:string|null;metadata?:Record<string,unknown>}){
  const record={level,service:"lastro",timestamp:new Date().toISOString(),correlation_id:event.correlationId,route:event.route.slice(0,200),operation:event.operation.slice(0,120),error_code:event.errorCode?.slice(0,120),user_id:event.userId??undefined,metadata:sanitizeLogMetadata(event.metadata)};
  const serialized=JSON.stringify(record);
  if(level==="error")console.error(serialized);else if(level==="warn")console.warn(serialized);else console.info(serialized);
  return record;
}
