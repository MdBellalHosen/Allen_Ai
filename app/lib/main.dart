import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await Services.create();
  runApp(AllenApp(services: services));
}

class AllenApp extends StatefulWidget {
  const AllenApp({super.key, required this.services});
  final Services services;

  @override
  State<AllenApp> createState() => _AllenAppState();
}

class _AllenAppState extends State<AllenApp> {
  // Router must survive rebuilds when settings change.
  late final _router = buildRouter(onboarded: widget.services.prefs.getBool('onboarded') ?? false);

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return ServicesScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) => MaterialApp.router(
          title: 'ALLEN AI',
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          routerConfig: _router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}
