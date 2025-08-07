import 'package:flutter/material.dart';
import '../api_services.dart';
import 'barcode_scanner_page.dart';
class TopUpPageUat extends StatefulWidget {
  const TopUpPageUat({super.key});
  @override
  State<TopUpPageUat> createState() => _TopUpPageUatState();
}
class _TopUpPageUatState extends State<TopUpPageUat> {
  final _topUpAmtController = TextEditingController();
  final _buyerIdController = TextEditingController();
  String _result = '執行結果將顯示於此';
  bool _isLoading = false;
  // 修改此處，呼叫 UAT 的 API 服務
  final _apiService = UatGeneralApiService();
  Future<void> _scanBarcode() async {
    final scannedBarcode = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (context) => const BarcodeScannerPage()));
    if (scannedBarcode != null && scannedBarcode.isNotEmpty) {
      setState(() { _buyerIdController.text = scannedBarcode; });
    }
  }
  @override
  void dispose() {
    _topUpAmtController.dispose();
    _buyerIdController.dispose();
    super.dispose();
  }
  Future<void> _handleTopUp() async {
    if (_topUpAmtController.text.isEmpty || _buyerIdController.text.isEmpty) {
      setState(() { _result = '錯誤：所有欄位皆為必填。'; });
      return;
    }
    setState(() { _isLoading = true; _result = '處理中...'; });
    try {
      final response = await _apiService.performTopUp(
        topUpAmt: _topUpAmtController.text.trim(),
        buyerId: _buyerIdController.text.trim(),
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
      // 修改標題以茲區別
      appBar: AppBar(title: const Text('icash Pay 現金儲值 (UAT)')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(controller: _topUpAmtController, decoration: const InputDecoration(labelText: '儲值金額 (TopUpAmt)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(controller: _buyerIdController, decoration: InputDecoration(labelText: '現金儲值條碼 (BuyerID)', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.camera_alt), onPressed: _scanBarcode, tooltip: '掃描條碼'))),
              const SizedBox(height: 24),
              _isLoading ? const Center(child: CircularProgressIndicator()) : ElevatedButton(onPressed: _handleTopUp, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('執行儲值')),
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