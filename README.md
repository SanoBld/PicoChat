# PicoChat

Private AI chat that runs 100% on your device. ChatGPT / Gemini / Claude-style
interface; models are downloaded from [Hugging Face](https://huggingface.co)
(GGUF files) and stay on your device. No account, no cloud, no tracking.

Same design system and project layout as LastStats (Material 3 expressive,
adaptive sidebar/drawer layout).

## Status

This is the **base project**: UI, settings, intro, Hugging Face search and
resumable downloads, chat history and CI/CD are done. Answers come from a real
on-device engine: llama.cpp through the [`llamadart`](https://pub.dev/packages/llamadart)
package (`lib/services/llama_engine.dart`). The web build keeps a demo engine.

## Cloud AI (optional)

Off by default. Settings > Cloud AI: add an account for Claude (Anthropic),
Gemini (Google), ChatGPT (OpenAI) or any OpenAI-compatible server (Mistral,
DeepSeek, Groq, OpenRouter, Ollama, LM Studio...) with your own API key, fetch
the model list from the service, then pick a cloud model in the chat header or
in Models. Cloud answers use the same pipeline as local ones (files, memory,
web results, steps, stop button). Settings > Cloud AI > Context chooses what is
sent along with the messages (memory, date, location, files, web, phone data,
history length). Protocol code: `lib/services/cloud/` (tested in
`test/cloud_protocol_test.dart`).

## Layout

```
lib/
  main.dart, app_state.dart, supported_locales.dart
  l10n/        strings_en|fr|es|de.dart + l10n.dart (tr('key'))
  theme/       m3_interaction, m3_motion, m3_shapes
  widgets/     m3_components, skeleton, markdown_lite, title bar, ...
  models/      chat_models, model_models
  services/    hf_service, model_manager, chat_store, chat_service, inference_engine, llama_engine
  screens/     intro_screen, home_screen (+ sidebar, chat, models, settings, about)
    settings/  appearance, chat, hugging face, language, storage, privacy
android/ ios/ macos/ linux/ windows/ web/   platform projects
.github/workflows/  build-android|ios|linux|macos|windows|all, release
```

## Add a language

1. Copy `lib/l10n/strings_en.dart` to `strings_xx.dart`, translate the values.
2. Register it in `lib/l10n/l10n.dart`.
3. Add one line in `lib/supported_locales.dart`.

## First run

```
flutter create . --project-name picochat   # only if a platform folder is missing
flutter pub get
flutter run
```

Android release and debug builds share the committed `android/debug.keystore`
so every APK has the same signature (same approach as LastStats).
