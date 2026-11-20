import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(children: [
        // Phase 1 TODO: persist locale choice (system / en / bn).
        ListTile(title: Text(t.language), subtitle: Text(t.languageSystem)),
      ]),
    );
  }
}
