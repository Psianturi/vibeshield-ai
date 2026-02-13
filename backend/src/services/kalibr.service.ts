import axios from 'axios';
import { RiskAnalysis, SentimentData, PriceData } from '../types';

export class KalibrService {
  private apiKey: string;
  private baseUrl = 'https://api.kalibr.ai/v1';
  private modelHigh: string;
  private modelLow: string;
  private sentimentBadThreshold: number;

  constructor() {
    this.apiKey = process.env.KALIBR_API_KEY || '';
    this.modelHigh = process.env.KALIBR_MODEL_HIGH || 'gpt-4o';
    this.modelLow = process.env.KALIBR_MODEL_LOW || 'gpt-4o-mini';
    this.sentimentBadThreshold = Number(process.env.SENTIMENT_BAD_THRESHOLD ?? 30);
  }

  async analyzeRisk(sentiment: SentimentData, price: PriceData): Promise<RiskAnalysis> {
    try {
      const prompt = `Analyze crypto risk:
Token: ${sentiment.token}
Sentiment Score: ${sentiment.score}/100
Price Change 24h: ${price.priceChange24h}%
Volume 24h: $${price.volume24h}

Should we exit position? Respond with JSON: {riskScore: 0-100, shouldExit: boolean, reason: string}`;

      const chosenModel = sentiment.score < this.sentimentBadThreshold ? this.modelHigh : this.modelLow;

      const response = await axios.post(
        `${this.baseUrl}/chat/completions`,
        {
          model: chosenModel,
          messages: [{ role: 'user', content: prompt }],
          response_format: { type: 'json_object' }
        },
        {
          headers: { 'Authorization': `Bearer ${this.apiKey}` }
        }
      );

      const result = JSON.parse(response.data.choices[0].message.content);
      return {
        ...result,
        aiModel: chosenModel
      };
    } catch (error) {
      console.error('Kalibr error:', error);
      return {
        riskScore: 50,
        shouldExit: false,
        reason: 'Analysis failed',
        aiModel: 'fallback'
      };
    }
  }
}
