import 'package:flutter/material.dart';
import 'pages/top_up_page.dart';
import 'pages/payment_page.dart';
import 'pages/cosmed_payment_page.dart';
import 'pages/ride_payment_page.dart';
import 'pages/top_up_page_uat.dart'; // <--- 1. 引用新的 UAT 頁面
void main() {
  final expirationDate = DateTime.parse('2025-09-07');
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
    // ... 此處程式碼不變 ...
    return Container(); // Placeholder
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'icash Pay Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  // --- 2. 在頁面列表中加入新的 UAT 頁面 ---
  static const List<Widget> _widgetOptions = <Widget>[
    TopUpPage(),
    PaymentPage(),
    CosmedPaymentPage(),
    RidePaymentPage(),
    TopUpPageUat(), // <--- 加入新的 UAT 頁面
  ];
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // --- 3. 在導航欄中加入新的按鈕 ---
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.add_card), label: '儲值(SIT)'), // 修改標籤
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: '反掃付款'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: '康是美扣款'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: '乘車碼扣款'),
          BottomNavigationBarItem(icon: Icon(Icons.add_moderator_outlined), label: '儲值(UAT)'), // <--- 新增 UAT 按鈕
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}