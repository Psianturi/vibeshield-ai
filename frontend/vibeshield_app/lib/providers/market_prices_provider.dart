import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vibe_models.dart';
import 'vibe_provider.dart';

final marketPricesProvider = StreamProvider.autoDispose<List<PriceData>>((ref) {
  final api = ref.watch(apiServiceProvider);

  var cancelled = false;
  ref.onDispose(() {
    cancelled = true;
  });

  Stream<List<PriceData>> stream() async* {
    const ids = ['bitcoin', 'binancecoin', 'ethereum', 'tether'];

    while (!cancelled) {
      try {
        final items = await api.getMarketPrices(ids: ids);
        if (cancelled) break;
        yield items;
      } catch (_) {
        if (cancelled) break;
        yield const <PriceData>[];
      }

      await Future.delayed(const Duration(seconds: 18));
    }
  }

  return stream();
});
