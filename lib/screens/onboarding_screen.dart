import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/store_settings_provider.dart';
import '../widgets/kupa_logo.dart';
import '../widgets/chain_badge.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StoreSettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canContinue = settings.myChains.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const KupaLogo(size: 72),
            const SizedBox(height: 16),
            const Text(
              'ברוכים הבאים ל"קופה" 🛒',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'בחר את הרשתות שבהן אתה בדרך כלל קונה או עובר בהן.\nכך נדע להציג לך רק מחירים רלוונטיים ולחלק את הסל שלך בצורה המשתלמת ביותר!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'נבחרו: ${settings.myChains.length} מתוך ${StoreSettingsProvider.allChains.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(
                          settings.isAllSelected ? Icons.deselect : Icons.select_all,
                          size: 18,
                          color: const Color(0xFF10B981),
                        ),
                        label: Text(
                          settings.isAllSelected ? 'בטל הכל' : 'בחר הכל',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 13),
                        ),
                        onPressed: () => settings.toggleSelectAll(),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.flash_on, size: 16),
                        label: const Text('מובילות', style: TextStyle(fontSize: 13)),
                        onPressed: () => settings.selectAllPopularChains(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Chains list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: StoreSettingsProvider.allChains.length,
                itemBuilder: (context, index) {
                  final chain = StoreSettingsProvider.allChains[index];
                  final chainName = chain['name']!;
                  final isSelected = settings.myChains.contains(chainName);

                  return Card(
                    elevation: isSelected ? 2 : 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF10B981) : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    color: isSelected
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    child: CheckboxListTile(
                      activeColor: const Color(0xFF10B981),
                      secondary: ChainBadge(chainName: chainName, size: 36),
                      title: Text(
                        chainName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSelected && !isDark ? const Color(0xFF065F46) : null,
                        ),
                      ),
                      subtitle: const Text('סניפים פעילים בפריסה ארצית', style: TextStyle(fontSize: 12)),
                      value: isSelected,
                      onChanged: (_) => settings.toggleChain(chainName),
                    ),
                  );
                },
              ),
            ),
            // Bottom Action
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  if (!canContinue)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        '⚠️ עליך לבחור לפחות רשת אחת כדי להמשיך',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canContinue ? const Color(0xFF10B981) : Colors.grey,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: canContinue ? 3 : 0,
                    ),
                    onPressed: canContinue ? () => settings.completeOnboarding() : null,
                    child: const Text(
                      'התחל להשוות ולסרוק מוצרים 🚀',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
