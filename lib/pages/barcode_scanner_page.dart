import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});
  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}
class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanCompleted = false;
  void _closeScreen() {
    if (mounted) { Navigator.pop(context); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描條碼'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _closeScreen),
      ),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          if (_isScanCompleted) return;
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final String? scannedCode = barcodes.first.rawValue;
            if (scannedCode != null && (scannedCode.startsWith('88') || scannedCode.startsWith('IC'))) {
              setState(() { _isScanCompleted = true; });
              Navigator.pop(context, scannedCode);
            }
          }
        },
      ),
    );
  }
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}



