// lib/models/model_models.dart
// Data classes for AI models: installed files, Hugging Face results and
// the hand-picked suggestions.

/// Extracts the quantisation tag (Q4_K_M, Q8_0, F16…) from a GGUF file name.
String quantOf(String fileName) {
  final m = RegExp(r'(I?Q\d(?:_[A-Z0-9]+)*|BF16|F16|F32)', caseSensitive: false)
      .allMatches(fileName)
      .toList();
  return m.isEmpty ? '' : m.last.group(0)!.toUpperCase();
}

/// Human-readable size: 1.2 GB, 640 MB…
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i >= 3 ? 1 : 0)} ${units[i]}';
}

/// A fully downloaded model file, ready to use.
class InstalledModel {
  final String id; // "<repo>/<fileName>" or "local/<fileName>"
  final String repo;
  final String fileName;
  final String path;
  final int sizeBytes;
  final DateTime addedAt;

  const InstalledModel({
    required this.id,
    required this.repo,
    required this.fileName,
    required this.path,
    required this.sizeBytes,
    required this.addedAt,
  });

  /// "Qwen2.5-0.5B-Instruct" from "Qwen/Qwen2.5-0.5B-Instruct-GGUF".
  String get displayName {
    final base = repo.contains('/') ? repo.split('/').last : repo;
    final clean = base.replaceAll(RegExp(r'[-_ ]?GGUF$', caseSensitive: false), '');
    if (repo == 'local' || clean.isEmpty) {
      return fileName.replaceAll(RegExp(r'\.gguf$', caseSensitive: false), '');
    }
    return clean;
  }

  String get quant => quantOf(fileName);
  bool get isLocalImport => repo == 'local';

  Map<String, dynamic> toJson() => {
        'id': id,
        'repo': repo,
        'fileName': fileName,
        'path': path,
        'sizeBytes': sizeBytes,
        'addedAt': addedAt.toIso8601String(),
      };

  factory InstalledModel.fromJson(Map<String, dynamic> j) => InstalledModel(
        id: j['id'] as String,
        repo: (j['repo'] as String?) ?? 'local',
        fileName: j['fileName'] as String,
        path: j['path'] as String,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.tryParse((j['addedAt'] as String?) ?? '') ?? DateTime.now(),
      );
}

/// One repository returned by the Hugging Face search API.
class HfModelSummary {
  final String id; // "author/name"
  final int downloads;
  final int likes;
  final bool gated;

  const HfModelSummary({
    required this.id,
    required this.downloads,
    required this.likes,
    required this.gated,
  });

  String get author => id.contains('/') ? id.split('/').first : '';
  String get name => id.contains('/') ? id.substring(id.indexOf('/') + 1) : id;

  factory HfModelSummary.fromJson(Map<String, dynamic> j) => HfModelSummary(
        id: (j['id'] ?? j['modelId'] ?? '') as String,
        downloads: (j['downloads'] as num?)?.toInt() ?? 0,
        likes: (j['likes'] as num?)?.toInt() ?? 0,
        gated: j['gated'] != null && j['gated'] != false,
      );
}

/// One downloadable .gguf file inside a repository.
class HfFileInfo {
  final String path;
  final int size;
  const HfFileInfo({required this.path, required this.size});
  String get quant => quantOf(path);
}

/// Hand-picked small models. Only the repo id is hard-coded: the file list
/// and sizes are fetched from Hugging Face when the person taps Download.
class RecommendedModel {
  final String repo;
  final String title;
  final String params;
  final int approxMb; // size of the default Q4 file, display only
  final String blurbKey; // l10n key
  final int minRamGb; // RAM needed to run it comfortably
  final bool vision; // can read images (a projector file is offered)
  final List<String> tags; // l10n keys of the feature chips
  final String maker; // who made it
  final int ctxK; // context window, in thousands of tokens
  final Map<String, String> about; // long description per language (fr / en)
  const RecommendedModel({
    required this.repo,
    required this.title,
    required this.params,
    required this.approxMb,
    required this.blurbKey,
    this.minRamGb = 4,
    this.vision = false,
    this.tags = const [],
    this.maker = '',
    this.ctxK = 8,
    this.about = const {},
  });

  String aboutFor(String lang) => about[lang] ?? about['en'] ?? '';
}

