import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ctp_overtime_tracker/firebase_options.dart';
import 'package:ctp_overtime_tracker/theme/app_theme.dart';
import 'package:ctp_overtime_tracker/screens/overtime_screen.dart';
import 'package:ctp_overtime_tracker/screens/jobs_screen.dart';
import 'package:ctp_overtime_tracker/screens/job_analysis_screen.dart';
import 'package:ctp_overtime_tracker/screens/calendar_view_screen.dart';
import 'package:ctp_overtime_tracker/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const CTPOverTimeTrackerApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

class CTPOverTimeTrackerApp extends StatelessWidget {
  const CTPOverTimeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'CTP Gravure Overtime',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainNavigation(),
      debugShowCheckedModeBanner: false,
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

  final List<Widget> _screens = [
    const DashboardScreen(),
    const OvertimeScreen(),
    const JobsScreen(),
    const JobAnalysisScreen(),
    const CalendarViewScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CTP Gravure Overtime'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Dark/Light Mode',
          ),
          const SizedBox(width: 16),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Text('M', style: TextStyle(color: Colors.blue)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryOrange,
        unselectedItemColor: Colors.grey[400]!,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Overtime',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}