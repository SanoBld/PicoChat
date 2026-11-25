// JNI bridge to llama.cpp. Phase 1: only reports the CPU features, to prove the build works.
// Phase 2 adds load / generate / stop / unload (see LlamaBridge.kt).
#include <jni.h>
#include "llama.h"

extern "C" JNIEXPORT jstring JNICALL
Java_com_picochat_llama_LlamaBridge_systemInfo(JNIEnv *env, jobject /*thiz*/) {
    return env->NewStringUTF(llama_print_system_info());
}
