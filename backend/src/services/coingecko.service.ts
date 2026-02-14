import axios from 'axios';
import { PriceData } from '../types';

export class CoinGeckoService {
  private apiKey: string;
  private baseUrl = 'https://api.coingecko.com/api/v3';

  constructor() {
    this.apiKey = process.env.COINGECKO_API_KEY || '';
  }

  private formatAxiosError(error: any): string {
    const status = error?.response?.status;
    const statusText = error?.response?.statusText;
    const message = error?.message;
    return [status ? `status ${status}` : null, statusText, message].filter(Boolean).join(' - ');
  }

  async getPrice(tokenId: string): Promise<PriceData> {
    try {
      const params = {
        ids: tokenId,
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
        // Some setups return 400/401/403 when a key is invalid or restricted.
        // Public endpoint often works without a key, so we retry once.
        response = await axios.get(`${this.baseUrl}/simple/price`, {
          params,
          timeout: 15000
        });
      }

      const data = response.data[tokenId];
      if (!data || typeof data.usd !== 'number') {
        throw new Error(`CoinGecko: missing data for tokenId='${tokenId}'`);
      }
      return {
        token: tokenId,
        price: data.usd,
        volume24h: data.usd_24h_vol,
        priceChange24h: data.usd_24h_change
      };
    } catch (error) {
      const msg = this.formatAxiosError(error);
      console.error('CoinGecko error:', msg);
      throw new Error(msg || 'CoinGecko request failed');
    }
  }

  async getPrices(tokenIds: string[]): Promise<PriceData[]> {
    const ids = tokenIds.map((s) => String(s || '').trim()).filter(Boolean);
    if (ids.length === 0) return [];

    try {
      const params = {
        ids: ids.join(','),
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
        response = await axios.get(`${this.baseUrl}/simple/price`, {
          params,
          timeout: 15000
        });
      }

      const out: PriceData[] = [];
      for (const tokenId of ids) {
        const data = response.data?.[tokenId];
        if (!data || typeof data.usd !== 'number') continue;
        out.push({
          token: tokenId,
          price: data.usd,
          volume24h: typeof data.usd_24h_vol === 'number' ? data.usd_24h_vol : 0,
          priceChange24h: typeof data.usd_24h_change === 'number' ? data.usd_24h_change : 0
        });
      }
      return out;
    } catch (error) {
      const msg = this.formatAxiosError(error);
      console.error('CoinGecko error:', msg);
      throw new Error(msg || 'CoinGecko request failed');
    }
  }
}
