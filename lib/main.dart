import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'firebase_options.dart';
import 'service/notification_service.dart';
import 'pages/LoginPage.dart';
import 'pages/TeacherHomePage.dart';
import 'pages/StudentHomePage.dart';
import 'pages/CoachHomePage.dart';

Future<void> requestExactAlarmPermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      await intent.launch();
    }
  }
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  await requestExactAlarmPermission();
}

void main() async {
  try {
    await _bootstrap();
    runApp(const MyApp());
  } catch (e, st) {
    // If boot fails before runApp, show a minimal error app
    runApp(_BootErrorApp(error: e, stack: st));
  }
}

class _BootErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace stack;
  const _BootErrorApp({required this.error, required this.stack, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Başlatma Hatası')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text('Uygulama başlatılırken bir hata oluştu.\n\n$error\n\n$stack'),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartPage() async {
    // 1) Auth check
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();

    // 2) Email verification (ignore errors from reload; don’t block start)
    try {
      await user.reload();
    } catch (_) {}
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && !refreshed.emailVerified) {
      return const LoginPage();
    }

    // 3) Fetch role from users/{uid}
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!snap.exists) {
      debugPrint('users/${user.uid} document does not exist.');
      return const LoginPage();
    }

    final data = snap.data();
    final role = data?['role'];
    switch (role) {
      case 'teacher':
        return const TeacherHomePage();
      case 'student':
        return const StudentHomePage();
      case 'coach':
        return const CoachHomePage();
      default:
        debugPrint('Unknown or missing role for ${user.uid}: $role');
        return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Özel Ders Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F0FF),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: const TextStyle(color: Colors.deepPurple),
          prefixIconColor: Colors.deepPurple,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
          ),
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _getStartPage(),
        builder: (context, snapshot) {
          // Show progress while deciding the start page
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If anything threw inside _getStartPage, show the error clearly
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Başlatma Hatası')),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Text(
                    'Giriş sayfası yüklenemedi.\n\nHata: ${snapshot.error}\n\n${snapshot.stackTrace}',
                  ),
                ),
              ),
            );
          }

          // Never return null; fall back to LoginPage if something odd happened
          final start = snapshot.data ?? const LoginPage();
          return start;
        },
      ),
    );
  }
}
