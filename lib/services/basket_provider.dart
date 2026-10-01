import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BasketItem {
  final String barcode;
  final String name;
  int quantity;

  BasketItem({required this.barcode, required this.name, this.quantity = 1});

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'quantity': quantity,
  };

  factory BasketItem.fromJson(Map<String, dynamic> json) => BasketItem(
    barcode: (json['barcode'] ?? '').toString(),
    name: (json['name'] ?? '').toString(),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );

  BasketItem copyWith({String? barcode, String? name, int? quantity}) {
    return BasketItem(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
    );
  }
}

class UserBasket {
  final String id;
  String name;
  final List<BasketItem> items;
  DateTime createdAt;
  DateTime updatedAt;

  UserBasket({
    required this.id,
    required this.name,
    List<BasketItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalCount => items.fold(0, (sum, i) => sum + i.quantity);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory UserBasket.fromJson(Map<String, dynamic> json) => UserBasket(
    id: (json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString(),
    name: (json['name'] ?? 'סל קניות').toString(),
    items: ((json['items'] as List<dynamic>?) ?? [])
        .map((i) => BasketItem.fromJson(i as Map<String, dynamic>))
        .toList(),
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
  );

  UserBasket cloneWithNewName(String newName, {String? newId}) {
    return UserBasket(
      id: newId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: newName,
      items: items.map((i) => i.copyWith()).toList(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Compact QR code representation (only minimal essential data: name + barcode:qty pairs)
  /// Format: KUPA:BASKET:v1|Basket Name|barcode1:qty1,barcode2:qty2
  String toQrPayload() {
    final cleanName = name.replaceAll('|', ' ').trim();
    final itemsCompact = items.map((i) => '${i.barcode}:${i.quantity}').join(',');
    return 'KUPA:BASKET:v1|$cleanName|$itemsCompact';
  }

  static UserBasket? fromQrPayload(String qrText) {
    if (!qrText.startsWith('KUPA:BASKET:v1|')) return null;
    final parts = qrText.split('|');
    if (parts.length < 3) return null;

    final basketName = parts[1].trim().isEmpty ? 'סל משותף' : parts[1].trim();
    final itemsStr = parts[2].trim();
    final List<BasketItem> parsedItems = [];

    if (itemsStr.isNotEmpty) {
      final pairs = itemsStr.split(',');
      for (var pair in pairs) {
        final pairParts = pair.split(':');
        if (pairParts.isNotEmpty && pairParts[0].trim().isNotEmpty) {
          final barcode = pairParts[0].trim();
          final qty = pairParts.length > 1 ? (int.tryParse(pairParts[1].trim()) ?? 1) : 1;
          parsedItems.add(BasketItem(barcode: barcode, name: 'מוצר $barcode', quantity: qty));
        }
      }
    }

    return UserBasket(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '$basketName (משותף)',
      items: parsedItems,
    );
  }
}

class BasketProvider extends ChangeNotifier {
  // SharedPreferences Keys
  static const String _kAllBasketsKey = 'kupa_all_baskets_v3';
  static const String _kActiveBasketIdKey = 'kupa_active_basket_id_v3';
  
  // Legacy migration keys to guarantee zero data loss between app updates
  static const String _kLegacyBasketKeyV2 = 'saved_basket_items_v2';
  static const String _kLegacyBasketKeyV1 = 'saved_basket_items_v1';

  final List<UserBasket> _baskets = [];
  String _activeBasketId = '';
  bool _isLoaded = false;

  BasketProvider() {
    _loadFromPrefs();
  }

  List<UserBasket> get allBaskets => _baskets;
  String get activeBasketId => _activeBasketId;
  bool get isLoaded => _isLoaded;

  UserBasket get activeBasket {
    if (_baskets.isEmpty) {
      final defaultBasket = UserBasket(
        id: 'default',
        name: 'הסל שלי 🛒',
      );
      _baskets.add(defaultBasket);
      _activeBasketId = defaultBasket.id;
      return defaultBasket;
    }
    return _baskets.firstWhere(
      (b) => b.id == _activeBasketId,
      orElse: () => _baskets.first,
    );
  }

  // Active Basket Shortcuts for backward compatibility with existing UI
  List<BasketItem> get items => activeBasket.items;
  int get count => activeBasket.totalCount;
  String get currentBasketName => activeBasket.name;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final rawJson = prefs.getString(_kAllBasketsKey);
    final savedActiveId = prefs.getString(_kActiveBasketIdKey);

    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> list = json.decode(rawJson);
        _baskets.clear();
        for (var item in list) {
          _baskets.add(UserBasket.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        print('Error decoding saved baskets: $e');
      }
    }

    // Migration from older app versions (saved_basket_items_v2 / v1)
    if (_baskets.isEmpty) {
      final legacyV2 = prefs.getStringList(_kLegacyBasketKeyV2) ?? prefs.getStringList(_kLegacyBasketKeyV1);
      final List<BasketItem> migratedItems = [];
      if (legacyV2 != null && legacyV2.isNotEmpty) {
        for (var str in legacyV2) {
          try {
            migratedItems.add(BasketItem.fromJson(json.decode(str)));
          } catch (_) {}
        }
      }

      _baskets.add(UserBasket(
        id: 'default',
        name: 'הסל הראשי שלי 🛒',
        items: migratedItems,
      ));
    }

    if (savedActiveId != null && _baskets.any((b) => b.id == savedActiveId)) {
      _activeBasketId = savedActiveId;
    } else {
      _activeBasketId = _baskets.first.id;
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = json.encode(_baskets.map((b) => b.toJson()).toList());
    await prefs.setString(_kAllBasketsKey, rawJson);
    await prefs.setString(_kActiveBasketIdKey, _activeBasketId);

    // Keep legacy key synced so older app rollbacks won't break
    final activeItems = activeBasket.items;
    final legacyList = activeItems.map((i) => json.encode(i.toJson())).toList();
    await prefs.setStringList(_kLegacyBasketKeyV2, legacyList);
  }

  /// Switch the active basket to another basket
  void switchBasket(String basketId) {
    if (_baskets.any((b) => b.id == basketId)) {
      _activeBasketId = basketId;
      notifyListeners();
      _saveToPrefs();
    }
  }

  /// Create a new basket and optionally switch to it immediately
  UserBasket createBasket(String name, {bool makeActive = true}) {
    final cleanName = name.trim().isEmpty ? 'סל חדש ${DateTime.now().minute}' : name.trim();
    final newBasket = UserBasket(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: cleanName,
    );
    _baskets.add(newBasket);
    if (makeActive) {
      _activeBasketId = newBasket.id;
    }
    notifyListeners();
    _saveToPrefs();
    return newBasket;
  }

  /// Rename an existing basket
  void renameBasket(String basketId, String newName) {
    final idx = _baskets.indexWhere((b) => b.id == basketId);
    if (idx >= 0 && newName.trim().isNotEmpty) {
      _baskets[idx].name = newName.trim();
      _baskets[idx].updatedAt = DateTime.now();
      notifyListeners();
      _saveToPrefs();
    }
  }

  /// Duplicate / save version of a basket (e.g. "קניות לשבת - גרסה 2")
  UserBasket duplicateBasket(String basketId, {String? customName}) {
    final original = _baskets.firstWhere((b) => b.id == basketId, orElse: () => activeBasket);
    final duplicateName = customName ?? '${original.name} (העתק)';
    final cloned = original.cloneWithNewName(duplicateName);
    _baskets.add(cloned);
    _activeBasketId = cloned.id;
    notifyListeners();
    _saveToPrefs();
    return cloned;
  }

  /// Import a basket from a scanned QR payload
  UserBasket? importBasketFromQr(String qrText, {bool makeActive = true}) {
    final imported = UserBasket.fromQrPayload(qrText);
    if (imported == null) return null;

    _baskets.add(imported);
    if (makeActive) {
      _activeBasketId = imported.id;
    }
    notifyListeners();
    _saveToPrefs();
    return imported;
  }

  /// Delete a basket
  void deleteBasket(String basketId) {
    if (_baskets.length <= 1) {
      // Don't leave zero baskets, simply clear active items
      activeBasket.items.clear();
      activeBasket.name = 'הסל שלי 🛒';
      notifyListeners();
      _saveToPrefs();
      return;
    }

    _baskets.removeWhere((b) => b.id == basketId);
    if (_activeBasketId == basketId) {
      _activeBasketId = _baskets.first.id;
    }
    notifyListeners();
    _saveToPrefs();
  }

  /// Add item to the currently active basket
  void addItem(String barcode, String name, {int qty = 1}) {
    addItemToBasket(_activeBasketId, barcode, name, qty: qty);
  }

  /// Add item to a specific basket (or target chosen during scanning)
  void addItemToBasket(String basketId, String barcode, String name, {int qty = 1}) {
    final targetBasket = _baskets.firstWhere((b) => b.id == basketId, orElse: () => activeBasket);
    final existing = targetBasket.items.indexWhere((i) => i.barcode == barcode);
    if (existing >= 0) {
      targetBasket.items[existing].quantity += qty;
    } else {
      targetBasket.items.add(BasketItem(barcode: barcode, name: name, quantity: qty));
    }
    targetBasket.updatedAt = DateTime.now();
    notifyListeners();
    _saveToPrefs();
  }

  void removeItem(String barcode) {
    activeBasket.items.removeWhere((i) => i.barcode == barcode);
    activeBasket.updatedAt = DateTime.now();
    notifyListeners();
    _saveToPrefs();
  }

  void updateQuantity(String barcode, int delta) {
    final idx = activeBasket.items.indexWhere((i) => i.barcode == barcode);
    if (idx >= 0) {
      activeBasket.items[idx].quantity += delta;
      if (activeBasket.items[idx].quantity <= 0) {
        activeBasket.items.removeAt(idx);
      }
      activeBasket.updatedAt = DateTime.now();
      notifyListeners();
      _saveToPrefs();
    }
  }

  void setQuantity(String barcode, int exactQty) {
    final idx = activeBasket.items.indexWhere((i) => i.barcode == barcode);
    if (idx >= 0) {
      if (exactQty <= 0) {
        activeBasket.items.removeAt(idx);
      } else {
        activeBasket.items[idx].quantity = exactQty;
      }
      activeBasket.updatedAt = DateTime.now();
      notifyListeners();
      _saveToPrefs();
    }
  }

  void clear() {
    activeBasket.items.clear();
    activeBasket.updatedAt = DateTime.now();
    notifyListeners();
    _saveToPrefs();
  }
}
