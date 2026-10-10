import 'package:flutter/services.dart';

class WhatsAppBridge {
  static const _channel = MethodChannel('wats/whatsapp');

  // ═══ Callbacks ═══
  static void setListener({
    required void Function(String msg) onProgress,
    required void Function(int sent, int failed) onDone,
  }) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onProgress') {
        onProgress(call.arguments?.toString() ?? '');
      } else if (call.method == 'onDone') {
        try {
          final args = call.arguments as Map;
          final sent = (args['sent'] as num?)?.toInt() ?? 0;
          final failed = (args['failed'] as num?)?.toInt() ?? 0;
          onDone(sent, failed);
        } catch (_) {
          onDone(0, 0);
        }
      }
    });
  }

  // ═══ Accessibility ═══
  static Future<bool> isAccessibilityEnabled() async {
    try {
      return await _channel.invokeMethod('isAccessibilityEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  // ═══ WhatsApp ═══
  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
    bool useBusiness = false,
  }) async {
    try {
      return await _channel.invokeMethod('openWhatsApp', {
            'phone': phone,
            'message': message,
            'business': useBusiness,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// ⭐ السحر — يرسل كل الرسائل من Native (أسرع)
  static Future<void> sendBulk({
    required String message,
    required int count,
    required int delayMs,
  }) async {
    try {
      await _channel.invokeMethod('sendBulk', {
        'message': message,
        'count': count,
        'delayMs': delayMs,
      });
    } catch (_) {}
  }

  static Future<void> stopBulk() async {
    try {
      await _channel.invokeMethod('stopBulk');
    } catch (_) {}
  }

  static Future<bool> isWhatsAppInstalled({bool business = false}) async {
    try {
      return await _channel
              .invokeMethod('isWhatsAppInstalled', {'business': business}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}