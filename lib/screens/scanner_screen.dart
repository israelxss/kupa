import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/basket_provider.dart';
import '../widgets/basket_selector_sheet.dart';
import 'product_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;
  bool _torchOn = false;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        setState(() => _isProcessing = true);
        _controller.stop();

        // Check if scanned code is a Shared Basket QR code!
        if (code.startsWith('KUPA:BASKET:v1|')) {
          _handleImportSharedBasket(code);
          break;
        }

        // Standard grocery product barcode
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(barcode: code),
          ),
        ).then((_) {
          setState(() => _isProcessing = false);
          _controller.start();
        });
        break;
      }
    }
  }

  void _handleImportSharedBasket(String qrCode) {
    final parsed = UserBasket.fromQrPayload(qrCode);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('קוד QR אינו תקין או שאינו סל קניות'), backgroundColor: Colors.redAccent),
      );
      setState(() => _isProcessing = false);
      _controller.start();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 8),
            Text('ייבוא סל קניות משותף! 📥'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('זוהה סל משותף בשם: "${parsed.name}"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('מכיל ${parsed.items.length} מוצרים (${parsed.totalCount} יח\' בסה"כ).', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            const Text(
              'האם ברצונך לייבא את הסל לאפליקציה שלך ולהפוך אותו לסל הפעיל?',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isProcessing = false);
              _controller.start();
            },
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final imported = context.read<BasketProvider>().importBasketFromQr(qrCode, makeActive: true);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('הסל "${imported?.name ?? parsed.name}" יובא והוגדר כסל הפעיל שלך! 🧺'),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 3),
                ),
              );
              setState(() => _isProcessing = false);
              _controller.start();
            },
            child: const Text('ייבא סל עכשיו'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final basketProv = context.watch<BasketProvider>();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => BasketSelectorSheet.show(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_basket_rounded, size: 20, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    basketProv.currentBasketName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'ניהול סלים וגרסאות',
            icon: const Icon(Icons.folder_copy_outlined, color: Colors.blueAccent),
            onPressed: () => BasketSelectorSheet.show(context),
          ),
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: _torchOn ? Colors.amber : Colors.grey),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // כוונת סריקה מעוצבת
          Center(
            child: Container(
              width: 280,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'כוון אל ברקוד מוצר לבדיקת מחירים, או אל קוד QR לשיתוף סל קניות 📲',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
