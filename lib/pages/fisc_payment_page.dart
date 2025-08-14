import 'package:flutter/material.dart';
import '../api_services.dart';
import 'barcode_scanner_page.dart';

class FiscPaymentPage extends StatefulWidget {
  const FiscPaymentPage({super.key});

  @override
  State<FiscPaymentPage> createState() => _FiscPaymentPageState();
}

class _FiscPaymentPageState extends State<FiscPaymentPage> {
  // 建立對應的 Controller
  final _buyerIdController = TextEditingController();
  final _txAmtController = TextEditingController(text: '200000900100'); // 預設金額

  String _result = '執行結果將顯示於此';
  bool _isLoading = false;
  // 建立新的 API Service 實例
  final _apiService = FiscApiService();

  // 掃碼功能
  Future<void> _scanBarcode() async {
    final scannedBarcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );
    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      setState(() {
        _buyerIdController.text = scannedBarcode;
      });
    }
  }

  @override
  void dispose() {
    _buyerIdController.dispose();
    _txAmtController.dispose();
    super.dispose();
  }

  // 執行付款的處理函式
  Future<void> _handleFiscPayment() async {
    if (_buyerIdController.text.isEmpty || _txAmtController.text.isEmpty) {
      setState(() {
        _result = '錯誤：所有欄位皆為必填。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '處理中...';
    });

    try {
      // 呼叫新的 API 方法
      final response = await _apiService.performQrPurchase(
        buyerId: _buyerIdController.text.trim(),
        txAmt: _txAmtController.text.trim(),
      );
      setState(() {
        _result = response;
      });
    } catch (e) {
      setState(() {
        _result = "發生未預期的錯誤：\n$e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FISC QR 掃碼付款')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ✨ 1. 在這裡新增說明文字
              const Text(
                '財經測試時間平日九點至下午五點',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24), // ✨ 2. 增加一些間距

              // 金額輸入框
              TextField(
                controller: _txAmtController,
                decoration: const InputDecoration(
                  labelText: '交易金額 (TxnAmount)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // 付款碼輸入框
              TextField(
                controller: _buyerIdController,
                decoration: InputDecoration(
                  labelText: '付款條碼 (BuyerID)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _scanBarcode,
                    tooltip: '掃描條碼',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 執行按鈕
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _handleFiscPayment,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('執行付款'),
              ),
              const SizedBox(height: 24),
              const Text('執行結果:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(_result),
              ),
            ],
          ),
        ),
      ),
    );
  }
}