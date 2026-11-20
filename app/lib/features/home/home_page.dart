import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/di.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../voice/voice_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _cmd = TextEditingController();

  @override
  void dispose() {
    _cmd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final voice = ServicesScope.of(context).voice;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.appName),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings'))],
      ),
      body: ListenableBuilder(
        listenable: voice,
        builder: (context, _) {
          final busy = voice.state == VoiceState.processing || voice.state == VoiceState.speaking;
          final listening = voice.state == VoiceState.listening;
          final status = switch (voice.state) {
            VoiceState.listening => t.listening,
            VoiceState.processing => t.processing,
            VoiceState.speaking => t.speaking,
            _ => t.idle,
          };
          final hint = switch (voice.message) {
            'mic' => t.micDenied,
            'nospeech' => t.noSpeech,
            'stt' => t.sttUnavailable,
            _ => null,
          };
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              children: [
                Text(t.homeTitle, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(status, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(voice.transcript, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                ),
                if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(hint)),
                SizedBox(
                  width: 96,
                  height: 96,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                    onPressed: busy ? voice.cancel : voice.toggle,
                    child: Icon(busy ? Icons.stop : (listening ? Icons.hearing : Icons.mic), size: 44),
                  ),
                ),
                const SizedBox(height: 8),
                Text(t.tapToTalk),
                const SizedBox(height: 16),
                // Same path as speech: handy for testing the phone-control layer without talking.
                TextField(
                  controller: _cmd,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: t.typeCommand,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        voice.runText(_cmd.text);
                        _cmd.clear();
                      },
                    ),
                  ),
                  onSubmitted: (v) {
                    voice.runText(v);
                    _cmd.clear();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
