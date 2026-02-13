class SentimentData {
  final String token;
  final double score;
  final int timestamp;
  final List<String> sources;

  SentimentData({
    required this.token,
    required this.score,
    required this.timestamp,
    required this.sources,
  });

  factory SentimentData.fromJson(Map<String, dynamic> json) {
    return SentimentData(
      token: json['token'],
      score: (json['score'] as num).toDouble(),
      timestamp: json['timestamp'],
      sources: List<String>.from(json['sources'] ?? []),
    );
  }
}

class PriceData {
  final String token;
  final double price;
  final double volume24h;
  final double priceChange24h;

  PriceData({
    required this.token,
    required this.price,
    required this.volume24h,
    required this.priceChange24h,
  });

  factory PriceData.fromJson(Map<String, dynamic> json) {
    return PriceData(
      token: json['token'],
      price: (json['price'] as num).toDouble(),
      volume24h: (json['volume24h'] as num).toDouble(),
      priceChange24h: (json['priceChange24h'] as num).toDouble(),
    );
  }
}

class RiskAnalysis {
  final double riskScore;
  final bool shouldExit;
  final String reason;
  final String aiModel;

  RiskAnalysis({
    required this.riskScore,
    required this.shouldExit,
    required this.reason,
    required this.aiModel,
  });

  factory RiskAnalysis.fromJson(Map<String, dynamic> json) {
    return RiskAnalysis(
      riskScore: (json['riskScore'] as num).toDouble(),
      shouldExit: json['shouldExit'],
      reason: json['reason'],
      aiModel: json['aiModel'],
    );
  }
}

class VibeCheckResult {
  final SentimentData sentiment;
  final PriceData price;
  final RiskAnalysis analysis;

  VibeCheckResult({
    required this.sentiment,
    required this.price,
    required this.analysis,
  });

  factory VibeCheckResult.fromJson(Map<String, dynamic> json) {
    return VibeCheckResult(
      sentiment: SentimentData.fromJson(json['sentiment']),
      price: PriceData.fromJson(json['price']),
      analysis: RiskAnalysis.fromJson(json['analysis']),
    );
  }
}
