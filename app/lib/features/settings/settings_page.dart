import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = ServicesScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) => ListView(children: [
          ListTile(title: Text(t.voiceLanguage)),
          RadioListTile<VoiceMode>(
              title: Text(t.voiceBn), value: VoiceMode.bn, groupValue: s.settings.voiceMode, onChanged: (v) => s.settings.setVoiceMode(v!)),
          RadioListTile<VoiceMode>(
              title: Text(t.voiceEn), value: VoiceMode.en, groupValue: s.settings.voiceMode, onChanged: (v) => s.settings.setVoiceMode(v!)),
          RadioListTile<VoiceMode>(
              title: Text(t.voiceAuto), value: VoiceMode.auto, groupValue: s.settings.voiceMode, onChanged: (v) => s.settings.setVoiceMode(v!)),
          const Divider(),
          FutureBuilder<bool>(
            future: s.voice.wake.available,
            builder: (context, snap) {
              final ok = snap.data ?? false;
              return SwitchListTile(
                title: Text(t.wakeWord),
                subtitle: ok ? null : Text(t.wakeWordOff),
                value: s.settings.wakeWordEnabled && ok,
                onChanged: ok
                    ? (v) async {
                        await s.settings.setWakeWord(v);
                        v ? await s.bridge.startForegroundService() : await s.bridge.stopForegroundService();
                      }
                    : null,
              );
            },
          ),
        ]),
      ),
    );
  }
}
