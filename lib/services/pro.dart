import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// How a purchase or a restore ended.
enum ProOutcome {
  unlocked,

  /// Waiting for approval, e.g. Ask to Buy or a slow payment method; Pro
  /// unlocks by itself once the store confirms it.
  pending,
  canceled,

  /// A restore found no earlier purchase on this account.
  notFound,
  failed,
}

/// Spurtly Pro: a one-time purchase that unlocks unlimited workouts and the
/// lock-screen controls. Listeners hear when it unlocks or the price loads.
abstract class SpurtlyPro extends ChangeNotifier {
  /// How many workouts the free version keeps; Pro has no limit.
  static const freeWorkouts = 3;

  bool get unlocked;

  /// The price in the user's currency, e.g. "4,99 €"; null until the store
  /// answers, or when it can't be reached.
  String? get price;

  /// Shows the store's payment sheet.
  Future<ProOutcome> buy();

  /// Looks for an earlier purchase on this Apple ID or Google account.
  Future<ProOutcome> restore();

  /// Opens the store's screen for offer and promo codes.
  Future<void> redeemCode();
}

/// [SpurtlyPro] bought through the App Store or Google Play. The store is
/// the source of truth; the last answer is kept on the device so Pro also
/// works offline.
class StorePro extends SpurtlyPro {
  StorePro({InAppPurchase? store, SharedPreferencesAsync? prefs})
    : _store = store ?? InAppPurchase.instance,
      _prefs = prefs ?? SharedPreferencesAsync();

  /// The same id in App Store Connect and the Play Console.
  static const productId = 'spurtly_pro';
  static const _cacheKey = 'pro_v1';

  /// Pro in debug builds without a store, for trying the Pro features:
  /// `flutter run --dart-define=SPURTLY_PRO=true`. Always false in release.
  static const _debugUnlocked =
      kDebugMode && bool.fromEnvironment('SPURTLY_PRO');

  final InAppPurchase _store;
  final SharedPreferencesAsync _prefs;
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  AppLifecycleListener? _lifecycle;
  ProductDetails? _product;
  bool _unlocked = false;

  /// The purchase started by [buy], completed from the purchase stream.
  Completer<ProOutcome>? _buying;

  /// Completed by the batch of restored purchases, with whether it has Pro.
  Completer<bool>? _restoring;

  @override
  bool get unlocked => _unlocked || _debugUnlocked;

  @override
  String? get price => _product?.price;

  /// Reads the cached answer, then checks with the store in the background.
  Future<void> load() async {
    try {
      _unlocked = await _prefs.getBool(_cacheKey) ?? false;
    } catch (error) {
      debugPrint('Could not read Spurtly Pro: $error');
    }
    unawaited(_connect());
  }

