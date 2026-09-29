import 'package:flutter/material.dart';

class ChainBadge extends StatelessWidget {
  final String chainName;
  final double size;

  const ChainBadge({Key? key, required this.chainName, this.size = 38}) : super(key: key);

  static const Map<String, _ChainVisual> _visuals = {
    'רמי לוי': _ChainVisual('רמי', Color(0xFFE11D48), Colors.white),
    'שופרסל': _ChainVisual('שופ', Color(0xFFDC2626), Colors.white),
    'אושר עד': _ChainVisual('אושר', Color(0xFF1D4ED8), Colors.white),
    'יוחננוף': _ChainVisual('יוחנ', Color(0xFFB45309), Colors.white),
    'קרפור': _ChainVisual('CRF', Color(0xFF0284C7), Colors.white),
    'ויקטורי': _ChainVisual('VICT', Color(0xFF059669), Colors.white),
    'מחסני השוק': _ChainVisual('שוק', Color(0xFFD97706), Colors.white),
    'טיב טעם': _ChainVisual('טיב', Color(0xFF7C3AED), Colors.white),
    'קשת טעמים': _ChainVisual('קשת', Color(0xFF9333EA), Colors.white),
    'חצי חינם': _ChainVisual('חצי', Color(0xFFEAB308), Colors.black87),
    'סופר פארם': _ChainVisual('פארם', Color(0xFF2563EB), Colors.white),
    'קינג סטור': _ChainVisual('KING', Color(0xFFB91C1C), Colors.white),
    'זול ובגדול': _ChainVisual('זול', Color(0xFF16A34A), Colors.white),
    'מעיין 2000': _ChainVisual('2000', Color(0xFF0D9488), Colors.white),
    'סופר ברקת': _ChainVisual('ברקת', Color(0xFF0284C7), Colors.white),
    'סטופ מרקט': _ChainVisual('STOP', Color(0xFFEF4444), Colors.white),
    'פרש מרקט': _ChainVisual('פרש', Color(0xFF15803D), Colors.white),
    'דבאח': _ChainVisual('דבאח', Color(0xFF475569), Colors.white),
    'וולט מרקט': _ChainVisual('WOLT', Color(0xFF00C2E8), Colors.white),
    'משנת יוסף': _ChainVisual('יוסף', Color(0xFF4338CA), Colors.white),
    'נתיב החסד': _ChainVisual('חסד', Color(0xFF1E3A8A), Colors.white),
    'סיטי מרקט': _ChainVisual('סיטי', Color(0xFFEA580C), Colors.white),
    'גוד פארם': _ChainVisual('GOOD', Color(0xFF10B981), Colors.white),
    'סופר ספיר': _ChainVisual('ספיר', Color(0xFF4F46E5), Colors.white),
    'שוק העיר': _ChainVisual('העיר', Color(0xFFCA8A04), Colors.white),
    'שפע ברכת השם': _ChainVisual('שפע', Color(0xFF1E40AF), Colors.white),
  };

  static const Map<String, String> _chainDomains = {
    'שופרסל': 'shufersal.co.il',
    'רמי לוי': 'rami-levy.co.il',
    'אושר עד': 'osherad.co.il',
    'קרפור': 'carrefour.co.il',
    'יוחננוף': 'yochananof.co.il',
    'חצי חינם': 'hazi-hinam.co.il',
    'ויקטורי': 'victory.co.il',
    'טיב טעם': 'tivtaam.co.il',
    'סופר פארם': 'super-pharm.co.il',
    'וולט מרקט': 'wolt.com',
    'מחסני השוק': 'mck.co.il',
    'קשת טעמים': 'keshet-teamim.co.il',
    'סטופ מרקט': 'stopmarket.co.il',
    'פרש מרקט': 'freshmarket.co.il',
    'גוד פארם': 'goodpharm.co.il',
  };

  @override
  Widget build(BuildContext context) {
    // Find matching chain visual or build a default one
    _ChainVisual visual = _visuals[chainName] ??
        _ChainVisual(
          chainName.length > 3 ? chainName.substring(0, 3) : chainName,
          const Color(0xFF3B82F6),
          Colors.white,
        );

    String? domain = _chainDomains[chainName];

    // Search substring match if not exact
    if (!_visuals.containsKey(chainName)) {
      for (var entry in _visuals.entries) {
        if (chainName.contains(entry.key)) {
          visual = entry.value;
          domain ??= _chainDomains[entry.key];
          break;
        }
      }
    }

    final fallbackWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visual.bgColor,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: visual.bgColor.withOpacity(0.35),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Center(
        child: Text(
          visual.label,
          style: TextStyle(
            color: visual.textColor,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.32,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );

    if (domain == null) {
      return fallbackWidget;
    }

    final logoUrl = 'https://www.google.com/s2/favicons?domain=$domain&sz=128';

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: Colors.grey.shade300, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => fallbackWidget,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallbackWidget;
          },
        ),
      ),
    );
  }
}

class _ChainVisual {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _ChainVisual(this.label, this.bgColor, this.textColor);
}
