import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  static const String baseUrl = 'https://www.over.org.il/api/prices';

  // Cache to accelerate repeated searches and comparisons
  static final Map<String, List<ProductItem>> _searchCache = {};
  static final Map<String, ComparisonResult> _compareCache = {};

  static Future<List<ProductItem>> searchProducts(String query, {int limit = 15}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    if (_searchCache.containsKey(cleanQuery)) {
      return _searchCache[cleanQuery]!;
    }

    final uri = Uri.parse(
      '$baseUrl/table/prices_products?q=${Uri.encodeComponent(cleanQuery)}&limit=$limit&columns=item_code,item_name,manufacturer_name,unit_of_measure',
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final rows = data['rows'] as List<dynamic>? ?? [];

        final Map<String, ProductItem> unique = {};
        for (var r in rows) {
          final item = ProductItem.fromJson(r as Map<String, dynamic>);
          if (item.itemCode.isNotEmpty && !unique.containsKey(item.itemCode)) {
            unique[item.itemCode] = item;
          }
        }
        final list = unique.values.toList();
        _searchCache[cleanQuery] = list;
        return list;
      }
    } catch (e) {
      print('Error searching products: $e');
    }
    return [];
  }

  static Future<ComparisonResult?> compareItem(String itemCode, {String? city}) async {
    final cleanCode = itemCode.trim();
    if (_compareCache.containsKey(cleanCode) && city == null) {
      return _compareCache[cleanCode];
    }

    String url = '$baseUrl/compare?item_code=${Uri.encodeComponent(cleanCode)}';
    if (city != null && city.isNotEmpty) {
      url += '&city=${Uri.encodeComponent(city.trim())}';
    }

    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final result = ComparisonResult.fromJson(data);
        if (result.found && city == null) {
          _compareCache[cleanCode] = result;
        }
        return result;
      }
    } catch (e) {
      print('Error comparing item: $e');
    }
    return null;
  }
}
