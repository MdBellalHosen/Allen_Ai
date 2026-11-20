import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appName),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.homeTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 32),
            // Phase 2: wire this button to STT.
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.mic),
              label: Text(t.tapToTalk),
            ),
          ],
        ),
      ),
    );
  }
}
