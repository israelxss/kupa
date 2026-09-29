class ProductItem {
  final String itemCode;
  final String itemName;
  final String manufacturer;
  final String unitOfMeasure;

  ProductItem({
    required this.itemCode,
    required this.itemName,
    required this.manufacturer,
    required this.unitOfMeasure,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      itemCode: (json['item_code'] ?? json['item_code_bare'] ?? '').toString(),
      itemName: (json['item_name'] ?? 'ללא שם').toString(),
      manufacturer: (json['manufacturer_name'] ?? '').toString(),
      unitOfMeasure: (json['unit_of_measure'] ?? '').toString(),
    );
  }
}

class ChainPrice {
  final String chain;
  final String chainName;
  final int storesCount;
  final double minPrice;
  final double medianPrice;
  final double maxPrice;
  final String cheapestStoreName;
  final String asOfDate;

  ChainPrice({
    required this.chain,
    required this.chainName,
    required this.storesCount,
    required this.minPrice,
    required this.medianPrice,
    required this.maxPrice,
    required this.cheapestStoreName,
    required this.asOfDate,
  });

  factory ChainPrice.fromJson(Map<String, dynamic> json) {
    final cheapest = json['cheapest_store'] as Map<String, dynamic>?;
    return ChainPrice(
      chain: (json['chain'] ?? '').toString(),
      chainName: (json['chain_name'] ?? json['chain'] ?? 'רשת לא ידועה').toString(),
      storesCount: (json['stores'] ?? 0) is int ? json['stores'] : int.tryParse(json['stores']?.toString() ?? '0') ?? 0,
      minPrice: (json['min_price'] as num?)?.toDouble() ?? 0.0,
      medianPrice: (json['median_price'] as num?)?.toDouble() ?? 0.0,
      maxPrice: (json['max_price'] as num?)?.toDouble() ?? 0.0,
      cheapestStoreName: cheapest != null ? (cheapest['store_name'] ?? '').toString() : '',
      asOfDate: (json['as_of'] ?? '').toString(),
    );
  }
}

class ComparisonResult {
  final bool found;
  final String itemCode;
  final String itemName;
  final List<ChainPrice> chains;

  ComparisonResult({
    required this.found,
    required this.itemCode,
    required this.itemName,
    required this.chains,
  });

  factory ComparisonResult.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) {
      return ComparisonResult(
        found: false,
        itemCode: '',
        itemName: '',
        chains: [],
      );
    }
    final first = items[0] as Map<String, dynamic>;
    final chainsList = (first['chains'] as List<dynamic>?)
            ?.map((c) => ChainPrice.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    chainsList.sort((a, b) => a.minPrice.compareTo(b.minPrice));

    return ComparisonResult(
      found: true,
      itemCode: (first['item_code'] ?? '').toString(),
      itemName: (first['item_name'] ?? '').toString(),
      chains: chainsList,
    );
  }
}
