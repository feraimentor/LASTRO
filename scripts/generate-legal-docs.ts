import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import {
  AlignmentType,
  BorderStyle,
  Document,
  Footer,
  Header,
  HeadingLevel,
  LevelFormat,
  Packer,
  PageNumber,
  Paragraph,
  TextRun,
} from "docx";

export const LEGAL_DOCUMENTS = [
  {
    key: "notifications_communication",
    title: "Política de Notificações e Comunicação",
    slug: "notificacoes-comunicacao",
  },
  {
    key: "responsible_use_moderation",
    title: "Política de Uso Responsável, Moderação e Proteção contra Abusos",
    slug: "uso-responsavel-moderacao",
  },
  {
    key: "privacy_terms",
    title: "Política de Privacidade, LGPD e Termos de Uso",
    slug: "privacidade-termos",
  },
] as const;

export function canonicalizeLegalMarkdown(source: string) {
  return `${source.normalize("NFC").replace(/\r\n?/g, "\n").trimEnd()}\n`;
}

export function sha256(source: string) {
  return createHash("sha256").update(source, "utf8").digest("hex");
}

function markdownToParagraphs(markdown: string) {
  const paragraphs: Paragraph[] = [];
  let paragraphLines: string[] = [];

  const flush = () => {
    const text = paragraphLines.join(" ").trim();
    if (text) paragraphs.push(new Paragraph({ text, spacing: { after: 120, line: 264 } }));
    paragraphLines = [];
  };

  for (const rawLine of markdown.split("\n")) {
    const line = rawLine.trim();
    if (!line) {
      flush();
      continue;
    }
    const heading = /^(#{1,4})\s+(.+)$/.exec(line);
    if (heading) {
      flush();
      const level = heading[1].length;
      if (level === 1) {
        paragraphs.push(new Paragraph({
          children: [new TextRun({ text: heading[2], bold: true, size: 46, color: "2E302C" })],
          spacing: { before: 0, after: 80 },
          border: { bottom: { color: "6B4936", size: 8, style: BorderStyle.SINGLE, space: 8 } },
        }));
      } else {
        paragraphs.push(new Paragraph({
          text: heading[2],
          heading: level === 2 ? HeadingLevel.HEADING_1 : level === 3 ? HeadingLevel.HEADING_2 : HeadingLevel.HEADING_3,
        }));
      }
      continue;
    }
    if (line.startsWith("- ")) {
      flush();
      paragraphs.push(new Paragraph({ text: line.slice(2), numbering: { reference: "legal-bullets", level: 0 } }));
      continue;
    }
    paragraphLines.push(line.replace(/^\*|\*$/g, ""));
  }
  flush();
  return paragraphs;
}

function makeDoc(markdown: string, title: string) {
  return new Document({
    creator: "LASTRO",
    title,
    description: "Documento jurídico canônico do LASTRO",
    styles: {
      default: { document: { run: { font: "Calibri", size: 22, color: "2E302C" }, paragraph: { spacing: { after: 120, line: 264 } } } },
      paragraphStyles: [
        { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { bold: true, size: 32, color: "3E6652" }, paragraph: { spacing: { before: 320, after: 160 }, keepNext: true } },
        { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { bold: true, size: 26, color: "3E6652" }, paragraph: { spacing: { before: 240, after: 120 }, keepNext: true } },
        { id: "Heading3", name: "Heading 3", basedOn: "Normal", next: "Normal", quickFormat: true,
          run: { bold: true, size: 24, color: "6B4936" }, paragraph: { spacing: { before: 160, after: 80 }, keepNext: true } },
      ],
    },
    numbering: {
      config: [{
        reference: "legal-bullets",
        levels: [{
          level: 0,
          format: LevelFormat.BULLET,
          text: "•",
          alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 }, spacing: { after: 160, line: 280 } } },
        }],
      }],
    },
    sections: [{
      properties: {
        page: {
          size: { width: 12240, height: 15840 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440, header: 708, footer: 708 },
        },
      },
      headers: { default: new Header({ children: [new Paragraph({
        children: [new TextRun({ text: "LASTRO", bold: true, color: "6B4936" }), new TextRun({ text: "  |  Documento jurídico V1.0", color: "666666" })],
        spacing: { after: 80 },
      })] }) },
      footers: { default: new Footer({ children: [new Paragraph({
        alignment: AlignmentType.RIGHT,
        children: [new TextRun({ text: "Página ", color: "666666" }), new TextRun({ children: [PageNumber.CURRENT], color: "666666" })],
      })] }) },
      children: markdownToParagraphs(markdown),
    }],
  });
}

function sqlLiteral(value: string) {
  return `$lastro_legal$${value}$lastro_legal$`;
}

export async function generateLegalArtifacts() {
  const publicDir = path.join(process.cwd(), "public", "legal");
  const seedDir = path.join(process.cwd(), "supabase", "seeds");
  await mkdir(publicDir, { recursive: true });
  await mkdir(seedDir, { recursive: true });
  const seed: string[] = ["-- Generated deterministically by scripts/generate-legal-docs.ts.\n"];

  for (const legal of LEGAL_DOCUMENTS) {
    const sourcePath = path.join(process.cwd(), "legal", legal.key, "1.0.md");
    const markdown = canonicalizeLegalMarkdown(await readFile(sourcePath, "utf8"));
    const hash = sha256(markdown);
    const outputName = `${legal.slug}-v1.0.docx`;
    const buffer = await Packer.toBuffer(makeDoc(markdown, legal.title));
    await writeFile(path.join(publicDir, outputName), buffer);

    seed.push(`insert into public.legal_documents(key, title, public_slug) values (${sqlLiteral(legal.key)}, ${sqlLiteral(legal.title)}, ${sqlLiteral(legal.slug)}) on conflict (key) do update set title = excluded.title, public_slug = excluded.public_slug;`);
    seed.push(`insert into public.legal_document_versions(document_id, version, state, published_at, effective_at, content_markdown, content_hash_sha256, requires_reacceptance, is_current, download_path) select id, '1.0', 'published', '2026-08-09T12:00:00-03:00'::timestamptz, '2026-08-09T12:00:00-03:00'::timestamptz, ${sqlLiteral(markdown)}, '${hash}', true, true, '/legal/${outputName}' from public.legal_documents where key = ${sqlLiteral(legal.key)} on conflict (document_id, version) do nothing;`);
  }
  await writeFile(path.join(seedDir, "legal.sql"), `${seed.join("\n\n")}\n`, "utf8");
}

if (require.main === module) {
  generateLegalArtifacts().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}
