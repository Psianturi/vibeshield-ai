import axios from 'axios';
import { SentimentData } from '../types';

export class CryptoracleService {
  private apiKey: string;
  private baseUrl = 'https://api.cryptoracle.io/v1';

  constructor() {
    this.apiKey = process.env.CRYPTORACLE_API_KEY || '';
  }

  async getSentiment(token: string): Promise<SentimentData> {
    try {
      const response = await axios.get(`${this.baseUrl}/sentiment/${token}`, {
        headers: { 'Authorization': `Bearer ${this.apiKey}` }
      });

      return {
        token,
        score: response.data.score,
        timestamp: Date.now(),
        sources: response.data.sources || []
      };
    } catch (error) {
      console.error('Cryptoracle error:', error);
      return { token, score: 50, timestamp: Date.now(), sources: [] };
    }
  }
}
