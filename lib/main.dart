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
  // 應用程式的有效期限設定
  final expirationDate = DateTime.parse('2025-09-07');
  final currentDate = DateTime.now();
  // 檢查是否過期
  if (currentDate.isAfter(expirationDate)) {
    runApp(const ExpiredAppPage());
  } else {
    runApp(const MyApp());
  }
}
/// :闪闪发光: **這是您缺少實作的過期頁面 Widget**
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
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  // 頁面選項列表
  static const List<Widget> _widgetOptions = <Widget>[
    TopUpPage(),
    PaymentPage(),
    RefundPage(), // 反掃退款頁面
    CosmedPaymentPage(),
    CosmedRedirectPage(),
    RidePaymentPage(),
    TopUpPageUat(),
    FiscPaymentPage(),
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
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.add_card), label: '儲值(SIT)'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: '反掃付款'),
          BottomNavigationBarItem(icon: Icon(Icons.undo), label: '反掃退款'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: '康是美扣款'),
          BottomNavigationBarItem(icon: Icon(Icons.open_in_new), label: '康是美跳轉'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: '乘車碼扣款'),
          BottomNavigationBarItem(icon: Icon(Icons.add_moderator_outlined), label: '儲值(UAT)'),
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: 'FISC付款'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.shifting,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
