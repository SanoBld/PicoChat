# Porting map: Flutter -> Kotlin

One row per Kotlin file. Tick when the file is really implemented.

| Done | Kotlin file | Flutter source |
|---|---|---|
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/model/ChatModels.kt` | `lib/models/chat_models.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/model/ModelModels.kt` | `lib/models/model_models.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/store/Prefs.kt` | `lib/app_state.dart, services/prefs.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/store/ChatStore.kt` | `lib/services/chat_store.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/store/MemoryStore.kt` | `lib/services/memory_store.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/store/ResetManager.kt` | `lib/services/reset.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/hf/HfService.kt` | `lib/services/hf_service.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/cloud/CloudProtocol.kt` | `lib/services/cloud/cloud_protocol.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/cloud/CloudEngine.kt` | `lib/services/cloud/cloud_engine.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/cloud/CloudStore.kt` | `lib/services/cloud/cloud_store.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/backup/BackupManager.kt` | `lib/services/backup.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/sync/SyncData.kt` | `lib/services/sync/sync_data.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/sync/SyncPrefs.kt` | `lib/services/sync/sync_prefs.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/data/sync/SyncService.kt` | `lib/services/sync/sync_service.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/engine/InferenceEngine.kt` | `lib/services/inference_engine.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/engine/LlamaEngine.kt` | `lib/services/llama_engine.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/ChatService.kt` | `lib/services/chat_service.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/CorePrompt.kt` | `lib/services/core_prompt.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/AutoCommands.kt` | `lib/services/auto_commands.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/Cards.kt` | `lib/services/cards.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/WebSearch.kt` | `lib/services/web_search.dart, services/web_intent.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/ImageLookup.kt` | `lib/services/image_lookup.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/Attachments.kt` | `lib/services/attachments.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/FileConvert.kt` | `lib/services/file_convert.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/FileOutput.kt` | `lib/services/file_output.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/ModelManager.kt` | `lib/services/model_manager.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/MapService.kt` | `lib/services/map_service.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/LocationService.kt` | `lib/services/location_service.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/DeviceData.kt` | `lib/services/device_data.dart, services/device_info.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/NotifService.kt` | `lib/services/notif_service.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/BackgroundService.kt` | `lib/services/background_service.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/Voice.kt` | `lib/services/voice.dart, services/sherpa_tts.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/VoiceInput.kt` | `lib/services/voice_input.dart, services/sherpa_stt.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/domain/SherpaModels.kt` | `lib/services/sherpa_models.dart` |
| [ ] | `shared/src/androidMain/kotlin/com/picochat/app/platform/DeviceBridge.kt` | `lib/android/.../DeviceBridge.kt` |
| [ ] | `shared/src/androidMain/kotlin/com/picochat/app/platform/AssistBridge.kt` | `lib/android/.../AssistBridge.kt` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/theme/Theme.kt` | `lib/main.dart, screens/settings/appearance_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/theme/Motion.kt` | `lib/theme/m3_motion.dart, theme/m3_interaction.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/theme/Shapes.kt` | `lib/theme/m3_shapes.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/M3Components.kt` | `lib/widgets/m3_components.dart, widgets/pc_segments.dart, widgets/pc_menu.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/Skeleton.kt` | `lib/widgets/skeleton.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/MarkdownLite.kt` | `lib/widgets/markdown_lite.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/PicoFace.kt` | `lib/widgets/pico_face.dart, widgets/pico_avatar.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/InfoCards.kt` | `lib/widgets/info_cards.dart, widgets/map_card.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/ErrorCard.kt` | `lib/widgets/error_card.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/ImageViewer.kt` | `lib/widgets/image_viewer.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/ChatToolsSheet.kt` | `lib/widgets/chat_tools_sheet.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/ImportMemorySheet.kt` | `lib/widgets/import_memory_sheet.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/BrandIcon.kt` | `lib/widgets/brand_icon.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/NetConsent.kt` | `lib/widgets/net_consent.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/OpeningSplash.kt` | `lib/widgets/opening_splash.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/components/AssistFx.kt` | `lib/widgets/assist_fx.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/intro/IntroScreen.kt` | `lib/screens/intro_screen.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/home/HomeScreen.kt` | `lib/screens/home_screen.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/home/Sidebar.kt` | `lib/screens/_sidebar.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/chat/ChatScreen.kt` | `lib/screens/_chat_view.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/chat/ChatViewModel.kt` | `lib/screens/_chat_view.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/models/ModelsScreen.kt` | `lib/screens/_models_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/models/CloudStoreTab.kt` | `lib/screens/cloud_store_tab.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/about/AboutScreen.kt` | `lib/screens/_about_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/voice/VoiceModeScreen.kt` | `lib/screens/voice_mode_screen.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/assist/AssistOverlay.kt` | `lib/screens/assist_overlay.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/SettingsScreen.kt` | `lib/screens/_settings_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/SettingsRows.kt` | `lib/screens/settings/settings_rows.dart, settings_helpers.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/AppearancePage.kt` | `lib/screens/settings/appearance_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/ChatSettingsPage.kt` | `lib/screens/settings/chat_settings_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/CloudPage.kt` | `lib/screens/settings/cloud_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/ContextPage.kt` | `lib/screens/settings/context_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/HfPage.kt` | `lib/screens/settings/hf_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/LanguagePage.kt` | `lib/screens/settings/language_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/MemoryPage.kt` | `lib/screens/settings/memory_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/PrivacyPage.kt` | `lib/screens/settings/privacy_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/StoragePage.kt` | `lib/screens/settings/storage_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/BackupPage.kt` | `lib/screens/settings/backup_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/SyncPage.kt` | `lib/screens/settings/sync_page.dart, sync_widgets.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/AssistantPage.kt` | `lib/screens/settings/assistant_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/AccessSettingsPage.kt` | `lib/screens/settings/access_settings_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/BackgroundPage.kt` | `lib/screens/settings/background_page.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/ui/screens/settings/VoiceModelsRows.kt` | `lib/screens/settings/voice_models_rows.dart` |
| [ ] | `l10n/Strings.kt` | `shared/src/commonMain/kotlin/com/picochat/app/lib/l10n/l10n.dart` |
| [ ] | `l10n/SupportedLocales.kt` | `shared/src/commonMain/kotlin/com/picochat/app/lib/supported_locales.dart` |
| [ ] | `shared/src/commonMain/kotlin/com/picochat/app/util/Ids.kt` | `lib/models/chat_models.dart (newId)` |
