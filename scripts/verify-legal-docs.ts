import { access, readFile } from "node:fs/promises";
import path from "node:path";
import { canonicalizeLegalMarkdown, LEGAL_DOCUMENTS, sha256 } from "./generate-legal-docs";

async function verify() {
  for (const legal of LEGAL_DOCUMENTS) {
    const markdown = canonicalizeLegalMarkdown(await readFile(path.join("legal", legal.key, "1.0.md"), "utf8"));
    const hash = sha256(markdown);
    const seed = await readFile(path.join("supabase", "seeds", "legal.sql"), "utf8");
    if (!seed.includes(hash)) throw new Error(`Hash ausente no seed: ${legal.key}`);
    await access(path.join("public", "legal", `${legal.slug}-v1.0.docx`));
  }
  console.log("Legal sources, hashes, seed and DOCX files are synchronized.");
}

verify().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
