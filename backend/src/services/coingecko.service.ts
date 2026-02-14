import axios from 'axios';
import { PriceData } from '../types';

export class CoinGeckoService {
  private apiKey: string;
  private baseUrl: string;
  private cache = new Map<string, { data: PriceData; fetchedAt: number }>();

  // Keep cache short to avoid showing stale prices.
  private cacheTtlMs = Number(process.env.COINGECKO_CACHE_TTL_MS ?? 30_000);
  private staleIfErrorMs = Number(process.env.COINGECKO_STALE_IF_ERROR_MS ?? 5 * 60_000);

  constructor() {
    this.apiKey = process.env.COINGECKO_API_KEY || '';

    const configuredBase = String(process.env.COINGECKO_BASE_URL || '').trim();
    const defaultBase = this.apiKey ? 'https://pro-api.coingecko.com/api/v3' : 'https://api.coingecko.com/api/v3';
    this.baseUrl = (configuredBase || defaultBase).replace(/\/+$/, '');
  }

  private isProBaseUrl(): boolean {
    return this.baseUrl.includes('pro-api.coingecko.com');
  }

  private getCached(tokenId: string): PriceData | null {
    const entry = this.cache.get(tokenId);
    if (!entry) return null;
    if (Date.now() - entry.fetchedAt <= this.cacheTtlMs) return entry.data;
    return null;
  }

  private getStale(tokenId: string): PriceData | null {
    const entry = this.cache.get(tokenId);
    if (!entry) return null;
    if (Date.now() - entry.fetchedAt <= this.staleIfErrorMs) return entry.data;
    return null;
  }

  private setCached(tokenId: string, data: PriceData) {
    this.cache.set(tokenId, { data, fetchedAt: Date.now() });
  }

  private formatAxiosError(error: any): string {
    const status = error?.response?.status;
    const statusText = error?.response?.statusText;
    const message = error?.message;
    return [status ? `status ${status}` : null, statusText, message].filter(Boolean).join(' - ');
  }

  async getPrice(tokenId: string): Promise<PriceData> {
    const cleanId = String(tokenId || '').trim().toLowerCase();
    if (!cleanId) throw new Error('CoinGecko: missing tokenId');

    const cached = this.getCached(cleanId);
    if (cached) return cached;

    try {
      const params = {
        ids: cleanId,
        vs_currencies: 'usd',
        include_24hr_vol: true,
        include_24hr_change: true
      };

      // Try with pro key header if present; if it fails, retry without it.
      let response: any;
      try {
        response = await axios.get(`${this.baseUrl}/simple/price`, {
          params,
          headers: this.apiKey ? { 'x-cg-pro-api-key': this.apiKey } : {},
          timeout: 15000
        });
      } catch (error: any) {
        // If we're using the public API, retry once without a key.
        // For Pro API base URL, do not retry without key.
        if (this.apiKey && this.isProBaseUrl()) {
          throw error;
        }

        response = await axios.get(`${this.baseUrl}/simple/price`, { params, timeout: 15000 });
      }

      const data = response.data[cleanId];
      if (!data || typeof data.usd !== 'number') {
        throw new Error(`CoinGecko: missing data for tokenId='${cleanId}'`);
      }
      const out: PriceData = {
        token: cleanId,
        price: data.usd,
        volume24h: data.usd_24h_vol,
        priceChange24h: data.usd_24h_change
      };
      this.setCached(cleanId, out);
      return out;
    } catch (error) {
      const msg = this.formatAxiosError(error);
      console.error('CoinGecko error:', msg);

      // If CoinGecko rate-limits or temporarily fails, serve stale cache if we have it.
      const stale = this.getStale(String(tokenId || '').trim());
      if (stale) return stale;

      throw new Error(msg || 'CoinGecko request failed');
    }
  }

  async getPrices(tokenIds: string[]): Promise<PriceData[]> {
    const ids = tokenIds.map((s) => String(s || '').trim().toLowerCase()).filter(Boolean);
    if (ids.length === 0) return [];

    const now = Date.now();
    const fresh: PriceData[] = [];
    const missing: string[] = [];

    for (const id of ids) {
      const entry = this.cache.get(id);
      if (entry && now - entry.fetchedAt <= this.cacheTtlMs) {
        fresh.push(entry.data);
      } else {
        missing.push(id);
      }
    }

    if (missing.length === 0) return fresh;

    try {
      const params = {
        ids: missing.join(','),
        vs_currencies: 'usd',
        include_24hr_vol: true,
        include_24hr_change: true
      };

      let response: any;
      try {
        response = await axios.get(`${this.baseUrl}/simple/price`, {
          params,
          headers: this.apiKey ? { 'x-cg-pro-api-key': this.apiKey } : {},
          timeout: 15000
        });
      } catch (error: any) {
        if (this.apiKey && this.isProBaseUrl()) {
          throw error;
        }

        response = await axios.get(`${this.baseUrl}/simple/price`, { params, timeout: 15000 });
      }

      const out: PriceData[] = [...fresh];
      for (const tokenId of missing) {
        const data = response.data?.[tokenId];
        if (!data || typeof data.usd !== 'number') continue;
        const item: PriceData = {
          token: tokenId,
          price: data.usd,
          volume24h: typeof data.usd_24h_vol === 'number' ? data.usd_24h_vol : 0,
          priceChange24h: typeof data.usd_24h_change === 'number' ? data.usd_24h_change : 0
        };
        this.setCached(tokenId, item);
        out.push(item);
      }
      return out;
    } catch (error) {
      const msg = this.formatAxiosError(error);
      console.error('CoinGecko error:', msg);

      // Best-effort: return any stale values we have instead of failing.
      const fallback: PriceData[] = [];
      for (const id of ids) {
        const stale = this.getStale(id);
        if (stale) fallback.push(stale);
      }
      if (fallback.length > 0) return fallback;

      throw new Error(msg || 'CoinGecko request failed');
    }
  }
}
