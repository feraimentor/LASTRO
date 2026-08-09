import type { ReactNode } from "react";

function linkify(text: string): ReactNode[] {
  const parts = text.split(/(https?:\/\/\S+)/g);
  return parts.map((part, index) => part.startsWith("http")
    ? <a key={`${part}-${index}`} href={part} rel="noreferrer" target="_blank">{part}</a>
    : part);
}
export function LegalMarkdown({ markdown }: { markdown: string }) {
  const nodes: ReactNode[] = [];
  const lines = markdown.split("\n");
  let paragraph: string[] = [];
  let bullets: string[] = [];

  const flushParagraph = () => {
    if (paragraph.length) nodes.push(<p key={`p-${nodes.length}`}>{linkify(paragraph.join(" "))}</p>);
    paragraph = [];
  };
  const flushBullets = () => {
    if (bullets.length) nodes.push(<ul key={`ul-${nodes.length}`}>{bullets.map((item, index) => <li key={`${item}-${index}`}>{linkify(item)}</li>)}</ul>);
    bullets = [];
  };

  for (const raw of lines) {
    const line = raw.trim();
    if (!line) { flushParagraph(); flushBullets(); continue; }
    const match = /^(#{1,4})\s+(.+)$/.exec(line);
    if (match) {
      flushParagraph(); flushBullets();
      const content = match[2];
      const key = `h-${nodes.length}`;
      nodes.push(match[1].length === 1 ? <h1 key={key}>{content}</h1> : match[1].length === 2 ? <h2 key={key}>{content}</h2> : match[1].length === 3 ? <h3 key={key}>{content}</h3> : <h4 key={key}>{content}</h4>);
    } else if (line.startsWith("- ")) {
      flushParagraph(); bullets.push(line.slice(2));
    } else {
      flushBullets(); paragraph.push(line.replace(/^\*|\*$/g, ""));
    }
  }
  flushParagraph(); flushBullets();
  return <div className="prose-lastro">{nodes}</div>;
}
