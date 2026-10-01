import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/basket_provider.dart';
import 'basket_qr_dialog.dart';

class BasketSelectorSheet extends StatelessWidget {
  final String? itemNameToAdd;
  final String? itemBarcodeToAdd;
  final int quantityToAdd;

  const BasketSelectorSheet({
    Key? key,
    this.itemNameToAdd,
    this.itemBarcodeToAdd,
    this.quantityToAdd = 1,
  }) : super(key: key);

  static Future<UserBasket?> show(
    BuildContext context, {
    String? itemNameToAdd,
    String? itemBarcodeToAdd,
    int quantityToAdd = 1,
  }) {
    return showModalBottomSheet<UserBasket>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BasketSelectorSheet(
        itemNameToAdd: itemNameToAdd,
        itemBarcodeToAdd: itemBarcodeToAdd,
        quantityToAdd: quantityToAdd,
      ),
    );
  }

  void _showCreateBasketDialog(BuildContext context) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('יצירת סל חדש 🧺'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'תן שם לסל שלך (לדוגמה: "קניות לשבת", "מוצרי ניקיון", "חג פסח"):',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'שם הסל...',
                prefixIcon: const Icon(Icons.edit_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final name = textCtrl.text.trim();
              if (name.isNotEmpty) {
                final basketProv = context.read<BasketProvider>();
                final created = basketProv.createBasket(name, makeActive: true);
                if (itemBarcodeToAdd != null && itemNameToAdd != null) {
                  basketProv.addItemToBasket(created.id, itemBarcodeToAdd!, itemNameToAdd!, qty: quantityToAdd);
                }
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context, created); // Close sheet & return
              }
            },
            child: const Text('צור סל ושמור'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, UserBasket basket) {
    final textCtrl = TextEditingController(text: basket.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('שינוי שם הסל ✏️'),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
          ElevatedButton(
            onPressed: () {
              final newName = textCtrl.text.trim();
              if (newName.isNotEmpty) {
                context.read<BasketProvider>().renameBasket(basket.id, newName);
                Navigator.pop(ctx);
              }
            },
            child: const Text('שמור'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateDialog(BuildContext context, UserBasket basket) {
    final textCtrl = TextEditingController(text: '${basket.name} (גרסה חדשה)');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('שמירת גרסת סל / שכפול 📑'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('שכפל את כל המוצרים והכמויות לסל חדש בשם נפרד:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
          ElevatedButton(
            onPressed: () {
              final newName = textCtrl.text.trim();
              if (newName.isNotEmpty) {
                context.read<BasketProvider>().duplicateBasket(basket.id, customName: newName);
                Navigator.pop(ctx);
              }
            },
            child: const Text('שכפל סל'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basketProv = context.watch<BasketProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allBaskets = basketProv.allBaskets;
    final isAddingItem = itemBarcodeToAdd != null && itemNameToAdd != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAddingItem ? 'בחר לאיזה סל להוסיף 🧺' : 'ניהול וגרסאות סלים 🧺',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (isAddingItem)
                    Text(
                      'מוסיף $quantityToAdd יח\' מ-"$itemNameToAdd"',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('סל חדש', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showCreateBasketDialog(context),
              ),
            ],
          ),
          const Divider(height: 24),

          // Baskets list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: allBaskets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final basket = allBaskets[index];
                final isActive = basket.id == basketProv.activeBasketId;

                return Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isActive ? const Color(0xFF10B981) : (isDark ? Colors.white12 : Colors.grey.shade300),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  color: isActive
                      ? (isDark ? const Color(0xFF064E3B).withOpacity(0.3) : const Color(0xFFECFDF5))
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: isActive ? const Color(0xFF10B981) : Colors.blueGrey.withOpacity(0.2),
                      foregroundColor: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      child: const Icon(Icons.shopping_basket_rounded, size: 20),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            basket.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isActive ? const Color(0xFF10B981) : null,
                            ),
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('פעיל', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${basket.items.length} מוצרים (${basket.totalCount} יח\')',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit & Version actions menu
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          tooltip: 'פעולות נוספות לסל',
                          onSelected: (val) {
                            if (val == 'share_qr') {
                              BasketQrDialog.show(context, basket);
                            } else if (val == 'rename') {
                              _showRenameDialog(context, basket);
                            } else if (val == 'duplicate') {
                              _showDuplicateDialog(context, basket);
                            } else if (val == 'delete') {
                              basketProv.deleteBasket(basket.id);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'share_qr',
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF10B981)),
                                  SizedBox(width: 8),
                                  Text('שתף סל ב-QR 📲'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                                  SizedBox(width: 8),
                                  Text('שנה שם סל'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 16, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('שמור כגרסה / שכפול'),
                                ],
                              ),
                            ),
                            if (allBaskets.length > 1)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Text('מחק סל זה'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () {
                      if (isAddingItem) {
                        basketProv.addItemToBasket(basket.id, itemBarcodeToAdd!, itemNameToAdd!, qty: quantityToAdd);
                        basketProv.switchBasket(basket.id);
                        Navigator.pop(context, basket);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('התווספו $quantityToAdd יח\' לסל "${basket.name}"! 🛒'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      } else {
                        basketProv.switchBasket(basket.id);
                        Navigator.pop(context, basket);
                      }
                    },
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
