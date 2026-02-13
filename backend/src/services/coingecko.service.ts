import axios from 'axios';
import { PriceData } from '../types';

export class CoinGeckoService {
  private apiKey: string;
  private baseUrl = 'https://api.coingecko.com/api/v3';

  constructor() {
    this.apiKey = process.env.COINGECKO_API_KEY || '';
  }

  async getPrice(tokenId: string): Promise<PriceData> {
    try {
      const response = await axios.get(`${this.baseUrl}/simple/price`, {
        params: {
          ids: tokenId,
          vs_currencies: 'usd',
          include_24hr_vol: true,
          include_24hr_change: true
        },
        headers: this.apiKey ? { 'x-cg-pro-api-key': this.apiKey } : {}
      });

      const data = response.data[tokenId];
      return {
        token: tokenId,
        price: data.usd,
        volume24h: data.usd_24h_vol,
        priceChange24h: data.usd_24h_change
      };
    } catch (error) {
      console.error('CoinGecko error:', error);
      throw error;
    }
  }
}
