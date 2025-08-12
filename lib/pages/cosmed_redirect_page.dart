import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../api_services.dart';

class CosmedRedirectPage extends StatefulWidget {
  const CosmedRedirectPage({super.key});

  @override
  State<CosmedRedirectPage> createState() => _CosmedRedirectPageState();
}

class _CosmedRedirectPageState extends State<CosmedRedirectPage> {
  // 預設金額與 JS 腳本一致，方便測試
  final _totalAmountController = TextEditingController(text: '50000');
  String _result = '點擊按鈕以產生付款連結。';
  bool _isLoading = false;
  final _apiService = CosmedApiService();

  @override
  void dispose() {
    _totalAmountController.dispose();
    super.dispose();
  }

  Future<void> _handleGetPaymentUrl() async {
    if (_totalAmountController.text.isEmpty) {
      setState(() {
        _result = '錯誤：總金額為必填欄位。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = '正在向 iCP 請求付款連結...';
    });

    try {
      // 呼叫我們即將在 api_service.dart 中新增的方法
      final paymentUrl = await _apiService.getPaymentUrl(
        totalAmount: _totalAmountController.text.trim(),
      );

      // 使用 url_launcher 開啟連結
      if (await canLaunchUrlString(paymentUrl)) {
        await launchUrlString(paymentUrl, mode: LaunchMode.externalApplication);
        setState(() {
          _result = '付款連結已成功在瀏覽器中開啟！\n\nURL (可複製):\n$paymentUrl';
        });
      } else {
        // 如果因某些原因無法自動開啟，則顯示連結讓使用者手動複製
        setState(() {
          _result = '無法自動開啟連結，請手動複製。\n\nURL:\n$paymentUrl';
        });
      }

    } catch (e) {
      setState(() {
        _result = "發生錯誤：\n$e";
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
      appBar: AppBar(title: const Text('康是美跳轉付款')),
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
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('產生並開啟付款連結'),
                onPressed: _handleGetPaymentUrl,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 24),
              const Text('執行結果:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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