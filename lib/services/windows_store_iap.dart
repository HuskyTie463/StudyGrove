import 'package:flutter/services.dart';

import 'subscription_catalog.dart';

/// WinRT `StoreContext` bridge. Queries the Partner Center identity
/// `studygrove_pro_monthly` (listing Store ID `9PP0RQTCQ47R` is not the query key).
class WindowsStoreSnapshot {
  const WindowsStoreSnapshot({
    required this.available,
    required this.owned,
    required this.productFound,
    this.price,
    this.title,
    this.status,
    this.message,
  });

  final bool available;
  final bool owned;
  final bool productFound;
  final String? price;
  final String? title;
  final String? status;
  final String? message;

  factory WindowsStoreSnapshot.fromMap(dynamic raw) {
    final map = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    return WindowsStoreSnapshot(
      available: map['available'] == true,
      owned: map['owned'] == true,
      productFound: map['productFound'] == true,
      price: map['price'] as String?,
      title: map['title'] as String?,
      status: map['status'] as String?,
      message: map['message'] as String?,
    );
  }

  bool get showNotListedMessage => !owned && !productFound;
}

class WindowsStoreIap {
  WindowsStoreIap({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('studygrove/windows_store');

  final MethodChannel _channel;

  static final instance = WindowsStoreIap();

  Future<WindowsStoreSnapshot> query() => _invoke('query');

  Future<WindowsStoreSnapshot> purchase() => _invoke(
        'purchase',
        <String, String>{
          'productId': SubscriptionCatalog.windowsMonthlyProductId,
        },
      );

  Future<WindowsStoreSnapshot> _invoke(
    String method, [
    Map<String, String>? args,
  ]) async {
    try {
      final raw = await _channel.invokeMethod<dynamic>(method, args);
      return WindowsStoreSnapshot.fromMap(raw);
    } on MissingPluginException {
      return const WindowsStoreSnapshot(
        available: false,
        owned: false,
        productFound: false,
        message: SubscriptionCatalog.windowsAddOnNotListedMessage,
      );
    } on PlatformException catch (e) {
      return WindowsStoreSnapshot(
        available: false,
        owned: false,
        productFound: false,
        message: e.message?.isNotEmpty == true
            ? e.message
            : SubscriptionCatalog.windowsAddOnNotListedMessage,
      );
    }
  }
}
