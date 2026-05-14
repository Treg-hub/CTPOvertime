import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'firebase_options.dart';
import 'package:ctp_overtime_tracker/theme/app_theme.dart';
import 'package:ctp_overtime_tracker/models/user.dart';
import 'package:ctp_overtime_tracker/screens/overtime_screen.dart';
import 'package:ctp_overtime_tracker/screens/jobs_screen.dart';
import 'package:ctp_overtime_tracker/screens/job_analysis_screen.dart';
import 'package:ctp_overtime_tracker/screens/calendar_view_screen.dart';
import 'package:ctp_overtime_tracker/screens/dashboard_screen.dart';
import 'package:ctp_overtime_tracker/screens/approval_screen.dart';
import 'package:ctp_overtime_tracker/screens/wages_screen.dart';
import 'package:ctp_overtime_tracker/screens/settings_screen.dart';
import 'dart:async';
import 'package:ctp_overtime_tracker/screens/login_screen.dart';
import 'package:ctp_overtime_tracker/services/data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const CTPOverTimeTrackerApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _authError;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get authError => _authError;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setAuthError(String? error) {
    _authError = error;
    notifyListeners();
  }

  void login(User user) {
    _currentUser = user;
    _authError = null; // Clear any previous error
    print('UserProvider: login called for ${user.name}'); // Debug
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _authError = null;
    notifyListeners();
  }

  /// Fetches employee profile from Firestore for the given Firebase user.
  /// Allows Manager and Wages positions; rejects everything else.
  Future<void> loadFromFirebase(firebase_auth.User firebaseUser) async {
    setLoading(true);
    setAuthError(null);

    try {
      final uid = firebaseUser.uid;

      // Query by UID only — no position filter so Wages can log in too.
      final snapshot = await FirebaseFirestore.instance
          .collection('employees')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final position = data['position'] as String? ?? '';

        if (position == 'Manager' || position == 'Wages') {
          final appUser =
              User.fromMap(data, snapshot.docs.first.id);
          login(appUser);
        } else {
          setAuthError(
              'Access denied. Only managers and wages staff can use this app.');
          await firebase_auth.FirebaseAuth.instance.signOut();
        }
      } else {
        setAuthError(
            'No employee profile found for this account. Contact admin.');
        await firebase_auth.FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      setAuthError('Error loading profile: ${e.toString()}');
      await firebase_auth.FirebaseAuth.instance.signOut();
    } finally {
      setLoading(false);
    }
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
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        return StreamBuilder<firebase_auth.User?>(
          stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            print('AuthWrapper: hasData=${snapshot.hasData}, currentUser=${userProvider.currentUser?.name ?? 'null'}, isLoading=${userProvider.isLoading}'); // Debug

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF6B35),
                  ),
                ),
              );
            }

            if (snapshot.hasData) {
              // Firebase user exists
              if (userProvider.currentUser != null) {
                print('AuthWrapper: Showing MainNavigation'); // Debug
                return const MainNavigation();
              } else {
                // Auto-fetch manager profile
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Provider.of<UserProvider>(context, listen: false).loadFromFirebase(snapshot.data!);
                });
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                );
              }
            }

            // No Firebase user
            print('AuthWrapper: Showing LoginScreen'); // Debug
            return const LoginScreen();
          },
        );
      },
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
  int _rejectionCount = 0;
  StreamSubscription<int>? _rejectionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupRejectionBadge());
  }

  void _setupRejectionBadge() {
    final user =
        Provider.of<UserProvider>(context, listen: false).currentUser;
    // Only dept managers and workshop managers can have their submitted
    // entries rejected — wire up the badge for those roles.
    if (user == null ||
        user.role == AppRole.wages ||
        user.role == AppRole.generalManager) return;

    _rejectionSub =
        DataService.getRejectedUnacknowledgedCount(user.department)
            .listen((n) {
      if (mounted) {
        setState(() => _rejectionCount = n);
      }
    });
  }

  @override
  void dispose() {
    _rejectionSub?.cancel();
    super.dispose();
  }

  // Build the screen list based on the user's role.
  List<Widget> _buildScreens(AppRole role) {
    if (role == AppRole.wages) {
      return [
        const WagesScreen(),
        const SettingsScreen(),
      ];
    }
    return [
      const DashboardScreen(),
      const OvertimeScreen(),
      const JobsScreen(),
      const JobAnalysisScreen(),
      const CalendarViewScreen(),
      if (role == AppRole.workshopManager || role == AppRole.generalManager)
        const ApprovalScreen(),
      const SettingsScreen(),
    ];
  }

  List<BottomNavigationBarItem> _buildNavItems(AppRole role) {
    final overtimeIcon = _rejectionCount > 0
        ? Badge(
            label: Text('$_rejectionCount'),
            child: const Icon(Icons.access_time),
          )
        : const Icon(Icons.access_time);

    if (role == AppRole.wages) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.download),
          label: 'Download',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ];
    }

    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      BottomNavigationBarItem(
        icon: overtimeIcon,
        label: 'Overtime',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.work),
        label: 'Jobs',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.analytics),
        label: 'Analysis',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month),
        label: 'Calendar',
      ),
      if (role == AppRole.workshopManager || role == AppRole.generalManager)
        const BottomNavigationBarItem(
          icon: Icon(Icons.task_alt),
          label: 'Approval',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final role = user?.role ?? AppRole.deptManager;

    final screens = _buildScreens(role);
    final navItems = _buildNavItems(role);

    // Guard against stale index after role changes.
    final safeIndex = _selectedIndex.clamp(0, screens.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CTP Gravure Overtime'),
        actions: [
          IconButton(
            icon: Icon(
                themeProvider.isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeProvider.toggleTheme(),
            tooltip: 'Toggle Dark/Light Mode',
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                try {
                  await firebase_auth.FirebaseAuth.instance.signOut();
                  userProvider.logout();
                } catch (e) {
                  // ignore logout errors
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'user',
                enabled: false,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'User'),
                        Text(
                          _roleLabel(role),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: screens[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryOrange,
        unselectedItemColor: Colors.grey[400]!,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: navItems,
      ),
    );
  }

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.generalManager:
        return 'General Manager';
      case AppRole.workshopManager:
        return 'Workshop Manager';
      case AppRole.wages:
        return 'Wages';
      case AppRole.deptManager:
        return 'Department Manager';
    }
  }
}
