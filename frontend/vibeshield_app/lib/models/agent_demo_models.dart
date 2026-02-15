class AgentDemoConfigResponse {
  final bool ok;
  final Map<String, dynamic> config;

  const AgentDemoConfigResponse({required this.ok, required this.config});

  factory AgentDemoConfigResponse.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return AgentDemoConfigResponse(
        ok: json['ok'] == true,
        config: (json['config'] is Map<String, dynamic>)
            ? (json['config'] as Map<String, dynamic>)
            : const <String, dynamic>{},
      );
    }
    return const AgentDemoConfigResponse(ok: false, config: <String, dynamic>{});
  }
}
