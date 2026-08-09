import{createClient}from"@supabase/supabase-js";
const url=process.env.NEXT_PUBLIC_SUPABASE_URL;const key=process.env.SUPABASE_SECRET_KEY;
if(!url||!key)throw new Error("NEXT_PUBLIC_SUPABASE_URL e SUPABASE_SECRET_KEY são obrigatórios.");
const client=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});const{data:buckets,error}=await client.storage.listBuckets();if(error)throw error;const inventory=[];
for(const bucket of buckets??[]){for(let offset=0;;offset+=1000){const{data,error:listError}=await client.storage.from(bucket.id).list("",{limit:1000,offset,sortBy:{column:"name",order:"asc"}});if(listError)throw listError;for(const item of data??[])inventory.push({bucket:bucket.id,name:item.name,size:item.metadata?.size??null,updated_at:item.updated_at??null});if((data?.length??0)<1000)break;}}
process.stdout.write(`${JSON.stringify({generated_at:new Date().toISOString(),project_url:url,buckets:(buckets??[]).map(({id,name,public:publicAccess})=>({id,name,public:publicAccess})),objects:inventory},null,2)}\n`);
