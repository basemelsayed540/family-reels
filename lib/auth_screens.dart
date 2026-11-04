import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data.dart';
import 'theme.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorScreen({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 56, color: AppColors.blue),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('حاول تاني')),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => sb.auth.signOut(),
                  child: const Text('تسجيل خروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  bool _login = true;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _code.dispose();
    super.dispose();
  }

  String _arabicError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return 'الإيميل أو الباسورد غير صحيح';
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'الإيميل ده مسجّل بالفعل، جرّب تسجيل الدخول';
    }
    if (m.contains('password should be')) {
      return 'الباسورد لازم يكون 6 حروف على الأقل';
    }
    if (m.contains('valid email') || m.contains('invalid email')) {
      return 'اكتب إيميل صحيح';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'محاولات كتير، استنى شوية وحاول تاني';
    }
    if (m.contains('not confirmed')) {
      return 'لازم تأكد الإيميل الأول من الرسالة اللي وصلتك';
    }
    return 'حصلت مشكلة، حاول تاني';
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    final name = _name.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'اكتب الإيميل والباسورد');
      return;
    }
    if (!_login && name.isEmpty) {
      setState(() => _error = 'اكتب اسمك');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_login) {
        await sb.auth.signInWithPassword(email: email, password: pass);
      } else {
        final res = await sb.auth.signUp(
          email: email,
          password: pass,
          data: {
            'display_name': name,
            'invite_code': _code.text.trim(),
          },
        );
        if (res.session == null && mounted) {
          setState(() {
            _info = 'تم إنشاء الحساب. افتح رسالة التأكيد على إيميلك ثم سجّل دخول.';
            _login = true;
          });
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _arabicError(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال. تأكد من الإنترنت.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: AppColors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.white, size: 46),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  AppConfig.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'مكان عيلتنا الخاص',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: _modeButton('تسجيل دخول', _login, () => setState(() {
                            _login = true;
                            _error = null;
                          })),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _modeButton('حساب جديد', !_login, () => setState(() {
                            _login = false;
                            _error = null;
                          })),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!_login) ...[
                  TextField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'الإيميل',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'الباسورد',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                if (!_login) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'كود الدعوة (لو معاك)',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8, right: 6, left: 6),
                    child: Text(
                      'من غير كود، طلبك هيستنى موافقة الأدمن.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(_login ? 'دخول' : 'إنشاء الحساب'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeButton(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class PendingScreen extends StatelessWidget {
  final Profile profile;
  final VoidCallback onRefresh;
  const PendingScreen({super.key, required this.profile, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    String title;
    String body;
    IconData icon;
    switch (profile.status) {
      case 'rejected':
        title = 'تم رفض طلبك';
        body = 'تواصل مع صاحب التطبيق لو فيه لبس.';
        icon = Icons.block_rounded;
        break;
      case 'blocked':
        title = 'تم إيقاف حسابك';
        body = 'تواصل مع صاحب التطبيق لو محتاج توضيح.';
        icon = Icons.block_rounded;
        break;
      default:
        title = 'طلبك قيد المراجعة';
        body = 'أول ما الأدمن يوافق هتقدر تدخل. اضغط تحديث للتأكد.';
        icon = Icons.hourglass_top_rounded;
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      color: AppColors.yellow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 42, color: const Color(0xFFB7791F)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'أهلًا ${profile.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRefresh, child: const Text('تحديث الحالة')),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => sb.auth.signOut(),
                  child: const Text('تسجيل خروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
