import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../platform/device_bridge.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with WidgetsBindingObserver {
  DeviceBridge? _bridge;
  bool _acc = false;

  PermissionStatus _mic = PermissionStatus.denied;
  PermissionStatus _notif = PermissionStatus.denied;
  PermissionStatus _media = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bridge ??= ServicesScope.of(context).bridge;
    _refreshAcc();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAcc(); // user may have just enabled it in Settings
  }

  Future<void> _refreshAcc() async {
    final on = await _bridge!.isAccessibilityEnabled();
    if (mounted) setState(() => _acc = on);
  }

  Future<void> _ask(Permission p, void Function(PermissionStatus) set) async {
    final s = await p.request();
    if (mounted) setState(() => set(s));
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (mounted) context.go('/');
  }

  Widget _tile(String title, String why, PermissionStatus s, VoidCallback onGrant, String grant) {
    return ListTile(
      title: Text(title),
      subtitle: Text(why),
      trailing: s.isGranted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : FilledButton.tonal(onPressed: onGrant, child: Text(grant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.onboardingTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.onboardingIntro),
          const SizedBox(height: 16),
          _tile(t.permMic, t.permMicWhy, _mic, () => _ask(Permission.microphone, (s) => _mic = s), t.grant),
          _tile(t.permNotif, t.permNotifWhy, _notif, () => _ask(Permission.notification, (s) => _notif = s), t.grant),
          _tile(t.permMedia, t.permMediaWhy, _media, () => _ask(Permission.videos, (s) => _media = s), t.grant),
          ListTile(
            title: Text(t.permAccessibility),
            subtitle: Text(t.permAccessibilityWhy),
            trailing: _acc
                ? const Icon(Icons.check_circle, color: Colors.green)
                : FilledButton.tonal(onPressed: () => _bridge!.openAccessibilitySettings(), child: Text(t.openSettings)),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _finish, child: Text(t.continueLabel)),
        ],
      ),
    );
  }
}
