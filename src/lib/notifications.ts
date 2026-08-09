export type NotificationInput={userId:string;kind:string;title:string;body:string;targetPath?:string;essential:boolean;dedupeKey:string};
export interface NotificationService{enqueue(input:NotificationInput):Promise<void>}
// A implementação de produção é a outbox transacional do PostgreSQL; o envio é drenado por cron.
