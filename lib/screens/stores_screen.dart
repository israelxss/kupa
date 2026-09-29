import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store_settings_provider.dart';
import '../widgets/chain_badge.dart';

class StoresScreen extends StatelessWidget {
  const StoresScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StoreSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('הסופרים והרשתות שלי 🏬'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: settings.isAllSelected ? 'בטל בחירת הכל' : 'בחר את כל הרשתות',
            icon: Icon(
              settings.isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
              color: const Color(0xFF10B981),
            ),
            onPressed: () => settings.toggleSelectAll(),
          ),
          if (settings.myChains.isNotEmpty)
            TextButton(
              onPressed: () => settings.clearFilter(),
              child: const Text('נקה', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    settings.myChains.isEmpty
                        ? 'כרגע כל הרשתות נכללות בהשוואה (33 רשתות). בחר את הרשתות שבהן אתה בדרך כלל קונה כדי לראות השוואה מותאמת אישית עבורך.'
                        : 'מסנן השוואה לפי ${settings.myChains.length} רשתות שבחרת. רק רשתות אלו יופיעו בתוצאות ובסל.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: StoreSettingsProvider.allChains.length,
              itemBuilder: (context, index) {
                final chain = StoreSettingsProvider.allChains[index];
                final chainName = chain['name']!;
                final isSelected = settings.myChains.contains(chainName);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.blueAccent : Colors.transparent,
                      width: isSelected ? 1.5 : 0,
                    ),
                  ),
                  child: CheckboxListTile(
                    activeColor: const Color(0xFF10B981),
                    secondary: ChainBadge(chainName: chainName, size: 36),
                    title: Text(chainName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: const Text('רשת ארצית', style: TextStyle(fontSize: 12)),
                    value: isSelected,
                    onChanged: (_) => settings.toggleChain(chainName),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
