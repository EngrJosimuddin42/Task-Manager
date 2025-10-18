import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/task_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';
import 'db/db_helper.dart';
import 'screens/email_verify_screen.dart';
import '../services/custom_snackbar.dart';

/// 🔹 Global ScaffoldMessengerKey
final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Enable offline Firestore cache
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 20 * 1024 * 1024, // 20 MB cache
      );

  runApp(const TaskManagerApp());
}

/// 🔹 Root Application
class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => TaskProvider())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: globalMessengerKey,
        title: 'Task Manager',
        theme: ThemeData(primarySwatch: Colors.deepPurple),
        home: const WifiListenerWrapper(child: AuthGate()),
      ),
    );
  }
}

/// 🔹 Wi-Fi/Data connectivity listener with Global Key
class WifiListenerWrapper extends StatefulWidget {
  final Widget child;
  const WifiListenerWrapper({super.key, required this.child});

  @override
  State<WifiListenerWrapper> createState() => _WifiListenerWrapperState();
}

class _WifiListenerWrapperState extends State<WifiListenerWrapper> {
  late final Connectivity _connectivity;
  final DBHelper _dbHelper = DBHelper();
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();

    _connectivity.onConnectivityChanged.listen((result) async {
      if (!mounted) return;

      // ❌ Went offline
      if (result == ConnectivityResult.none && !_wasOffline) {
        _wasOffline = true;
        CustomSnackbar.show(globalMessengerKey.currentContext!,"❌ No Internet connection",backgroundColor: Colors.redAccent);}

      // 🌐 Came online
      else if (result != ConnectivityResult.none && _wasOffline) {
        _wasOffline = false;
        String connectionType =
        result == ConnectivityResult.wifi
            ? '📶 Wi-Fi connected'
            : '📱 Mobile data connected';
        CustomSnackbar.show(globalMessengerKey.currentContext!,connectionType,backgroundColor: Colors.green);

        // 🔄 Sync local → Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _dbHelper.syncToFirestore(user.uid);
          final taskProvider = Provider.of<TaskProvider>(context, listen: false);
          await taskProvider.loadTasks();
          debugPrint('✅ Local tasks synced to Firestore for ${user.uid}');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 🔹 Authentication Gate
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          if (!user.emailVerified) {
            return const EmailVerifyScreen();
          }
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