const List<RecommendedModel> kRecommendedModels = [
  RecommendedModel(repo: 'unsloth/Qwen3-0.6B-GGUF', title: 'Qwen3 0.6B', params: '0.6B', approxMb: 400, blurbKey: 'rec_tiny', minRamGb: 2, maker: 'Alibaba', ctxK: 32, about: {'fr': "Très petit et très rapide : idéal pour les vieux téléphones ou les tâches simples (reformuler, résumer, répondre court). Mode réflexion disponible.", 'en': "Tiny and very fast: ideal for older phones and simple tasks (rewrite, summarize, short answers). Thinking mode available."}, tags: ['tag_fast', 'tag_thinking']),
  RecommendedModel(repo: 'unsloth/gemma-3-1b-it-GGUF', title: 'Gemma 3 1B', params: '1B', approxMb: 810, blurbKey: 'rec_fast', minRamGb: 3, maker: 'Google', ctxK: 32, about: {'fr': "Le petit modèle de Google : rapide, bon en français et dans de nombreuses langues. Texte uniquement.", 'en': "Google's small model: fast and good in many languages. Text only."}, tags: ['tag_fast', 'tag_multi']),
  RecommendedModel(repo: 'ggml-org/SmolVLM2-2.2B-Instruct-GGUF', title: 'SmolVLM2 2.2B', params: '2.2B', approxMb: 1800, blurbKey: 'rec_vision_small', minRamGb: 4, vision: true, maker: 'Hugging Face', ctxK: 8, about: {'fr': "Comprend les images : photos, captures d'écran, documents. Léger pour un modèle vision.", 'en': "Understands images: photos, screenshots, documents. Light for a vision model."}, tags: ['tag_vision']),
  RecommendedModel(repo: 'unsloth/Qwen3-1.7B-GGUF', title: 'Qwen3 1.7B', params: '1.7B', approxMb: 1110, blurbKey: 'rec_balanced', minRamGb: 4, maker: 'Alibaba', ctxK: 32, about: {'fr': "Bon équilibre vitesse / qualité. Raisonne mieux que les modèles de 1B et reste fluide sur mobile.", 'en': "Good speed / quality balance. Reasons better than 1B models and stays smooth on mobile."}, tags: ['tag_thinking', 'tag_multi']),
  RecommendedModel(repo: 'bartowski/Llama-3.2-3B-Instruct-GGUF', title: 'Llama 3.2 3B', params: '3B', approxMb: 2020, blurbKey: 'rec_reliable', minRamGb: 6, maker: 'Meta', ctxK: 128, about: {'fr': "Fiable pour la conversation de tous les jours, avec un très grand contexte (longs documents).", 'en': "Reliable for everyday chat, with a very large context (long documents)."}, tags: ['tag_multi']),
  RecommendedModel(repo: 'unsloth/Qwen3-4B-Instruct-2507-GGUF', title: 'Qwen3 4B 2507', params: '4B', approxMb: 2500, blurbKey: 'rec_smart', minRamGb: 6, maker: 'Alibaba', ctxK: 32, about: {'fr': "Très intelligent pour sa taille, solide en code et en raisonnement. Le meilleur choix pour un téléphone récent.", 'en': "Very smart for its size, strong at code and reasoning. Best pick for a recent phone."}, tags: ['tag_multi', 'tag_code']),
  RecommendedModel(repo: 'ggml-org/gemma-3-4b-it-GGUF', title: 'Gemma 3 4B Vision', params: '4B', approxMb: 2500, blurbKey: 'rec_vision', minRamGb: 6, vision: true, maker: 'Google', ctxK: 128, about: {'fr': "Voit les images et comprend de nombreuses langues. Bon pour décrire une photo ou lire un document.", 'en': "Sees images and understands many languages. Good for describing a photo or reading a document."}, tags: ['tag_vision', 'tag_multi']),
  RecommendedModel(repo: 'ggml-org/gemma-4-E2B-it-GGUF', title: 'Gemma 4 E2B', params: '2B', approxMb: 3430, blurbKey: 'rec_best', minRamGb: 8, maker: 'Google', ctxK: 128, about: {'fr': "Dernière génération de Google : très bonne qualité pour sa taille, multilingue.", 'en': "Google's latest generation: very good quality for its size, multilingual."}, tags: ['tag_multi']),
  RecommendedModel(repo: 'unsloth/Qwen3-8B-GGUF', title: 'Qwen3 8B', params: '8B', approxMb: 5030, blurbKey: 'rec_pc', minRamGb: 12, maker: 'Alibaba', ctxK: 32, about: {'fr': "Le plus puissant de la liste : réponses détaillées, code et raisonnement avancés. Pour PC ou téléphones très costauds.", 'en': "The most powerful in the list: detailed answers, advanced code and reasoning. For PCs or very strong phones."}, tags: ['tag_thinking', 'tag_code']),
];
