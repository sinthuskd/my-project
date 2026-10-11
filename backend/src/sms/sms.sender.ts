/** Nest injection token for the SMS implementation. */
export const SMS_SENDER = 'SMS_SENDER';

export interface SmsSender {
  send(toE164: string, message: string): Promise<void> | void;
}

/**
 * Development sender: prints the SMS in the backend terminal.
 *
 * To send real SMS, write another class with the same `send()` method
 * (Twilio, Dialog, Mobitel, Notify.lk ...) and use it in app.module.ts.
 */
export class ConsoleSmsSender implements SmsSender {
  send(toE164: string, message: string) {
    console.log(`\n[SMS -> ${toE164}] ${message}\n`);
  }
}
