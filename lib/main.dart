import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/auth_login_page.dart';
import 'pages/app_shell.dart';
import 'services/study_ai_settings.dart';
import 'theme/theme_controller.dart';

final themeController = ThemeController();
bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load appearance before first paint to avoid theme flash.
  // Do not initialize Firebase before runApp: the macOS C++ SDK can abort
  // the process (missing plist / bad app id), which Dart try/catch cannot
  // stop, and macOS then shows "StudyGrove quit unexpectedly".
  await themeController.load();
  await studyAiSettings.load();
  runApp(const OrganiserApp());
}

Future<bool> initializeFirebaseSafely() async {
  if (firebaseReady) return true;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    return true;
  } catch (e, st) {
    debugPrint('Firebase failed to start: $e\n$st');
    firebaseReady = false;
    return false;
  }
}

class OrganiserApp extends StatelessWidget {
  const OrganiserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Study Grove',
          debugShowCheckedModeBanner: false,
          theme: themeController.lightTheme,
          darkTheme: themeController.darkTheme,
          themeMode: themeController.themeMode,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFirebase();
    });
  }

  Future<void> _startFirebase() async {
    await initializeFirebaseSafely();
    if (mounted) setState(() => _starting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!firebaseReady) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Study Grove could not start cloud login on this Mac. Check the network and open the app again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        themeController.bindUser(user?.uid);
        if (user == null) return const AuthLoginPage();
        return const AppShell();
      },
    );
  }
}
