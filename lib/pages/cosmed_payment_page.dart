import 'package:flutter/material.dart';
import '../api_services.dart';
import 'barcode_scanner_page.dart';
class CosmedPaymentPage extends StatefulWidget {
  const CosmedPaymentPage({super.key});
  @override
  State<CosmedPaymentPage> createState() => _CosmedPaymentPageState();
}
class _CosmedPaymentPageState extends State<CosmedPaymentPage> {
  final _totalAmountController = TextEditingController();
  final _barCodeController = TextEditingController();
  String _result = '執行結果將顯示於此';
  bool _isLoading = false;
  final _apiService = CosmedApiService();
  Future<void> _scanBarcode() async {
    final scannedBarcode = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (context) => const BarcodeScannerPage()));
    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      setState(() { _barCodeController.text = scannedBarcode; });
    }
  }
  @override
  void dispose() {
    _totalAmountController.dispose();
    _barCodeController.dispose();
    super.dispose();
  }
  Future<void> _handleCosmedPayment() async {
    if (_totalAmountController.text.isEmpty || _barCodeController.text.isEmpty) {
      setState(() { _result = '錯誤：所有欄位皆為必填。'; });
      return;
    }
    setState(() { _isLoading = true; _result = '處理中...'; });
    try {
      final response = await _apiService.performDeduction(
        totalAmount: _totalAmountController.text.trim(),
        barCode: _barCodeController.text.trim(),
      );
      setState(() { _result = response; });
    } catch (e) {
      setState(() { _result = "發生未預期的錯誤：\n$e"; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('康是美實體門市扣款')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(controller: _totalAmountController, decoration: const InputDecoration(labelText: '總金額 (TotalAmount)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(controller: _barCodeController, decoration: InputDecoration(labelText: '付款條碼 (BarCode)', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.camera_alt), onPressed: _scanBarcode, tooltip: '掃描條碼'))),
              const SizedBox(height: 24),
              _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _handleCosmedPayment, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('執行扣款')),
              const SizedBox(height: 24),
              const Text('執行結果:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: SelectableText(_result)),
            ],
          ),
        ),
      ),
    );
  }
}
