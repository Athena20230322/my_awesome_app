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
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掃描條碼/QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _closeScreen,
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              // 防止重複觸發
              if (_isScanCompleted) return;

              final List<Barcode> barcodes = capture.barcodes;

              if (barcodes.isNotEmpty) {
                final String? scannedCode = barcodes.first.rawValue;

                // --- 【***程式碼修正處***】 ---
                // 移除原有的前綴檢查，使其能接受任何內容的條碼/QR Code
                if (scannedCode != null && scannedCode.isNotEmpty) {
                  setState(() {
                    _isScanCompleted = true;
                  });
                  // 回傳掃描到的原始字串
                  Navigator.pop(context, scannedCode);
                }
              }
            },
          ),
          // 增加一個掃描框的 UI 提示，提升使用者體驗
          Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}