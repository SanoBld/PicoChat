package com.picochat.app.engine

/** llama.cpp is not linked on iOS yet (see native/ios/README.md): the demo engine answers. */
actual fun createEngine(): InferenceEngine = PlaceholderEngine()
