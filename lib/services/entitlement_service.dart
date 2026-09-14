import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_catalog.dart';
import 'windows_store_iap.dart';

enum EntitlementPlan { free, pro }

/// Free vs Pro.
///
/// iOS / Android / macOS: Apple or Play IAP (`pro_monthly`).
/// Windows release: Microsoft Store add-on `studygrove_pro_monthly`.
/// Debug and `STUDY_GROVE_UNLOCK_PRO` stay Pro for local work. Release
/// Microsoft Store builds do not auto-unlock.
class EntitlementService extends ChangeNotifier {
  EntitlementService({
    InAppPurchase? store,
    WindowsStoreIap? windowsStore,
  })  : _store = store,
        _windowsStore = windowsStore;

  final InAppPurchase? _store;
  final WindowsStoreIap? _windowsStore;

  InAppPurchase get _iap => _store ?? InAppPurchase.instance;
  WindowsStoreIap get _winIap => _windowsStore ?? WindowsStoreIap.instance;

  String? _uid;
  var _storePro = false;
  var _forceFree = false;
  var _ready = false;
  var _storeAvailable = false;
  var _windowsProductFound = false;
  var _busy = false;
  String? _activeProductId;
  String? _status;
  String? _windowsPrice;
  List<ProductDetails> products = const [];
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  bool get ready => _ready;
  bool get busy => _busy;
  bool get storeAvailable => _storeAvailable;
  bool get windowsAddOnListed => _windowsProductFound;
  String? get activeProductId => _activeProductId;
  String? get status => _status;

  bool get _isWindowsDesktop => !kIsWeb && Platform.isWindows;

  String get unlockProductId => _isWindowsDesktop
      ? SubscriptionCatalog.windowsMonthlyProductId
      : SubscriptionCatalog.monthlyProductId;

  bool get isPro => EntitlementPolicy.isPro(
        debugMode: kDebugMode,
        forceFree: _forceFree,
        unlockDefine: EntitlementPolicy.unlockProDefine,
        isLinux: !kIsWeb && Platform.isLinux,
        storePro: _storePro,
      );

  EntitlementPlan get plan => isPro ? EntitlementPlan.pro : EntitlementPlan.free;

  String get planLabel {
    if (!isPro) return 'Free';
    if (_activeProductId == SubscriptionCatalog.monthlyProductId ||
        _activeProductId == SubscriptionCatalog.windowsMonthlyProductId) {
      return 'Pro (monthly)';
    }
    if (_storePro) return 'Pro';
    if (kDebugMode) return 'Pro (debug)';
    return 'Pro';
  }

  bool get showDeveloperOverride => kDebugMode;

  bool get forceFreeForTesting => _forceFree;

  ProductDetails? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  String priceLabel(String id, String fallback) {
    final windowsPrice = _windowsPrice;
    if (_isWindowsDesktop && windowsPrice != null && windowsPrice.isNotEmpty) {
      return windowsPrice;
    }
    return product(id)?.price ?? fallback;
  }

  Future<void> bindUser(String uid) async {
    if (_uid == uid && _ready) return;
    await unbind();
    _uid = uid;
    final prefs = await SharedPreferences.getInstance();
    _storePro = prefs.getBool(_storeKey(uid)) ?? false;
    _activeProductId = prefs.getString(_productKey(uid));
    _forceFree = prefs.getBool(_forceFreeKey(uid)) ?? false;
    _ready = true;
    notifyListeners();
    await _hydrateFromCloud(uid);
    await _startStore();
  }

