import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'pages/auth_login_page.dart';
import 'pages/app_shell.dart';
import 'services/study_ai_settings.dart';
import 'theme/theme_controller.dart';

final themeController = ThemeController();
bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TestFlight / Mac App Store is sandboxed. Downloading fonts at first
  // paint can write outside the container and macOS then kills the app
  // ("quit unexpectedly"). USB builds hid this because sandbox is off.
  GoogleFonts.config.allowRuntimeFetching = false;
  // Load appearance before first paint to avoid theme flash.
  // Do not initialize Firebase or the keychain before runApp: the macOS
  // SDK can abort the process (bad app id / keychain), which Dart
  // try/catch cannot stop, and macOS then shows "StudyGrove quit unexpectedly".
  try {
    await themeController.load();
  } catch (e, st) {
    debugPrint('Theme failed to load: $e\n$st');
  }
  runApp(const OrganiserApp());
}

Future<bool> initializeFirebaseSafely() async {
  if (firebaseReady) return true;
  try {
    // Native macOS already configures the default FIRApp during plugin
    // registration. A second default-app configure also aborts.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
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
    try {
      await studyAiSettings.load();
    } catch (e, st) {
      debugPrint('Study AI settings failed to load: $e\n$st');
    }
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
