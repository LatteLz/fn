import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme/app_theme.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/prediction_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'services/background_monitoring.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyAnlTjNUS8TXyYbA4CkwctxqkgtcNfvPUs',
        appId: '1:991635367629:android:c0df528b58c83168dd6b84',
        messagingSenderId: '991635367629',
        projectId: 'strokeguard-nhom9',
        storageBucket: 'strokeguard-nhom9.firebasestorage.app',
      ),
    );
    debugPrint("Firebase của StrokeGuard Nhóm 9 đã kích hoạt thành công!");

    await BackgroundMonitoring.initialize();
  } catch (e) {
    debugPrint("App initialization error: $e");
  }

  runApp(const StrokeGuardApp());
}

class StrokeGuardApp extends StatelessWidget {
  const StrokeGuardApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StrokeGuard AI',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _AuthGate(),
      );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          return snap.hasData ? const MainShell() : const RegisterScreen();
        },
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    BackgroundMonitoring.startForCurrentUser();
  }

  static const _screens = [
    HomeScreen(),
    PredictionScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          indicatorColor: Colors.blue.withValues(alpha: 0.12),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_rounded), label: 'Trang chủ'),
            NavigationDestination(
                icon: Icon(Icons.analytics_rounded), label: 'Phân tích'),
            NavigationDestination(
                icon: Icon(Icons.history_rounded), label: 'Lịch sử'),
            NavigationDestination(
                icon: Icon(Icons.person_rounded), label: 'Hồ sơ'),
          ],
        ),
      );
}
