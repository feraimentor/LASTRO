import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: { default: "LASTRO", template: "%s | LASTRO" },
  description: "Memória comunitária de problemas e demandas do Condomínio Alto Icaraí.",
  applicationName: "LASTRO",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="pt-BR" className="h-full antialiased">
      <body className="min-h-full">{children}</body>
    </html>
  );
}
