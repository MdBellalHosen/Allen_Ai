import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/settings/settings_page.dart';

GoRouter buildRouter({required bool onboarded}) => GoRouter(
      initialLocation: onboarded ? '/' : '/onboarding',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomePage()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      ],
    );
