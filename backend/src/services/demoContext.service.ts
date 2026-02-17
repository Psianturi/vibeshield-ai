export type DemoSeverity = 'HIGH' | 'CRITICAL';

export interface InjectedContext {
  token: string;
  headline: string;
  severity: DemoSeverity;
  timestamp: number;
  expiresAt: number;
  consumed: boolean;
}

const DEFAULT_TTL_MS = 3 * 60 * 1000;

class DemoContextManager {
  private context: InjectedContext | null = null;

  inject(params: {
    token: string;
    headline: string;
    severity?: DemoSeverity;
    ttlMs?: number;
  }): InjectedContext {
    const ttlMs = Number.isFinite(params.ttlMs)
      ? Math.max(15_000, Number(params.ttlMs))
      : DEFAULT_TTL_MS;

    const now = Date.now();
    this.context = {
      token: String(params.token || '').trim().toUpperCase(),
      headline: String(params.headline || '').trim(),
      severity: params.severity ?? 'CRITICAL',
      timestamp: now,
      expiresAt: now + ttlMs,
      consumed: false,
    };

    console.log(`[DemoContext] injected token=${this.context.token} severity=${this.context.severity} ttlMs=${ttlMs}`);
    return this.context;
  }

  getActiveContext(token: string): InjectedContext | null {
    if (!this.context) return null;
    if (Date.now() > this.context.expiresAt) {
      this.context = null;
      return null;
    }

    const target = String(token || '').trim().toUpperCase();
    if (!target || this.context.token !== target || this.context.consumed) {
      return null;
    }

    return this.context;
  }

  markConsumed(token?: string): void {
    if (!this.context) return;
    if (token) {
      const target = String(token).trim().toUpperCase();
      if (this.context.token !== target) return;
    }

    this.context.consumed = true;
    console.log('[DemoContext] context marked consumed');
  }

  clear(): void {
    this.context = null;
  }

  getSnapshot(): InjectedContext | null {
    if (!this.context) return null;
    if (Date.now() > this.context.expiresAt) {
      this.context = null;
      return null;
    }
    return this.context;
  }
}

export const demoContextManager = new DemoContextManager();
