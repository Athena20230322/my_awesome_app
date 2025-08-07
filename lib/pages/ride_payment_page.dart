import 'package:flutter/material.dart';
import 'dart:math';
import 'barcode_scanner_page.dart';
class RidePaymentPage extends StatefulWidget {
  const RidePaymentPage({super.key});
  @override
  State<RidePaymentPage> createState() => _RidePaymentPageState();
}
class _RidePaymentPageState extends State<RidePaymentPage> {
  String _result = '執行結果將顯示於此。\n請掃描乘車碼以獲取其詳細偵錯資訊。';
  bool _isLoading = false;
  // final _apiService = RidePaymentApiService(); // 偵錯模式下暫時不需要呼叫 API
  Future<void> _scanAndProcessPayment() async {
    // 導航到掃描頁面並等待結果
    final scannedQrData = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );
    // 檢查使用者是否掃描了內容
    if (scannedQrData == null || scannedQrData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('掃描已取消'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }
    setState(() { _isLoading = true; });
    // --- 【*** 偵錯邏輯開始 ***】 ---
    // 1. 執行我們之前嘗試的處理邏輯，以便比對
    String sanitizedString = scannedQrData.replaceAll('\u0000', '');
    String processedString = sanitizedString.trim();
    while (processedString.length % 4 != 0) {
      processedString += '=';
    }
    // 2. 準備要顯示在畫面上的所有偵錯資訊
    final rawRunes = scannedQrData.runes.toList();
    final processedRunes = processedString.runes.toList();
    String debugOutput = '--- 請將以下所有內容複製並回傳 ---\n\n'
        '【1. 原始掃描字串】\n'
        '字串長度: ${scannedQrData.length}\n'
        '字元碼 (開頭10碼): ${rawRunes.take(10)}\n'
        '字元碼 (結尾10碼): ${rawRunes.skip(max(0, rawRunes.length - 10))}\n\n'
        '--- 原始字串的完整內容 ---\n'
        '$scannedQrData\n'
        '--- 內容結束 ---\n\n'
        '【2. 最終處理後準備解碼的字串】\n'
        '字串長度: ${processedString.length}\n'
        '長度是否為4的倍數: ${processedString.length % 4 == 0}\n'
        '字元碼 (開頭10碼): ${processedRunes.take(10)}\n'
        '字元碼 (結尾10碼): ${processedRunes.skip(max(0, processedRunes.length - 10))}\n\n'
        '--- 處理後字串的完整內容 ---\n'
        '$processedString\n'
        '--- 內容結束 ---';
    // 3. 將偵錯資訊更新到畫面上
    setState(() {
      _result = debugOutput;
      _isLoading = false;
    });
    // --- 【*** 偵錯邏輯結束 ***】 ---
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('乘車碼扣款 (偵錯模式)')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 說明卡片
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.bug_report, size: 50, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 10),
                      const Text('乘車碼扣款偵錯', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('請掃描有問題的乘車碼，然後將下方「執行結果」框內的**所有文字**複製並回傳。', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 執行按鈕
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('掃描乘車碼獲取資訊'),
                onPressed: _scanAndProcessPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 24),
              // 結果顯示區
              const Text('執行結果:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                // 使用等寬字體方便查看原始字串的細節
                child: SelectableText(_result, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
