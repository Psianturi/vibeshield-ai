export interface SentimentData {
  token: string;
  score: number;
  timestamp: number;
  sources: string[];
}

export interface PriceData {
  token: string;
  price: number;
  volume24h: number;
  priceChange24h: number;
}

export interface RiskAnalysis {
  riskScore: number;
  shouldExit: boolean;
  reason: string;
  aiModel: string;
}

export interface SwapResult {
  success: boolean;
  txHash?: string;
  error?: string;
}
