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
import 'package:ctp_overtime_tracker/screens/settings_screen.dart';
import 'package:ctp_overtime_tracker/screens/login_screen.dart';
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

  /// Fetches manager profile from Firestore for the given Firebase user.
  /// If found, logs in the user. If not, sets error and signs out.
  Future<void> loadFromFirebase(firebase_auth.User firebaseUser) async {
    setLoading(true);
    setAuthError(null); // Clear previous errors

    try {
      final uid = firebaseUser.uid;
      print('AuthWrapper: Loading profile for UID: $uid'); // Debug

      final snapshot = await FirebaseFirestore.instance
          .collection('employees')
          .where('uid', isEqualTo: uid)
          .where('position', isEqualTo: 'Manager')
          .limit(1)
          .get();

      print('AuthWrapper: Query returned ${snapshot.docs.length} docs'); // Debug

      if (snapshot.docs.isNotEmpty) {
        print('AuthWrapper: First doc data: ${snapshot.docs.first.data()}'); // Debug
        final appUser = User.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
        login(appUser);
        print('AuthWrapper: Logged in user: ${appUser.name}'); // Debug
      } else {
        print('AuthWrapper: No documents found for UID: $uid, position: Manager'); // Debug
        setAuthError('No manager profile found for this account. Contact admin.');
        await firebase_auth.FirebaseAuth.instance.signOut();
        print('AuthWrapper: No manager profile found, signed out'); // Debug
      }
    } catch (e) {
      setAuthError('Error loading profile: ${e.toString()}');
      await firebase_auth.FirebaseAuth.instance.signOut();
      print('AuthWrapper: Error loading profile: $e'); // Debug
    } finally {
      setLoading(false);
      print('AuthWrapper: Loading complete'); // Debug
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

  final List<Widget> _screens = [
    const DashboardScreen(),
    const OvertimeScreen(),
    const JobsScreen(),
    const JobAnalysisScreen(),
    const CalendarViewScreen(),
    const ApprovalScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

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
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                try {
                  await firebase_auth.FirebaseAuth.instance.signOut();
                  userProvider.logout();
                } catch (e) {
                  print('Logout error: $e');
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'user',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        user?.name[0] ?? 'M',
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Manager'),
                        Text(
                          user?.department ?? 'Department',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                user?.name[0] ?? 'M',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: 'Approval',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
