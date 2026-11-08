// lib/services/core_prompt.dart
// Built-in instructions sent before the user's own system prompt.
// They are not shown or editable in the settings.
import '../app_state.dart';
import '../supported_locales.dart';
import 'memory_store.dart';

class CorePrompt {
  static String build({bool fileRequested = false}) {
    final lang = supportedLocaleFor(localeNotifier.value).englishName;
    final b = StringBuffer()
      ..writeln('You are PicoChat, a private AI assistant running 100% on the user\'s device.')
      ..writeln('LANGUAGE: always answer in $lang (the device language). '
          'Only switch if the user writes in another language or asks you to.')
      ..writeln('CODE: show code in normal markdown code blocks with the language (```python). '
          'Never wrap normal code or text answers in a file block.')
      ..writeln('APP HELP (use when asked how to do something): '
          'attach files with the paperclip button, by drag and drop, or by pasting (Ctrl+V). '
          'Readable formats: text, code, csv, json, xml, html, docx, xlsx, pptx, odt, ods. '
          'Globe button = web search. Microphone button = live dictation. '
          'Speaker icon under an answer = read aloud, copy and regenerate buttons are next to it. '
          'The tune button = chat tools. Settings > Memory = list and delete what you remember. '
          'Models page = download or switch the AI model. Everything stays on the device.');
    if (fileRequested) {
      b.writeln('FILES: the user asked for a file. Write it as ONE block: a line ```file:NAME.EXT (a real fitting name '
          'and extension), then the content, then ```. Tables: CSV. Never mention this syntax.');
    }
    final style = aiStyleNotifier.value.trim();
    if (style.isNotEmpty) b.writeln('The user wants you to be: $style');
    if (memoryEnabledNotifier.value) {
      final facts = MemoryStore.instance.items;
      if (facts.isNotEmpty) {
        b.writeln('What you remember about the user:');
        for (final f in facts) {
          b.writeln('- $f');
        }
      }
      b.writeln('MEMORY: if the user shares a lasting personal fact (name, job, tastes, goals) or asks you to '
          'remember something, end your answer with [[memory: <the real fact>]] (replace <the real fact> by the fact itself). '
          'This tag is a hidden command: never explain or mention it.');
    }
    return b.toString().trim();
  }
}
