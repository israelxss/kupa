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
}

class BasketProvider extends ChangeNotifier {
  static const String _kBasketItemsKey = 'saved_basket_items_v2';
  final List<BasketItem> _items = [];
  bool _isLoaded = false;

  BasketProvider() {
    _loadFromPrefs();
  }

  List<BasketItem> get items => _items;
  int get count => _items.fold(0, (sum, i) => sum + i.quantity);
  bool get isLoaded => _isLoaded;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_kBasketItemsKey);
    if (jsonList != null && jsonList.isNotEmpty) {
      _items.clear();
      for (var str in jsonList) {
        try {
          final map = json.decode(str) as Map<String, dynamic>;
          _items.add(BasketItem.fromJson(map));
        } catch (e) {
          print('Error restoring basket item: $e');
        }
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _items.map((i) => json.encode(i.toJson())).toList();
    await prefs.setStringList(_kBasketItemsKey, jsonList);
  }

  void addItem(String barcode, String name, {int qty = 1}) {
    final existing = _items.indexWhere((i) => i.barcode == barcode);
    if (existing >= 0) {
      _items[existing].quantity += qty;
    } else {
      _items.add(BasketItem(barcode: barcode, name: name, quantity: qty));
    }
    notifyListeners();
    _saveToPrefs();
  }

  void removeItem(String barcode) {
    _items.removeWhere((i) => i.barcode == barcode);
    notifyListeners();
    _saveToPrefs();
  }

  void updateQuantity(String barcode, int delta) {
    final idx = _items.indexWhere((i) => i.barcode == barcode);
    if (idx >= 0) {
      _items[idx].quantity += delta;
      if (_items[idx].quantity <= 0) {
        _items.removeAt(idx);
      }
      notifyListeners();
      _saveToPrefs();
    }
  }

  void setQuantity(String barcode, int exactQty) {
    final idx = _items.indexWhere((i) => i.barcode == barcode);
    if (idx >= 0) {
      if (exactQty <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity = exactQty;
      }
      notifyListeners();
      _saveToPrefs();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _saveToPrefs();
  }
}
