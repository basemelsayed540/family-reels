import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screens.dart';
import 'config.dart';
import 'data.dart';
import 'shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseKey,
  );
  runApp(const LammatnaApp());
}

class LammatnaApp extends StatelessWidget {
  const LammatnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(0.86 * mq.textScaler.scale(1))),
          child: child!,
        );
      },
      home: const AuthGate(),
    );
  }
}

/// يقرر أي شاشة تظهر: تسجيل دخول، أو انتظار موافقة، أو التطبيق نفسه.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _sub;
  String? _userId;
  Future<Map<String, dynamic>?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _userId = sb.auth.currentUser?.id;
    _profileFuture = _userId == null ? null : fetchMyProfile();
    _sub = sb.auth.onAuthStateChange.listen((data) {
      final newId = data.session?.user.id;
      if (newId == _userId) return;
      if (!mounted) return;
      setState(() {
        _userId = newId;
        _profileFuture = newId == null ? null : fetchMyProfile();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _profileFuture = _userId == null ? null : fetchMyProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const AuthScreen();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final row = snap.data;
        if (snap.hasError || row == null) {
          return ErrorScreen(
            message: 'تعذّر تحميل حسابك. تأكد من الاتصال بالإنترنت.',
            onRetry: _reload,
          );
        }
        final profile = Profile.fromMap(row);
        if (profile.status == 'approved') {
          return HomeShell(key: ValueKey(profile.id), profile: profile);
        }
        return PendingScreen(profile: profile, onRefresh: _reload);
      },
    );
  }
}