  Future<void> unbind() async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    _uid = null;
    _storePro = false;
    _forceFree = false;
    _ready = false;
    _storeAvailable = false;
    _windowsProductFound = false;
    _activeProductId = null;
    _status = null;
    _windowsPrice = null;
    products = const [];
    notifyListeners();
  }

  Future<void> setForceFreeForTesting(bool value) async {
    if (!kDebugMode) return;
    _forceFree = value;
    final uid = _uid;
    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_forceFreeKey(uid), value);
    }
    notifyListeners();
  }

  Future<void> unlockPro() => buy(unlockProductId);

  Future<void> buy(String productId) async {
    if (_isWindowsDesktop) {
      await _buyWindows();
      return;
    }
    final details = product(productId);
    if (details == null) {
      _status = 'The store has not listed that plan yet. Try Restore, or check '
          'that $productId exists in App Store Connect / Play Console.';
      notifyListeners();
      return;
    }
    _busy = true;
    _status = null;
    notifyListeners();
    try {
      final ok = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!ok) {
        _status = 'The store could not start that purchase.';
      }
    } catch (e) {
      _status = 'Purchase did not start. $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (_isWindowsDesktop) {
      await _restoreWindows();
      return;
    }
    _busy = true;
    _status = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      _status = isPro
          ? 'Purchases restored. You are on $planLabel.'
          : 'No Pro subscription found for this store account.';
    } catch (e) {
      _status = 'Restore failed. $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _startStore() async {
    if (_isWindowsDesktop) {
      await _refreshWindowsEntitlement(updateStatus: false);
      notifyListeners();
      return;
    }
    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (e) {
      debugPrint('IAP unavailable: $e');
      _storeAvailable = false;
    }
    if (!_storeAvailable) {
      notifyListeners();
      return;
    }
    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        _status = 'Store error. $e';
        notifyListeners();
      },
    );
    try {
      final response = await _iap.queryProductDetails(
        SubscriptionCatalog.productIds,
      );
      products = response.productDetails;
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('IAP products missing: ${response.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('IAP product query failed: $e');
    }
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('IAP restore on bind failed: $e');
    }
    notifyListeners();
  }

  Future<void> _buyWindows() async {
    _busy = true;
    _status = null;
    notifyListeners();
    try {
      final result = await _winIap.purchase();
      await _applyWindowsSnapshot(result, fromPurchase: true);
    } catch (e) {
      _status = SubscriptionCatalog.windowsAddOnNotListedMessage;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _restoreWindows() async {
    _busy = true;
    _status = null;
    notifyListeners();
    try {
      await _refreshWindowsEntitlement(updateStatus: true);
    } catch (e) {
      _status = 'Restore failed. $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _refreshWindowsEntitlement({required bool updateStatus}) async {
    final result = await _winIap.query();
    await _applyWindowsSnapshot(result, fromPurchase: false);
    if (!updateStatus) return;
    if (result.owned) {
      _status = 'Purchases restored. You are on $planLabel.';
    } else if (result.showNotListedMessage) {
      _status = SubscriptionCatalog.windowsAddOnNotListedMessage;
    } else {
      _status = 'No Pro subscription found for this Microsoft account.';
    }
  }

  Future<void> _applyWindowsSnapshot(
    WindowsStoreSnapshot result, {
    required bool fromPurchase,
  }) async {
    _storeAvailable = result.available;
    _windowsProductFound = result.productFound;
    if (result.price != null && result.price!.isNotEmpty) {
      _windowsPrice = result.price;
    }
    if (result.owned) {
      await _setStorePro(
        productId: SubscriptionCatalog.windowsMonthlyProductId,
        purchased: true,
      );
      if (fromPurchase) {
        _status = result.status == 'already_purchased'
            ? 'This Microsoft account already has Pro.'
            : 'You are on Pro.';
      }
      return;
    }
    if (result.available && result.productFound) {
      await _setStorePro(
        productId: SubscriptionCatalog.windowsMonthlyProductId,
        purchased: false,
      );
    }
    if (!fromPurchase) return;
    if (result.status == 'canceled') {
      _status = 'Purchase cancelled.';
    } else if (result.showNotListedMessage) {
      _status = SubscriptionCatalog.windowsAddOnNotListedMessage;
    } else {
      _status = (result.message != null && result.message!.isNotEmpty)
          ? result.message
          : SubscriptionCatalog.windowsAddOnNotListedMessage;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        _status = 'Purchase pending…';
      } else if (purchase.status == PurchaseStatus.error) {
        _status = purchase.error?.message ?? 'Purchase failed.';
      } else if (purchase.status == PurchaseStatus.canceled) {
        _status = 'Purchase cancelled.';
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (SubscriptionCatalog.grantsPro(purchase.productID)) {
          await _setStorePro(
            productId: purchase.productID,
            purchased: true,
          );
          _status = purchase.status == PurchaseStatus.restored
              ? 'Restored ${purchase.productID}.'
              : 'You are on Pro.';
        }
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          debugPrint('IAP complete failed: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> _setStorePro({
    required String productId,
    required bool purchased,
  }) async {
    _storePro = purchased;
    _activeProductId = purchased ? productId : null;
    final uid = _uid;
    if (uid == null || uid.isEmpty || uid == 'NO_USER') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storeKey(uid), purchased);
    if (purchased) {
      await prefs.setString(_productKey(uid), productId);
    } else {
      await prefs.remove(_productKey(uid));
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'entitlement': {
          'plan': purchased ? 'pro' : 'free',
          'productId': purchased ? productId : null,
          'source': 'store',
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _hydrateFromCloud(String uid) async {
    if (uid.isEmpty || uid == 'NO_USER') return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data()?['entitlement'] as Map<String, dynamic>?;
      if (data == null) return;
      final productId = data['productId'] as String?;
      if (productId != null &&
          SubscriptionCatalog.grantsPro(productId) &&
          !_storePro) {
        // Cache only. Store platforms still require a real IAP receipt.
        _activeProductId ??= productId;
      }
    } catch (_) {}
  }

  static String _storeKey(String uid) => 'entitlement_store_pro_$uid';
  static String _productKey(String uid) => 'entitlement_product_$uid';
  static String _forceFreeKey(String uid) => 'entitlement_force_free_$uid';
}

final entitlementService = EntitlementService();
