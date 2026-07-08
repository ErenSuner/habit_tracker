import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

// Cihazin internet baglantisi durumunu izler.
//  - [online] : arayuz bunu dinleyip cevrimdisi cubugunu gosterir
//  - [onReconnect] : yeniden baglaninca bekleyen yazmalari gondermek icin
//
// Not: connectivity_plus "ag arayuzu var mi"yi soyler, gercek internet
// erisimini garanti etmez. Yazma kararlari yine de istekteki hataya gore
// verilir (bkz. DataService); bu sinif cubugu ve senkron tetigi icindir.
class NetStatus {
  static final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  static final _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _sub;
  static final List<Future<void> Function()> _reconnectCallbacks = [];

  static Future<void> init() async {
    try {
      online.value = _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      // Belirlenemezse cevrimici varsay (yanlis alarm vermeyelim).
      online.value = true;
    }
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final now = _isOnline(results);
      final wasOffline = !online.value;
      online.value = now;
      // Cevrimdisiyken cevrimici olduysa bekleyen isleri gonder.
      if (now && wasOffline) {
        for (final cb in _reconnectCallbacks) {
          cb();
        }
      }
    });
  }

  // Yeniden baglaninca cagrilacak bir geri cagirim ekler (orn. senkron).
  static void onReconnect(Future<void> Function() cb) {
    _reconnectCallbacks.add(cb);
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
