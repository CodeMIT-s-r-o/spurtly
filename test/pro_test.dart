import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spurtly/services/pro.dart';

class _FakeStore extends Fake implements InAppPurchase {
  final _purchases = StreamController<List<PurchaseDetails>>.broadcast();

  /// What a restore reports; null makes it fail, like when offline.
  List<PurchaseDetails>? owned = [];

  /// What the payment sheet ends with.
  List<PurchaseDetails> bought = [];

  final completed = <PurchaseDetails>[];

  void deliver(List<PurchaseDetails> purchases) => _purchases.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async => ProductDetailsResponse(
    productDetails: [
      ProductDetails(
        id: StorePro.productId,
        title: 'Spurtly Pro',
        description: 'Saved workouts and lock-screen controls',
        price: '4,99 €',
        rawPrice: 4.99,
        currencyCode: 'EUR',
      ),
    ],
    notFoundIDs: [],
  );

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    final owned = this.owned;
    if (owned == null) throw PlatformException(code: 'offline');
    deliver(owned);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    scheduleMicrotask(() => deliver(bought));
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async =>
      completed.add(purchase);
}

class _FakePrefs extends Fake implements SharedPreferencesAsync {
  final values = <String, bool>{};

  @override
  Future<bool?> getBool(String key) async => values[key];

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}

PurchaseDetails _purchase(PurchaseStatus status) => PurchaseDetails(
  productID: StorePro.productId,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: '',
    source: 'test',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStore store;
  late _FakePrefs prefs;

  Future<StorePro> loadPro() async {
    final pro = StorePro(store: store, prefs: prefs);
    addTearDown(pro.dispose);
    await pro.load();
    await pumpEventQueue();
    return pro;
  }

  setUp(() {
    store = _FakeStore();
    prefs = _FakePrefs();
  });

  test('starts locked and loads the price', () async {
    final pro = await loadPro();

    expect(pro.unlocked, isFalse);
    expect(pro.price, '4,99 €');
  });

  test('a purchase unlocks Pro, is completed and remembered', () async {
    final pro = await loadPro();
    final purchase = _purchase(PurchaseStatus.purchased);
    store.bought = [purchase];

    expect(await pro.buy(), ProOutcome.unlocked);
    expect(pro.unlocked, isTrue);
    expect(store.completed, [purchase]);
    expect(prefs.values['pro_v1'], isTrue);
  });

  test('a canceled purchase keeps Pro locked', () async {
    final pro = await loadPro();
    store.bought = [_purchase(PurchaseStatus.canceled)];

    expect(await pro.buy(), ProOutcome.canceled);
    expect(pro.unlocked, isFalse);
  });

  test('a pending purchase unlocks once the store confirms it', () async {
    final pro = await loadPro();
    final pending = _purchase(PurchaseStatus.pending);
    store.bought = [pending];

    expect(await pro.buy(), ProOutcome.pending);
    expect(pro.unlocked, isFalse);
    expect(store.completed, isEmpty);

    store.deliver([_purchase(PurchaseStatus.purchased)]);
    await pumpEventQueue();
    expect(pro.unlocked, isTrue);
  });

  test('restore finds an earlier purchase', () async {
    final pro = await loadPro();
    store.owned = [_purchase(PurchaseStatus.restored)];

    expect(await pro.restore(), ProOutcome.unlocked);
    expect(pro.unlocked, isTrue);
    expect(store.completed, hasLength(1));
  });

  test('restore reports when there is nothing to restore', () async {
    final pro = await loadPro();

    expect(await pro.restore(), ProOutcome.notFound);
    expect(pro.unlocked, isFalse);
  });

  test('works offline from the cached answer', () async {
    prefs.values['pro_v1'] = true;
    store.owned = null;

    final pro = await loadPro();
    expect(pro.unlocked, isTrue);
    expect(await pro.restore(), ProOutcome.failed);
    expect(pro.unlocked, isTrue);
  });

  test('locks Pro again after a refund', () async {
    prefs.values['pro_v1'] = true;
    store.owned = [];

    final pro = await loadPro();
    expect(pro.unlocked, isFalse);
    expect(prefs.values['pro_v1'], isFalse);
  });

  test('picks up a purchase made on another device at launch', () async {
    store.owned = [_purchase(PurchaseStatus.restored)];

    final pro = await loadPro();
    expect(pro.unlocked, isTrue);
  });
}
