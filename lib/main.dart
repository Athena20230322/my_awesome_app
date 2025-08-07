import 'package:flutter/material.dart';
import 'pages/top_up_page.dart';
import 'pages/payment_page.dart';
import 'pages/cosmed_payment_page.dart';
import 'pages/ride_payment_page.dart';
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('應用程式已過期'), backgroundColor: Colors.red),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 80),
                SizedBox(height: 20),
                Text('此應用程式版本已過期', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                SizedBox(height: 10),
                Text('請聯繫開發人員以獲取更新版本。', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
              ],
            ),
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
  static const List<Widget> _widgetOptions = <Widget>[
    TopUpPage(),
    PaymentPage(),
    CosmedPaymentPage(),
    RidePaymentPage(),
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
          BottomNavigationBarItem(icon: Icon(Icons.add_card), label: '現金儲值'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: '反掃付款'),
          BottomNavigationBarItem(icon: Icon(Icons.store), label: '康是美扣款'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: '乘車碼扣款'),
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
