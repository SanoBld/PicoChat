# Porting map: Flutter -> Kotlin

One row per Kotlin file. Tick when the file is really implemented.

| Done | Kotlin file | Flutter source |
|---|---|---|
| [ ] | `data/model/ChatModels.kt` | `lib/models/chat_models.dart` |
| [ ] | `data/model/ModelModels.kt` | `lib/models/model_models.dart` |
| [ ] | `data/store/Prefs.kt` | `lib/app_state.dart, services/prefs.dart` |
| [ ] | `data/store/ChatStore.kt` | `lib/services/chat_store.dart` |
| [ ] | `data/store/MemoryStore.kt` | `lib/services/memory_store.dart` |
| [ ] | `data/store/ResetManager.kt` | `lib/services/reset.dart` |
| [ ] | `data/hf/HfService.kt` | `lib/services/hf_service.dart` |
| [ ] | `data/cloud/CloudProtocol.kt` | `lib/services/cloud/cloud_protocol.dart` |
| [ ] | `data/cloud/CloudEngine.kt` | `lib/services/cloud/cloud_engine.dart` |
| [ ] | `data/cloud/CloudStore.kt` | `lib/services/cloud/cloud_store.dart` |
| [ ] | `data/backup/BackupManager.kt` | `lib/services/backup.dart` |
| [ ] | `data/sync/SyncData.kt` | `lib/services/sync/sync_data.dart` |
| [ ] | `data/sync/SyncPrefs.kt` | `lib/services/sync/sync_prefs.dart` |
| [ ] | `data/sync/SyncService.kt` | `lib/services/sync/sync_service.dart` |
| [ ] | `engine/InferenceEngine.kt` | `lib/services/inference_engine.dart` |
| [ ] | `engine/LlamaEngine.kt` | `lib/services/llama_engine.dart` |
| [ ] | `domain/ChatService.kt` | `lib/services/chat_service.dart` |
| [ ] | `domain/CorePrompt.kt` | `lib/services/core_prompt.dart` |
| [ ] | `domain/AutoCommands.kt` | `lib/services/auto_commands.dart` |
| [ ] | `domain/Cards.kt` | `lib/services/cards.dart` |
| [ ] | `domain/WebSearch.kt` | `lib/services/web_search.dart, services/web_intent.dart` |
| [ ] | `domain/ImageLookup.kt` | `lib/services/image_lookup.dart` |
| [ ] | `domain/Attachments.kt` | `lib/services/attachments.dart` |
| [ ] | `domain/FileConvert.kt` | `lib/services/file_convert.dart` |
| [ ] | `domain/FileOutput.kt` | `lib/services/file_output.dart` |
| [ ] | `domain/ModelManager.kt` | `lib/services/model_manager.dart` |
| [ ] | `domain/MapService.kt` | `lib/services/map_service.dart` |
| [ ] | `domain/LocationService.kt` | `lib/services/location_service.dart` |
| [ ] | `domain/DeviceData.kt` | `lib/services/device_data.dart, services/device_info.dart` |
| [ ] | `domain/NotifService.kt` | `lib/services/notif_service.dart` |
| [ ] | `domain/BackgroundService.kt` | `lib/services/background_service.dart` |
| [ ] | `domain/Voice.kt` | `lib/services/voice.dart, services/sherpa_tts.dart` |
| [ ] | `domain/VoiceInput.kt` | `lib/services/voice_input.dart, services/sherpa_stt.dart` |
| [ ] | `domain/SherpaModels.kt` | `lib/services/sherpa_models.dart` |
| [ ] | `platform/DeviceBridge.kt` | `lib/android/.../DeviceBridge.kt` |
| [ ] | `platform/AssistBridge.kt` | `lib/android/.../AssistBridge.kt` |
| [ ] | `ui/theme/Theme.kt` | `lib/main.dart, screens/settings/appearance_page.dart` |
| [ ] | `ui/theme/Motion.kt` | `lib/theme/m3_motion.dart, theme/m3_interaction.dart` |
| [ ] | `ui/theme/Shapes.kt` | `lib/theme/m3_shapes.dart` |
| [ ] | `ui/components/M3Components.kt` | `lib/widgets/m3_components.dart, widgets/pc_segments.dart, widgets/pc_menu.dart` |
| [ ] | `ui/components/Skeleton.kt` | `lib/widgets/skeleton.dart` |
| [ ] | `ui/components/MarkdownLite.kt` | `lib/widgets/markdown_lite.dart` |
| [ ] | `ui/components/PicoFace.kt` | `lib/widgets/pico_face.dart, widgets/pico_avatar.dart` |
| [ ] | `ui/components/InfoCards.kt` | `lib/widgets/info_cards.dart, widgets/map_card.dart` |
| [ ] | `ui/components/ErrorCard.kt` | `lib/widgets/error_card.dart` |
| [ ] | `ui/components/ImageViewer.kt` | `lib/widgets/image_viewer.dart` |
| [ ] | `ui/components/ChatToolsSheet.kt` | `lib/widgets/chat_tools_sheet.dart` |
| [ ] | `ui/components/ImportMemorySheet.kt` | `lib/widgets/import_memory_sheet.dart` |
| [ ] | `ui/components/BrandIcon.kt` | `lib/widgets/brand_icon.dart` |
| [ ] | `ui/components/NetConsent.kt` | `lib/widgets/net_consent.dart` |
| [ ] | `ui/components/OpeningSplash.kt` | `lib/widgets/opening_splash.dart` |
| [ ] | `ui/components/AssistFx.kt` | `lib/widgets/assist_fx.dart` |
| [ ] | `ui/screens/intro/IntroScreen.kt` | `lib/screens/intro_screen.dart` |
| [ ] | `ui/screens/home/HomeScreen.kt` | `lib/screens/home_screen.dart` |
| [ ] | `ui/screens/home/Sidebar.kt` | `lib/screens/_sidebar.dart` |
| [ ] | `ui/screens/chat/ChatScreen.kt` | `lib/screens/_chat_view.dart` |
| [ ] | `ui/screens/chat/ChatViewModel.kt` | `lib/screens/_chat_view.dart` |
| [ ] | `ui/screens/models/ModelsScreen.kt` | `lib/screens/_models_page.dart` |
| [ ] | `ui/screens/models/CloudStoreTab.kt` | `lib/screens/cloud_store_tab.dart` |
| [ ] | `ui/screens/about/AboutScreen.kt` | `lib/screens/_about_page.dart` |
| [ ] | `ui/screens/voice/VoiceModeScreen.kt` | `lib/screens/voice_mode_screen.dart` |
| [ ] | `ui/screens/assist/AssistOverlay.kt` | `lib/screens/assist_overlay.dart` |
| [ ] | `ui/screens/settings/SettingsScreen.kt` | `lib/screens/_settings_page.dart` |
| [ ] | `ui/screens/settings/SettingsRows.kt` | `lib/screens/settings/settings_rows.dart, settings_helpers.dart` |
| [ ] | `ui/screens/settings/AppearancePage.kt` | `lib/screens/settings/appearance_page.dart` |
| [ ] | `ui/screens/settings/ChatSettingsPage.kt` | `lib/screens/settings/chat_settings_page.dart` |
| [ ] | `ui/screens/settings/CloudPage.kt` | `lib/screens/settings/cloud_page.dart` |
| [ ] | `ui/screens/settings/ContextPage.kt` | `lib/screens/settings/context_page.dart` |
| [ ] | `ui/screens/settings/HfPage.kt` | `lib/screens/settings/hf_page.dart` |
| [ ] | `ui/screens/settings/LanguagePage.kt` | `lib/screens/settings/language_page.dart` |
| [ ] | `ui/screens/settings/MemoryPage.kt` | `lib/screens/settings/memory_page.dart` |
| [ ] | `ui/screens/settings/PrivacyPage.kt` | `lib/screens/settings/privacy_page.dart` |
| [ ] | `ui/screens/settings/StoragePage.kt` | `lib/screens/settings/storage_page.dart` |
| [ ] | `ui/screens/settings/BackupPage.kt` | `lib/screens/settings/backup_page.dart` |
| [ ] | `ui/screens/settings/SyncPage.kt` | `lib/screens/settings/sync_page.dart, sync_widgets.dart` |
| [ ] | `ui/screens/settings/AssistantPage.kt` | `lib/screens/settings/assistant_page.dart` |
| [ ] | `ui/screens/settings/AccessSettingsPage.kt` | `lib/screens/settings/access_settings_page.dart` |
| [ ] | `ui/screens/settings/BackgroundPage.kt` | `lib/screens/settings/background_page.dart` |
| [ ] | `ui/screens/settings/VoiceModelsRows.kt` | `lib/screens/settings/voice_models_rows.dart` |
| [ ] | `l10n/Strings.kt` | `lib/l10n/l10n.dart` |
| [ ] | `l10n/SupportedLocales.kt` | `lib/supported_locales.dart` |
| [ ] | `util/Ids.kt` | `lib/models/chat_models.dart (newId)` |
