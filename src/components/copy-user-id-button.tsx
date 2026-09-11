"use client";

import { useState } from "react";

export function CopyUserIdButton({ userId }: { userId: string }) {
  const [status, setStatus] = useState<"idle" | "copied" | "failed">("idle");

  async function copy() {
    try {
      await navigator.clipboard.writeText(userId);
      setStatus("copied");
    } catch {
      setStatus("failed");
    }
  }

  return (
    <div className="flex items-center gap-2">
      <button type="button" onClick={copy} className="min-h-10 rounded-lg border border-[#aaa59e] bg-white px-3 text-sm font-bold text-forest">
        Copiar UUID
      </button>
      <span className="text-xs text-[#62645e]" role="status" aria-live="polite">
        {status === "copied" ? "Copiado" : status === "failed" ? "Não foi possível copiar" : ""}
      </span>
    </div>
  );
}