  Future<void> _connect() async {
    // Listen first: purchases that finished while the app was closed are
    // delivered now and still have to be completed.
    _purchases = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => debugPrint('Purchase stream: $error'),
    );
    // Codes redeemed in the Play Store arrive while the app is away.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_unlocked) unawaited(_check(revoke: false));
      },
    );
    try {
      if (!await _store.isAvailable()) return;
      final response = await _store.queryProductDetails({productId});
      _product = response.productDetails
          .where((product) => product.id == productId)
          .firstOrNull;
      notifyListeners();
    } catch (error) {
      debugPrint('Could not load Spurtly Pro: $error');
    }
    // Picks up refunds, and purchases from another device or a code.
    await _check(revoke: true);
  }

  @override
  Future<ProOutcome> buy() async {
    if (_buying case final buying? when !buying.isCompleted) {
      return buying.future;
    }
    final product = _product;
    if (product == null) return ProOutcome.failed;
    final buying = _buying = Completer<ProOutcome>();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) return ProOutcome.failed;
    } catch (error) {
      debugPrint('Purchase failed: $error');
      return ProOutcome.failed;
    }
    return buying.future;
  }

  @override
  Future<ProOutcome> restore() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Fetches purchases made on other devices; the App Store may ask the
      // user to sign in, which is fine for a tap on Restore.
      try {
        await _store
            .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>()
            .sync();
      } catch (error) {
        debugPrint('App Store sync failed: $error');
      }
    }
    return switch (await _check(revoke: true)) {
      true => ProOutcome.unlocked,
      false => ProOutcome.notFound,
      null => ProOutcome.failed,
    };
  }

  @override
  Future<void> redeemCode() async {
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          await _store
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>()
              .presentCodeRedemptionSheet();
        case TargetPlatform.android:
          // There is no in-app sheet; the purchase shows up when the user
          // comes back (see the lifecycle listener).
          await launchUrl(
            Uri.parse('https://play.google.com/redeem'),
            mode: LaunchMode.externalApplication,
          );
        default:
          break;
      }
    } catch (error) {
      debugPrint('Could not open code redemption: $error');
    }
  }

  /// Asks the store whether this account owns Pro and caches the answer;
  /// null when the store didn't answer. With [revoke], a "no" locks Pro
  /// again (after a refund); otherwise it only ever unlocks.
  Future<bool?> _check({required bool revoke}) async {
    final restoring = _restoring ??= Completer<bool>();
    bool? owned;
    try {
      await _store.restorePurchases();
      owned = await restoring.future.timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('Could not check Spurtly Pro: $error');
    } finally {
      if (identical(_restoring, restoring)) _restoring = null;
    }
    if (owned == true || (owned == false && revoke)) _setUnlocked(owned!);
    return owned;
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    // A restore always answers with one batch, empty if nothing is owned;
    // purchases in progress come with other statuses.
    final restoring = _restoring;
    if (restoring != null &&
        !restoring.isCompleted &&
        purchases.every((p) => p.status == PurchaseStatus.restored)) {
      restoring.complete(purchases.any(_ownsPro));
    }

    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      final outcome = switch (purchase.status) {
        _ when _isPending(purchase) => ProOutcome.pending,
        PurchaseStatus.purchased || PurchaseStatus.restored => null,
        PurchaseStatus.canceled => ProOutcome.canceled,
        _ => ProOutcome.failed,
      };
      if (_ownsPro(purchase)) {
        _setUnlocked(true);
        _finishBuying(ProOutcome.unlocked);
      } else if (outcome != null) {
        _finishBuying(outcome);
      }
      // Unfinished transactions are offered again on every launch, and
      // Google Play refunds purchases that aren't acknowledged in 3 days.
      if (purchase.pendingCompletePurchase && !_isPending(purchase)) {
        unawaited(
          _store
              .completePurchase(purchase)
              .catchError((Object e) => debugPrint('Completing: $e')),
        );
      }
    }
  }

  static bool _ownsPro(PurchaseDetails purchase) =>
      purchase.productID == productId &&
      (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) &&
      !_isPending(purchase);

  /// Google Play reports a purchase that still awaits payment as "restored"
  /// when restoring, so its own state has to be checked too.
  static bool _isPending(PurchaseDetails purchase) =>
      purchase.status == PurchaseStatus.pending ||
      (purchase is GooglePlayPurchaseDetails &&
          purchase.billingClientPurchase.purchaseState ==
              PurchaseStateWrapper.pending);

  void _finishBuying(ProOutcome outcome) {
    final buying = _buying;
    if (buying != null && !buying.isCompleted) buying.complete(outcome);
  }

  void _setUnlocked(bool unlocked) {
    if (unlocked == _unlocked) return;
    _unlocked = unlocked;
    notifyListeners();
    unawaited(
      _prefs
          .setBool(_cacheKey, unlocked)
          .catchError((Object e) => debugPrint('Could not save Pro: $e')),
    );
  }

  @override
  void dispose() {
    unawaited(_purchases?.cancel());
    _lifecycle?.dispose();
    super.dispose();
  }
}
