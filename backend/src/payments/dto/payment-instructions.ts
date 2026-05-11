import { PaymentProvider } from '@prisma/client';

/**
 * Provider-specific instructions returned to the client when an order is
 * placed. The client uses these to either complete the flow inline (CASH)
 * or redirect the customer to the provider's hosted checkout.
 */
export interface PaymentInstructions {
  provider: PaymentProvider;
  paymentId: string;
  /** CASH only — the customer is told to pay at pickup. */
  payAtPickup?: boolean;
  /** Stripe / VNPay / MoMo — the URL to redirect to. */
  redirectUrl?: string;
  /** Stripe Payment Intents flow (mobile, future). */
  clientSecret?: string;
  /** Human-readable hint for unconfigured providers. */
  configurationError?: string;
}
