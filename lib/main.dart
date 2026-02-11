import 'package:flutter/material.dart';
import 'pages/top_up_page.dart';
import 'pages/payment_page.dart';
import 'pages/cosmed_payment_page.dart';
import 'pages/ride_payment_page.dart';
import 'pages/top_up_page_uat.dart';
import 'pages/cosmed_redirect_page.dart';
import 'pages/fisc_payment_page.dart';
import 'pages/refund_page.dart';
import 'pages/simplemart_payment_page.dart';
import 'pages/icash_welfare_payment_page.dart';
import 'pages/BooksPaymentPage.dart';


// 🌟 1. 嘗試讀取編譯時的日期 (若有下特殊指令)
const String buildDateEnv = String.fromEnvironment('BUILD_DATE');

void main() {
  final expirationDate = DateTime.parse('2026-06-07');
  final currentDate = DateTime.now();
  if (currentDate.isAfter(expirationDate)) {
    runApp(const ExpiredAppPage());
  } else {
    runApp(const MyApp());
  }
}

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
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FeatureItem {
  final String title;
  final IconData icon;
  final Widget page;
  const FeatureItem({required this.title, required this.icon, required this.page});
}

final List<FeatureItem> features = [
  FeatureItem(title: '儲值(SIT)', icon: Icons.add_card, page: const TopUpPage()),
  FeatureItem(title: '反掃付款', icon: Icons.qr_code_scanner, page: const PaymentPage()),
  FeatureItem(title: '反掃退款', icon: Icons.undo, page: const RefundPage()),
  FeatureItem(title: '康是美扣款', icon: Icons.store, page: const CosmedPaymentPage()),
  FeatureItem(title: '康是美跳轉', icon: Icons.open_in_new, page: const CosmedRedirectPage()),
  FeatureItem(title: '乘車碼扣款', icon: Icons.directions_bus, page: const RidePaymentPage()),
  FeatureItem(title: '儲值(UAT)', icon: Icons.add_moderator_outlined, page: const TopUpPageUat()),
  FeatureItem(title: '韓國付款', icon: Icons.shield, page: const FiscPaymentPage()),
  FeatureItem(title: '美廉社3DS扣款', icon: Icons.local_grocery_store, page: const SimpleMartPaymentPage()),
  FeatureItem(title: '愛金卡褔利社九九號店3DS扣款', icon: Icons.storefront, page: const IcashWelfarePaymentPage()),
  FeatureItem(title: '博客來網路書店3DS扣款', icon: Icons.menu_book, page: const BooksPaymentPage()),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // 🌟 2. 輔助函式：將 DateTime 轉為易讀格式 (YYYY-MM-DD HH:MM)
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} "
        "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 3. 智慧判斷邏輯
    // 如果 buildDateEnv 是空的 (代表沒下特殊指令)，就抓現在時間 (DateTime.now)
    // 如果 buildDateEnv 有值，就用那個固定的包版日期
    String displayDate;
    if (buildDateEnv.isNotEmpty) {
      displayDate = "版本: $buildDateEnv";
    } else {
      displayDate = "預覽: ${_formatDate(DateTime.now())} (App開啟時間)";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('icash Pay Demo Home'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.9,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                return _buildFeatureCard(context, feature);
              },
            ),
          ),
          // 🌟 4. 顯示日期
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
            child: Text(
              displayDate,
              style: const TextStyle(color: Colors.grey, fontSize: 13.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, FeatureItem feature) {
    return Card(
      elevation: 2.0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
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