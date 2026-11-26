package com.picochat.app.data.model

/** A model suggested in the store. */
data class RecommendedModel(
    val repo: String,
    val title: String,
    val params: String,
    /** Size of the default Q4 file, display only. */
    val approxMb: Int,
    /** Translation key of the one-line description. */
    val blurbKey: String,
    /** RAM needed to run it comfortably. */
    val minRamGb: Int = 4,
    /** Can read images (a projector file is offered). */
    val vision: Boolean = false,
    val maker: String = "",
    /** Context window in thousands of tokens. */
    val ctxK: Int = 8,
    /** Long description per language (fr / en). */
    val about: Map<String, String> = emptyMap(),
    /** Translation keys of the feature chips. */
    val tags: List<String> = emptyList(),
)

val recommendedModels: List<RecommendedModel> = listOf(
    RecommendedModel(repo = "unsloth/Qwen3-0.6B-GGUF", title = "Qwen3 0.6B", params = "0.6B", approxMb = 400, blurbKey = "rec_tiny", minRamGb = 2, vision = false, maker = "Alibaba", ctxK = 32, about = mapOf("fr" to "Très petit et très rapide : idéal pour les vieux téléphones ou les tâches simples (reformuler, résumer, répondre court). Mode réflexion disponible.", "en" to "Tiny and very fast: ideal for older phones and simple tasks (rewrite, summarize, short answers). Thinking mode available."), tags = listOf("tag_fast", "tag_thinking")),
    RecommendedModel(repo = "unsloth/gemma-3-1b-it-GGUF", title = "Gemma 3 1B", params = "1B", approxMb = 810, blurbKey = "rec_fast", minRamGb = 3, vision = false, maker = "Google", ctxK = 32, about = mapOf("fr" to "Le petit modèle de Google : rapide, bon en français et dans de nombreuses langues. Texte uniquement.", "en" to "Google's small model: fast and good in many languages. Text only."), tags = listOf("tag_fast", "tag_multi")),
    RecommendedModel(repo = "ggml-org/SmolVLM2-2.2B-Instruct-GGUF", title = "SmolVLM2 2.2B", params = "2.2B", approxMb = 1800, blurbKey = "rec_vision_small", minRamGb = 4, vision = true, maker = "Hugging Face", ctxK = 8, about = mapOf("fr" to "Comprend les images : photos, captures d'écran, documents. Léger pour un modèle vision.", "en" to "Understands images: photos, screenshots, documents. Light for a vision model."), tags = listOf("tag_vision")),
    RecommendedModel(repo = "unsloth/Qwen3-1.7B-GGUF", title = "Qwen3 1.7B", params = "1.7B", approxMb = 1110, blurbKey = "rec_balanced", minRamGb = 4, vision = false, maker = "Alibaba", ctxK = 32, about = mapOf("fr" to "Bon équilibre vitesse / qualité. Raisonne mieux que les modèles de 1B et reste fluide sur mobile.", "en" to "Good speed / quality balance. Reasons better than 1B models and stays smooth on mobile."), tags = listOf("tag_thinking", "tag_multi")),
    RecommendedModel(repo = "bartowski/Llama-3.2-3B-Instruct-GGUF", title = "Llama 3.2 3B", params = "3B", approxMb = 2020, blurbKey = "rec_reliable", minRamGb = 6, vision = false, maker = "Meta", ctxK = 128, about = mapOf("fr" to "Fiable pour la conversation de tous les jours, avec un très grand contexte (longs documents).", "en" to "Reliable for everyday chat, with a very large context (long documents)."), tags = listOf("tag_multi")),
    RecommendedModel(repo = "unsloth/Qwen3-4B-Instruct-2507-GGUF", title = "Qwen3 4B 2507", params = "4B", approxMb = 2500, blurbKey = "rec_smart", minRamGb = 6, vision = false, maker = "Alibaba", ctxK = 32, about = mapOf("fr" to "Très intelligent pour sa taille, solide en code et en raisonnement. Le meilleur choix pour un téléphone récent.", "en" to "Very smart for its size, strong at code and reasoning. Best pick for a recent phone."), tags = listOf("tag_multi", "tag_code")),
    RecommendedModel(repo = "ggml-org/gemma-3-4b-it-GGUF", title = "Gemma 3 4B Vision", params = "4B", approxMb = 2500, blurbKey = "rec_vision", minRamGb = 6, vision = true, maker = "Google", ctxK = 128, about = mapOf("fr" to "Voit les images et comprend de nombreuses langues. Bon pour décrire une photo ou lire un document.", "en" to "Sees images and understands many languages. Good for describing a photo or reading a document."), tags = listOf("tag_vision", "tag_multi")),
    RecommendedModel(repo = "ggml-org/gemma-4-E2B-it-GGUF", title = "Gemma 4 E2B", params = "2B", approxMb = 3430, blurbKey = "rec_best", minRamGb = 8, vision = false, maker = "Google", ctxK = 128, about = mapOf("fr" to "Dernière génération de Google : très bonne qualité pour sa taille, multilingue.", "en" to "Google's latest generation: very good quality for its size, multilingual."), tags = listOf("tag_multi")),
    RecommendedModel(repo = "unsloth/Qwen3-8B-GGUF", title = "Qwen3 8B", params = "8B", approxMb = 5030, blurbKey = "rec_pc", minRamGb = 12, vision = false, maker = "Alibaba", ctxK = 32, about = mapOf("fr" to "Le plus puissant de la liste : réponses détaillées, code et raisonnement avancés. Pour PC ou téléphones très costauds.", "en" to "The most powerful in the list: detailed answers, advanced code and reasoning. For PCs or very strong phones."), tags = listOf("tag_thinking", "tag_code")),
)
