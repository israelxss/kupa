import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../services/basket_provider.dart';
import '../services/store_settings_provider.dart';
import '../services/api_service.dart';
import '../widgets/chain_badge.dart';

class BasketScreen extends StatefulWidget {
  const BasketScreen({Key? key}) : super(key: key);

  @override
  State<BasketScreen> createState() => _BasketScreenState();
}

class _BasketScreenState extends State<BasketScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  // Data structure for comparison results:
  // Key: barcode -> Map of store name -> price
  Map<String, Map<String, dynamic>> _itemPriceByChain = {};
  
  // Manual overrides for drag & drop:
  // Key: barcode -> assigned chain name
  final Map<String, String> _manualChainOverride = {};

  // Ranked single chains for the "All in one store" tab
  List<Map<String, dynamic>> _rankedSingleChains = [];

  // Cached item count to trigger auto-fetch when basket changes
  int _lastBasketItemCount = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBasketPrices();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBasketPrices() async {
    final basket = context.read<BasketProvider>();
    final settings = context.read<StoreSettingsProvider>();
    if (basket.items.isEmpty) {
      setState(() {
        _itemPriceByChain.clear();
        _rankedSingleChains.clear();
      });
      return;
    }

    setState(() => _isLoading = true);

    final barcodes = basket.items.map((i) => i.barcode).join(',');
    final url = '${ApiService.baseUrl}/compare?item_code=${Uri.encodeComponent(barcodes)}';

    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final itemsData = (data['items'] as List<dynamic>?) ?? [];

        final Map<String, Map<String, dynamic>> priceMap = {};

        for (var itm in itemsData) {
          final code = (itm['item_code'] ?? '').toString();
          final chains = (itm['chains'] as List<dynamic>? ?? []);
          priceMap[code] = {};

          for (var ch in chains) {
            final chainName = (ch['chain_name'] ?? ch['chain'] ?? '').toString();
            final minPrice = (ch['min_price'] as num?)?.toDouble() ?? 0.0;
            final branchName = ch['cheapest_store'] != null ? ch['cheapest_store']['store_name'] ?? '' : '';
            priceMap[code]![chainName] = {
              'unit_price': minPrice,
              'branch': branchName,
            };
          }
        }

        // Calculate single chain totals
        final Map<String, Map<String, dynamic>> singleChainTotals = {};
        for (var item in basket.items) {
          final code = item.barcode;
          final chainPrices = priceMap[code] ?? {};

          for (var entry in chainPrices.entries) {
            final chain = entry.key;
            if (!settings.myChains.contains(chain)) continue;

            final unitPrice = (entry.value['unit_price'] as double);
            final totalItemPrice = unitPrice * item.quantity;

            if (!singleChainTotals.containsKey(chain)) {
              singleChainTotals[chain] = {
                'name': chain,
                'min_total': 0.0,
                'items_count': 0,
                'breakdown': <Map<String, dynamic>>[],
                'missing': <String>[],
              };
            }
            singleChainTotals[chain]!['min_total'] += totalItemPrice;
            singleChainTotals[chain]!['items_count'] += 1;
            (singleChainTotals[chain]!['breakdown'] as List<Map<String, dynamic>>).add({
              'name': item.name,
              'barcode': code,
              'qty': item.quantity,
              'unit_price': unitPrice,
              'total_price': totalItemPrice,
            });
          }
        }

        for (var t in singleChainTotals.values) {
          final foundCodes = (t['breakdown'] as List<Map<String, dynamic>>).map((b) => b['barcode']).toSet();
          t['missing'] = basket.items.where((i) => !foundCodes.contains(i.barcode)).map((i) => i.name).toList();
        }

        final rankedList = singleChainTotals.values.toList();
        rankedList.sort((a, b) {
          int countCmp = (b['items_count'] as int).compareTo(a['items_count'] as int);
          if (countCmp != 0) return countCmp;
          return (a['min_total'] as double).compareTo(b['min_total'] as double);
        });

        setState(() {
          _itemPriceByChain = priceMap;
          _rankedSingleChains = rankedList;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Error fetching basket prices: $e');
    }

    setState(() => _isLoading = false);
  }

  // Determine best recommended store for an item among user's active chains
  String? _getRecommendedStore(String barcode, List<String> myChains) {
    final prices = _itemPriceByChain[barcode];
    if (prices == null || prices.isEmpty) return null;

    String? bestChain;
    double minPrice = double.infinity;

    for (var chain in myChains) {
      if (prices.containsKey(chain)) {
        final p = (prices[chain]['unit_price'] as num?)?.toDouble() ?? double.infinity;
        if (p < minPrice) {
          minPrice = p;
          bestChain = chain;
        }
      }
    }
    return bestChain;
  }

  void _showQuantityDialog(BuildContext context, BasketItem item) {
    final ctrl = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('עדכון כמות עבור ${item.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'כמות יחידות',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim()) ?? item.quantity;
              context.read<BasketProvider>().setQuantity(item.barcode, val);
              Navigator.pop(ctx);
              _fetchBasketPrices();
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basket = context.watch<BasketProvider>();
    final settings = context.watch<StoreSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Trigger auto-fetch if basket count changed
    if (basket.items.length != _lastBasketItemCount) {
      _lastBasketItemCount = basket.items.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchBasketPrices();
      });
    }

    if (basket.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('סל הקניות שלי 🧺'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_basket_outlined, size: 76, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'הסל שלך ריק כרגע.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'סרוק ברקודים או חפש מוצרים כדי לגלות איך הכי כדאי לחלק את הקניות שלך בצורה חכמה!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('סל הקניות שלי 🧺'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'חלונות חנויות (גרירה) 🔀'),
              Tab(icon: Icon(Icons.store), text: 'הכל ברשת אחת 🏬'),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh),
            tooltip: 'רענן מחירים',
            onPressed: _isLoading ? null : () => _fetchBasketPrices(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'רוקן סל',
            onPressed: () {
              basket.clear();
              setState(() {
                _itemPriceByChain.clear();
                _manualChainOverride.clear();
                _rankedSingleChains.clear();
              });
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDragAndDropWindowsTab(basket, settings, isDark),
          _buildSingleChainTab(isDark),
        ],
      ),
    );
  }

  // TAB 1: Split Store Windows with Drag & Drop
  Widget _buildDragAndDropWindowsTab(BasketProvider basket, StoreSettingsProvider settings, bool isDark) {
    // 1. Group items into store buckets based on manual overrides or auto-recommended store
    final Map<String, List<BasketItem>> storeBuckets = {};
    final List<BasketItem> unassignedItems = [];

    // Ensure all user active chains exist as buckets
    for (var chain in settings.myChains) {
      storeBuckets[chain] = [];
    }

    for (var item in basket.items) {
      String? assignedChain = _manualChainOverride[item.barcode];
      if (assignedChain == null || !settings.myChains.contains(assignedChain)) {
        assignedChain = _getRecommendedStore(item.barcode, settings.myChains);
      }

      if (assignedChain != null && storeBuckets.containsKey(assignedChain)) {
        storeBuckets[assignedChain]!.add(item);
      } else {
        unassignedItems.add(item);
      }
    }

    // 2. Compute grand total across all assigned items
    double grandTotal = 0.0;
    int totalAssignedItems = 0;

    for (var entry in storeBuckets.entries) {
      final chain = entry.key;
      for (var itm in entry.value) {
        final p = _itemPriceByChain[itm.barcode]?[chain]?['unit_price'] as double? ?? 0.0;
        grandTotal += (p * itm.quantity);
        totalAssignedItems += itm.quantity;
      }
    }

    return Column(
      children: [
        // Top Total & Tip Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
            border: Border(bottom: BorderSide(color: Colors.green.withOpacity(0.3))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calculate, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'סה"כ לסל: ₪${grandTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'בסל $totalAssignedItems יחידות • מחושב אוטומטית לפי הרשתות שלך',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app, size: 14, color: Colors.blueAccent),
                    SizedBox(width: 4),
                    Text('גרור מוצר להחלפה', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Unassigned / Missing items banner if any
        if (unassignedItems.isNotEmpty)
          Container(
            color: Colors.amber.shade900.withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${unassignedItems.length} מוצרים לא נמצאו באף אחת מהרשתות שבחרת',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        // Store Windows List - Sorted so stores with items appear first, empty stores at the bottom
        Expanded(
          child: Builder(
            builder: (context) {
              final sortedChains = List<String>.from(settings.myChains);
              sortedChains.sort((a, b) {
                final countA = storeBuckets[a]?.length ?? 0;
                final countB = storeBuckets[b]?.length ?? 0;
                if (countA > 0 && countB == 0) return -1;
                if (countA == 0 && countB > 0) return 1;
                // If both have items, sort by descending count, then subtotal
                if (countA > 0 && countB > 0) {
                  return countB.compareTo(countA);
                }
                return a.compareTo(b);
              });

              final hasEmptyStores = sortedChains.any((c) => (storeBuckets[c]?.length ?? 0) == 0);
              final hasActiveStores = sortedChains.any((c) => (storeBuckets[c]?.length ?? 0) > 0);

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sortedChains.length,
                itemBuilder: (context, index) {
                  final chainName = sortedChains[index];
                  final chainItems = storeBuckets[chainName] ?? [];
                  final isFirstEmpty = chainItems.isEmpty &&
                      index > 0 &&
                      (storeBuckets[sortedChains[index - 1]]?.isNotEmpty ?? false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFirstEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 8, right: 4),
                          child: Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                              SizedBox(width: 6),
                              Text(
                                'רשתות נוספות שלך (ללא מוצרים מוקצים - ניתן לגרור לכאן):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _buildStoreWindowCard(
                        chainName: chainName,
                        items: chainItems,
                        basket: basket,
                        settings: settings,
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // A distinct Store Window Card that functions as a DragTarget
  Widget _buildStoreWindowCard({
    required String chainName,
    required List<BasketItem> items,
    required BasketProvider basket,
    required StoreSettingsProvider settings,
    required bool isDark,
  }) {
    // Calculate subtotal for this chain
    double chainSubtotal = 0.0;
    for (var itm in items) {
      final p = _itemPriceByChain[itm.barcode]?[chainName]?['unit_price'] as double? ?? 0.0;
      chainSubtotal += (p * itm.quantity);
    }

    return DragTarget<BasketItem>(
      onWillAccept: (incomingItem) {
        // Can accept if the dragged item isn't already assigned to this store
        return incomingItem != null;
      },
      onAccept: (incomingItem) {
        HapticFeedback.mediumImpact();
        setState(() {
          _manualChainOverride[incomingItem.barcode] = chainName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${incomingItem.name} הועבר בהצלחה ל-$chainName 🛒'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isHovered
                ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFDBEAFE))
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered
                  ? Colors.blueAccent
                  : (items.isNotEmpty ? Colors.transparent : Colors.grey.withOpacity(0.2)),
              width: isHovered ? 2.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovered ? Colors.blueAccent.withOpacity(0.3) : Colors.black.withOpacity(0.06),
                blurRadius: isHovered ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ChainBadge(chainName: chainName, size: 36),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chainName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              items.isEmpty ? 'אין מוצרים מוקצים לרשת זו' : '${items.length} מוצרים מומלצים',
                              style: TextStyle(fontSize: 11, color: items.isEmpty ? Colors.grey : Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '₪${chainSubtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      )
                    else
                      Text(
                        'גרור מוצר לכאן',
                        style: TextStyle(
                          fontSize: 12,
                          color: isHovered ? Colors.blueAccent : Colors.grey.shade400,
                          fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                  ],
                ),
              ),

              // Items Inside this Store
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drive_file_move_outlined, size: 16, color: isHovered ? Colors.blueAccent : Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          isHovered ? 'שחרר כאן כדי להעביר לרשת זו!' : 'גרור פריט לכאן כדי להעביר לרשת זו',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                            color: isHovered ? Colors.blueAccent : (isDark ? Colors.white38 : Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(10),
                  itemCount: items.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _buildDraggableProductItem(
                      item: item,
                      chainName: chainName,
                      basket: basket,
                      settings: settings,
                      isDark: isDark,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Draggable Product Item inside a store card
  Widget _buildDraggableProductItem({
    required BasketItem item,
    required String chainName,
    required BasketProvider basket,
    required StoreSettingsProvider settings,
    required bool isDark,
  }) {
    final prices = _itemPriceByChain[item.barcode];
    final chainPriceData = prices?[chainName];
    final double unitPrice = (chainPriceData?['unit_price'] as num?)?.toDouble() ?? 0.0;
    final double totalPrice = unitPrice * item.quantity;
    final bool isOverridden = _manualChainOverride.containsKey(item.barcode);

    // Check if there is an optimal recommended store that is cheaper than the current assigned store
    final recommendedChain = _getRecommendedStore(item.barcode, settings.myChains);
    final hasBetterStore = recommendedChain != null &&
        recommendedChain != chainName &&
        prices != null &&
        prices.containsKey(recommendedChain) &&
        (prices[recommendedChain]['unit_price'] as double? ?? double.infinity) <
            (unitPrice > 0 ? unitPrice : double.infinity);

    final double recommendedUnitPrice = hasBetterStore
        ? (prices[recommendedChain]['unit_price'] as double? ?? 0.0)
        : 0.0;
    final double priceDiffPerUnit = (unitPrice > 0 && hasBetterStore) ? unitPrice - recommendedUnitPrice : 0.0;

    final itemWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasBetterStore
              ? Colors.orange.withOpacity(0.5)
              : (isOverridden ? Colors.blueAccent.withOpacity(0.5) : Colors.transparent),
          width: hasBetterStore || isOverridden ? 1.2 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Drag Indicator Grip Handle
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.drag_indicator, size: 20, color: Colors.grey),
              ),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOverridden)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('הועבר ידנית', style: TextStyle(fontSize: 9, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          unitPrice > 0 ? '₪${unitPrice.toStringAsFixed(2)} ליח\'' : 'מחיר לא זמין',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade600),
                        ),
                        if (item.quantity > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• סה"כ: ₪${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Quantity controls
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: () => basket.updateQuantity(item.barcode, -1),
              ),
              InkWell(
                onTap: () => _showQuantityDialog(context, item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade400, width: 0.8),
                  ),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                onPressed: () => basket.updateQuantity(item.barcode, 1),
              ),
            ],
          ),

          // Notification bar if there's a cheaper / better store or if overridden
          if (hasBetterStore || isOverridden) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: hasBetterStore
                    ? (isDark ? Colors.orange.withOpacity(0.15) : const Color(0xFFFFFBEB))
                    : (isDark ? Colors.blue.withOpacity(0.15) : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasBetterStore ? Colors.orange.withOpacity(0.4) : Colors.blue.withOpacity(0.3),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasBetterStore ? Icons.savings_outlined : Icons.info_outline,
                    size: 15,
                    color: hasBetterStore ? Colors.orange.shade700 : Colors.blueAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasBetterStore
                          ? 'זול יותר ב-$recommendedChain (₪${recommendedUnitPrice.toStringAsFixed(2)}, חסוך ₪${(priceDiffPerUnit * item.quantity).toStringAsFixed(2)})'
                          : 'הועבר ידנית מ-${recommendedChain ?? "חנות אחרת"}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: hasBetterStore
                            ? (isDark ? Colors.orange.shade300 : Colors.orange.shade900)
                            : (isDark ? Colors.blue.shade300 : Colors.blue.shade900),
                      ),
                    ),
                  ),
                  // One-click restore button!
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _manualChainOverride.remove(item.barcode);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.name} הוחזר אוטומטית לרשת המשתלמת ביותר! 🎯'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasBetterStore ? Colors.orange.shade800 : Colors.blueAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.undo, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text('החזר', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return LongPressDraggable<BasketItem>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.blueAccent, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.open_with, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${item.quantity} יח\'',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: itemWidget,
      ),
      child: itemWidget,
    );
  }

  // TAB 2: Ranked single chains (buy entire basket in one place)
  Widget _buildSingleChainTab(bool isDark) {
    if (_rankedSingleChains.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              const Icon(Icons.store_mall_directory_outlined, size: 60, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('לחץ על "רענן" להצגת השוואת סל מלא ברשת אחת', style: TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rankedSingleChains.length,
      itemBuilder: (context, index) {
        final r = _rankedSingleChains[index];
        final isWinner = index == 0;
        final missingList = (r['missing'] as List<dynamic>? ?? []);

        return Card(
          color: isWinner
              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isWinner ? const Color(0xFF10B981) : Colors.transparent,
              width: isWinner ? 2 : 0,
            ),
          ),
          child: ExpansionTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isWinner ? '🥇' : '#${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isWinner ? const Color(0xFF10B981) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                ChainBadge(chainName: r['name'], size: 34),
              ],
            ),
            title: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: missingList.isEmpty
                ? const Text('כל המוצרים זמינים בסל ✅', style: TextStyle(color: Colors.green, fontSize: 12))
                : Text('חסרים ${missingList.length} מוצרים ברשת זו', style: const TextStyle(color: Colors.orange, fontSize: 12)),
            trailing: Text(
              '₪${(r['min_total'] as double).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isWinner ? const Color(0xFF10B981) : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('פירוט עלויות בסל לפי כמויות:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    ...((r['breakdown'] as List<Map<String, dynamic>>).map((b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${b['qty']}x ${b['name']}', style: const TextStyle(fontSize: 13))),
                          Text('₪${(b['total_price'] as double).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ))),
                    if (missingList.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('מוצרים שלא נמצאו במלאי: ${missingList.join(", ")}',
                          style: const TextStyle(color: Colors.orange, fontSize: 11)),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
