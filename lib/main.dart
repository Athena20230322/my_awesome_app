import 'package:flutter/material.dart';
import 'pages/top_up_page.dart';
import 'pages/payment_page.dart';
import 'pages/cosmed_payment_page.dart';
import 'pages/ride_payment_page.dart';
import 'pages/top_up_page_uat.dart';
import 'pages/cosmed_redirect_page.dart';
import 'pages/fisc_payment_page.dart';
import 'pages/refund_page.dart';

void main() {
  // 應用程式的有效期限設定 (此部分邏輯維持不變)
  final expirationDate = DateTime.parse('2025-09-07');
  final currentDate = DateTime.now();
  // 檢查是否過期
  if (currentDate.isAfter(expirationDate)) {
    runApp(const ExpiredAppPage());
  } else {
    runApp(const MyApp());
  }
}

/// 過期頁面 Widget (維持不變)
class ExpiredAppPage extends StatelessWidget {
  const ExpiredAppPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'This application has expired.',
            style: TextStyle(color: Colors.red, fontSize: 22),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'icash Pay Demo',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const HomePage(), // 主頁入口不變
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 建立一個模型類別來存放每個功能項目的資訊
class FeatureItem {
  final String title;
  final IconData icon;
  final Widget page;

  const FeatureItem({required this.title, required this.icon, required this.page});
}

/// 所有功能頁面的列表
/// 未來若要新增功能，只需要在此列表中增加一個 FeatureItem 即可
final List<FeatureItem> features = [
  FeatureItem(title: '儲值(SIT)', icon: Icons.add_card, page: const TopUpPage()),
  FeatureItem(title: '反掃付款', icon: Icons.qr_code_scanner, page: const PaymentPage()),
  FeatureItem(title: '反掃退款', icon: Icons.undo, page: const RefundPage()),
  FeatureItem(title: '康是美扣款', icon: Icons.store, page: const CosmedPaymentPage()),
  FeatureItem(title: '康是美跳轉', icon: Icons.open_in_new, page: const CosmedRedirectPage()),
  FeatureItem(title: '乘車碼扣款', icon: Icons.directions_bus, page: const RidePaymentPage()),
  FeatureItem(title: '儲值(UAT)', icon: Icons.add_moderator_outlined, page: const TopUpPageUat()),
  // ✨ --- 修改點 --- ✨
  FeatureItem(title: '韓國付款', icon: Icons.shield, page: const FiscPaymentPage()),
];


/// 新的 HomePage Widget，使用網格佈局
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('icash Pay Demo Home'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: GridView.builder(
        // 使用 GridView.builder 建立網格
        padding: const EdgeInsets.all(16.0),
        // 設定網格的 Delegate，每行顯示 3 個項目
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 每行顯示的數量
          crossAxisSpacing: 16.0, // 水平間距
          mainAxisSpacing: 16.0, // 垂直間距
          childAspectRatio: 0.9, // 調整項目的寬高比，讓文字有足夠空間
        ),
        itemCount: features.length, // 網格項目的總數
        itemBuilder: (context, index) {
          final feature = features[index];
          return _buildFeatureCard(context, feature);
        },
      ),
    );
  }

  /// 建立單一網格項目的方法
  Widget _buildFeatureCard(BuildContext context, FeatureItem feature) {
    return Card(
      elevation: 2.0,
      clipBehavior: Clip.antiAlias, // 讓 InkWell 的波紋效果被限制在 Card 的圓角內
      child: InkWell(
        // 使用 InkWell 包裹以提供點擊效果
        onTap: () {
          // 點擊後，使用 Navigator.push 跳轉到對應的頁面
          // 這會自動在目標頁面的 AppBar 上加上返回按鈕
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => feature.page),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(feature.icon, size: 40.0, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                feature.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.0),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}