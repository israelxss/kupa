import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/basket_provider.dart';
import '../services/store_settings_provider.dart';
import '../widgets/chain_badge.dart';

class ProductDetailScreen extends StatefulWidget {
  final String barcode;
  final String? initialName;

  const ProductDetailScreen({Key? key, required this.barcode, this.initialName}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<ComparisonResult?> _futureComparison;
  int _quantityToAdd = 1;

  @override
  void initState() {
    super.initState();
    _futureComparison = ApiService.compareItem(widget.barcode);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StoreSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('תוצאות השוואה ראש-בראש'),
        centerTitle: true,
      ),
      body: FutureBuilder<ComparisonResult?>(
        future: _futureComparison,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('סורק מחירים ב-33 רשתות שיווק...', style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final result = snapshot.data;
          if (result == null || !result.found || result.chains.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('לא נמצאו נתוני מחיר עבור ברקוד: ${widget.barcode}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('ייתכן שמדובר במוצר שאינו נמכר ברשתות המזון או בברקוד פנימי.'),
                  ],
                ),
              ),
            );
          }

          // Filter by user's preferred stores if set
          final allChains = result.chains;
          final chains = settings.myChains.isEmpty
              ? allChains
              : allChains.where((c) => settings.myChains.contains(c.chainName) || settings.myChains.contains(c.chain)).toList();

          if (chains.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.amber),
                    const SizedBox(height: 16),
                    const Text('המוצר קיים ברשתות אחרות, אך לא ברשתות שבחרת לסנן.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => settings.clearFilter(),
                      child: const Text('הצג את כל הרשתות'),
                    )
                  ],
                ),
              ),
            );
          }

          final cheapest = chains.first;
          final mostExpensive = chains.last;
          final diff = mostExpensive.minPrice - cheapest.minPrice;
          final diffPercent = cheapest.minPrice > 0 ? (diff / cheapest.minPrice) * 100 : 0;

          return Column(
            children: [
              // Header Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A8A), const Color(0xFF1E293B)]
                        : [Colors.blue.shade800, Colors.blue.shade600],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.itemName.isNotEmpty ? result.itemName : (widget.initialName ?? 'מוצר ללא שם'),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ברקוד: ${widget.barcode}',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                    ),
                    const Divider(color: Colors.white24, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('הכי זול 🏆', '₪${cheapest.minPrice.toStringAsFixed(2)}', Colors.greenAccent),
                        _buildStat('הכי יקר', '₪${mostExpensive.minPrice.toStringAsFixed(2)}', Colors.orangeAccent),
                        _buildStat('פער למוצר', '${diffPercent.toStringAsFixed(0)}%', Colors.yellowAccent),
                      ],
                    ),
                  ],
                ),
              ),

              // Button to add to basket with quantity
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () {
                              if (_quantityToAdd > 1) setState(() => _quantityToAdd--);
                            },
                          ),
                          Text('$_quantityToAdd', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () => setState(() => _quantityToAdd++),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text('הוסף לסל ($_quantityToAdd יח\') ➕', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          context.read<BasketProvider>().addItem(widget.barcode, result.itemName, qty: _quantityToAdd);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('נוספו $_quantityToAdd יח\' מ-"${result.itemName}" לסל!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('השוואת רשתות (${chains.length}):',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (settings.myChains.isNotEmpty)
                      const Text('(מסונן לפי הרשתות שלי)', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                  ],
                ),
              ),

              // List of Chains
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: chains.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final ch = chains[index];
                    final isFirst = index == 0;

                    return Card(
                      elevation: isFirst ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isFirst ? Colors.greenAccent : (isDark ? Colors.white12 : Colors.grey.shade200),
                          width: isFirst ? 2 : 1,
                        ),
                      ),
                      color: isFirst
                          ? (isDark ? const Color(0xFF064E3B) : Colors.green.shade50)
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              alignment: Alignment.center,
                              child: Text(
                                '#${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isFirst ? const Color(0xFF10B981) : Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            ChainBadge(chainName: ch.chainName, size: 36),
                          ],
                        ),
                        title: Text(ch.chainName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: ch.cheapestStoreName.isNotEmpty
                            ? Text('סניף זול: ${ch.cheapestStoreName} (${ch.storesCount} סניפים)',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54))
                            : Text('${ch.storesCount} סניפים פעילים',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₪${ch.minPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isFirst
                                    ? (isDark ? Colors.greenAccent : Colors.green.shade800)
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            if (ch.maxPrice > ch.minPrice)
                              Text(
                                'עד ₪${ch.maxPrice.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
