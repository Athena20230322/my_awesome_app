import 'package:flutter/material.dart';
import '../api_services.dart';
import 'barcode_scanner_page.dart';
// 1. 類別名稱更新
class IcashWelfarePaymentPage extends StatefulWidget {
  const IcashWelfarePaymentPage({super.key});
  @override
  State<IcashWelfarePaymentPage> createState() => _IcashWelfarePaymentPageState();
}
class _IcashWelfarePaymentPageState extends State<IcashWelfarePaymentPage> {
  // 4. 根據 .js 範例，更新預設金額
  final _totalAmountController = TextEditingController(text: '400');
  final _barCodeController = TextEditingController();
  String _result = '執行結果將顯示於此';
  bool _isLoading = false;
  // 2. 使用新的 IcashWelfareApiService
  final _apiService = IcashWelfareApiService();
  Future<void> _scanBarcode() async {
    final scannedBarcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => const BarcodeScannerPage()));
    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      setState(() {
        _barCodeController.text = scannedBarcode;
      });
    }
  }
  @override
  void dispose() {
    _totalAmountController.dispose();
    _barCodeController.dispose();
    super.dispose();
  }
  // 3. 處理函式名稱更新
  Future<void> _handleIcashWelfarePayment() async {
    if (_totalAmountController.text.isEmpty ||
        _barCodeController.text.isEmpty) {
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
      // 這裡會自動呼叫 IcashWelfareApiService 的 performDeduction 方法
      final response = await _apiService.performDeduction(
        totalAmount: _totalAmountController.text.trim(),
        barCode: _barCodeController.text.trim(),
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
      // 3. AppBar 標題更新
      appBar: AppBar(title: const Text('愛金卡褔利社九九號店3DS扣款')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                  controller: _totalAmountController,
                  decoration: const InputDecoration(
                      labelText: '總金額 (TotalAmount)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(
                  controller: _barCodeController,
                  decoration: InputDecoration(
                      labelText: '付款條碼 (BarCode)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: _scanBarcode,
                          tooltip: '掃描條碼'))),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                // 3. 按鈕的處理函式更新
                  onPressed: _handleIcashWelfarePayment,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('執行扣款')),
              const SizedBox(height: 24),
              const Text('執行結果:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8)),
                  child: SelectableText(_result)),
            ],
          ),
        ),
      ),
    );
  }
}
