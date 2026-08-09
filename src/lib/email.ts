import { Resend } from "resend";

export type EmailMessage = { to: string; subject: string; text: string };
export interface EmailProvider { send(message: EmailMessage): Promise<{ id: string }> }

class DevelopmentEmailProvider implements EmailProvider {
  async send(message: EmailMessage) {
    const id = `dev-${crypto.randomUUID()}`;
    console.info(JSON.stringify({ event: "email.simulated", id, toDomain: message.to.split("@")[1], subject: message.subject }));
    return { id };
  }
}

class ResendEmailProvider implements EmailProvider {
  private client: Resend; private from: string;
  constructor(apiKey: string, from: string) { this.client = new Resend(apiKey); this.from = from; }
  async send(message: EmailMessage) {
    const { data, error } = await this.client.emails.send({ from: this.from, ...message });
    if (error || !data) throw new Error("email_delivery_failed");
    return { id: data.id };
  }
}

export function getEmailProvider(): EmailProvider {
  if (process.env.EMAIL_PROVIDER === "resend") {
    if (!process.env.RESEND_API_KEY || !process.env.EMAIL_FROM) throw new Error("resend_configuration_missing");
    return new ResendEmailProvider(process.env.RESEND_API_KEY, process.env.EMAIL_FROM);
  }
  return new DevelopmentEmailProvider();
}
