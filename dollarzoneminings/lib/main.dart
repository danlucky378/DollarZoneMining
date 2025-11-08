import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

// 🧩 Import your helpers and services
import 'helpers/notification_helper.dart';
import 'services/notification_service.dart';
import 'services/auto_notification_service.dart';

// 🧭 Import your screens
import 'screens/home_screen.dart';
import 'screens/task_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp();

  // ✅ Initialize FCM + Local Notification Helper
  await NotificationHelper.initializeNotifications();

  // ✅ Initialize Awesome Notifications (for scheduled + interactive notifications)
  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'mining_channel',
        channelName: 'Mining Notifications',
        channelDescription:
            'Used for mining cooldowns, wallet updates, and referral alerts.',
        importance: NotificationImportance.Max,
        playSound: true,
        enableVibration: true,
        defaultColor: Colors.orange,
        ledColor: Colors.white,
      ),
    ],
  );

  // ✅ Ask user for permission
  bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    await AwesomeNotifications().requestPermissionToSendNotifications();
  }

  // ✅ Start Auto Notification Background Listener
  await AutoNotificationService().startListening();

  runApp(const DollarZoneApp());
}

class DollarZoneApp extends StatelessWidget {
  const DollarZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DollarZoneMining',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFFFFFCF9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TaskScreen(),
    WalletScreen(),
    TransactionScreen(),
    ReferralScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  void initState() {
    super.initState();

    // 🔔 Handle notification taps
    AwesomeNotifications().actionStream.listen((receivedAction) {
      if (receivedAction.channelKey == 'mining_channel') {
        final payload = receivedAction.payload ?? {};

        if (payload['target'] == 'wallet') {
          setState(() => _selectedIndex = 2);
        } else if (payload['target'] == 'referral') {
          setState(() => _selectedIndex = 4);
        } else if (payload['target'] == 'mining') {
          setState(() => _selectedIndex = 0);
        } else if (payload['target'] == 'profile') {
          setState(() => _selectedIndex = 5);
        }
      }
    });
  }

  @override
  void dispose() {
    AwesomeNotifications().actionSink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Task'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Referral'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}