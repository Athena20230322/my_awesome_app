import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_services.dart';
class RefundPage extends StatefulWidget {
  const RefundPage({super.key});
  @override
  State<RefundPage> createState() => _RefundPageState();
}
class _RefundPageState extends State<RefundPage> {
  String _result = '執行結果將顯示於此。\n請先到「反掃付款」頁面完成一筆交易，才能進行退款。';
  bool _isLoading = false;
  final _apiService = GeneralApiService();
  // 用來在畫面上顯示最後一筆交易資訊
  Map<String, String?> _lastPaymentInfo = {};
  @override
  void initState() {
    super.initState();
    // 頁面載入時，自動讀取上次付款的資訊
    _loadLastPaymentInfo();
  }
  /// 從 SharedPreferences 讀取上次付款的資訊以供顯示
  Future<void> _loadLastPaymentInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastPaymentInfo = {
        'OPSeq': prefs.getString('refund_op_seq'),
        'BankSeq': prefs.getString('refund_bank_seq'),
        'BuyerID': prefs.getString('refund_buyer_id'),
      };
    });
  }
  /// 處理退款邏輯
  Future<void> _handleRefund() async {
    // 確保使用的是最新的資訊
    await _loadLastPaymentInfo();
    final opSeq = _lastPaymentInfo['OPSeq'];
    final bankSeq = _lastPaymentInfo['BankSeq'];
    final buyerId = _lastPaymentInfo['BuyerID'];
    // 檢查是否有可用的退款資訊
    if (opSeq == null || bankSeq == null || buyerId == null) {
      setState(() {
        _result = '錯誤：找不到可用的退款資訊。\n請先完成一筆「反掃付款」交易。';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _result = '處理中...';
    });
    try {
      final response = await _apiService.performRefund(
        opSeq: opSeq,
        bankSeq: bankSeq,
        buyerId: buyerId,
      );
      setState(() {
        _result = response;
      });
    } catch (e) {
      setState(() {
        _result = "執行退款時發生錯誤：\n$e";
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
      appBar: AppBar(title: const Text('icash Pay 反掃退款')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 顯示將被退款的交易資訊卡片
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('將用於退款的交易資訊', style: Theme.of(context).textTheme.titleMedium),
                      const Divider(height: 20),
                      Text('OPSeq: ${_lastPaymentInfo['OPSeq'] ?? '（無資料）'}'),
                      const SizedBox(height: 4),
                      Text('BankSeq: ${_lastPaymentInfo['BankSeq'] ?? '（無資料）'}'),
                      const SizedBox(height: 4),
                      Text('BuyerID: ${_lastPaymentInfo['BuyerID'] ?? '（無資料）'}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _loadLastPaymentInfo,
                            child: const Text('重新整理'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 執行按鈕
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _handleRefund,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('執行退款'),
              ),
              const SizedBox(height: 24),
              const Text('執行結果:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // 結果顯示區塊
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8)),
                child: SelectableText(_result),
              ),
            ],
          ),
        ),
      ),
    );
  }
}