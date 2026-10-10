import 'package:flutter/services.dart';

class WhatsAppBridge {
  static const _channel = MethodChannel('wats/whatsapp');

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

  static Future<bool> clickSend({int timeoutMs = 6000}) async {
    try {
      return await _channel
              .invokeMethod('clickSend', {'timeout': timeoutMs}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> goBack() async {
    try {
      await _channel.invokeMethod('goBack');
    } catch (_) {}
  }

  static Future<void> goHome() async {
    try {
      await _channel.invokeMethod('goHome');
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