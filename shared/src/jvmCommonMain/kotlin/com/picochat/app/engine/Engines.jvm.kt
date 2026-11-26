package com.picochat.app.engine

actual fun createEngine(): InferenceEngine = LlamaEngine()
