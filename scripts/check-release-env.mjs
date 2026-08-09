const required=["NEXT_PUBLIC_APP_URL","NEXT_PUBLIC_SUPABASE_URL","NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY","SUPABASE_SECRET_KEY","MASTER_BOOTSTRAP_EMAIL","RESEND_API_KEY","EMAIL_FROM","CRON_SECRET"];
const missing=required.filter(name=>!process.env[name]);const problems=[];
if(missing.length)problems.push(`ausentes: ${missing.join(", ")}`);
if(process.env.NEXT_PUBLIC_APP_URL&&!process.env.NEXT_PUBLIC_APP_URL.startsWith("https://"))problems.push("NEXT_PUBLIC_APP_URL deve usar HTTPS");
if(process.env.NEXT_PUBLIC_SUPABASE_URL&&!process.env.NEXT_PUBLIC_SUPABASE_URL.startsWith("https://"))problems.push("NEXT_PUBLIC_SUPABASE_URL deve usar HTTPS em produção");
if(process.env.EMAIL_PROVIDER!=="resend")problems.push("EMAIL_PROVIDER deve ser resend em produção");
if((process.env.CRON_SECRET?.length??0)<32)problems.push("CRON_SECRET deve ter ao menos 32 caracteres");
if(problems.length){console.error(`Release env inválido — ${problems.join("; ")}`);process.exit(1)}
console.log("Release env contém as chaves obrigatórias e restrições básicas; valide os serviços externamente.");
