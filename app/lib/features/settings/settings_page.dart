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
          const Divider(),
          const _BackendSection(),
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


class _BackendSection extends StatefulWidget {
  const _BackendSection();

  @override
  State<_BackendSection> createState() => _BackendSectionState();
}

class _BackendSectionState extends State<_BackendSection> {
  late final TextEditingController _url;
  late final TextEditingController _code;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final st = ServicesScope.of(context).settings;
    _url = TextEditingController(text: st.backendUrl);
    _code = TextEditingController(text: st.registrationCode);
  }

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save(Services s) async {
    await s.settings.setBackend(_url.text, _code.text);
    await s.auth.clearToken(); // new address / code -> register again
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = ServicesScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.backendSection, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: t.backendUrl, hintText: 'http://192.168.0.10:8000', border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          obscureText: true,
          decoration: InputDecoration(labelText: t.registrationCode, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(children: [
          FilledButton(
            onPressed: () async {
              await _save(s);
              messenger.showSnackBar(SnackBar(content: Text(t.saved)));
            },
            child: Text(t.save),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () async {
              await _save(s);
              final ok = await s.backend.health();
              messenger.showSnackBar(SnackBar(content: Text(ok ? t.connectionOk : t.connectionFailed)));
            },
            child: Text(t.testConnection),
          ),
        ]),
      ]),
    );
  }
}
