// JNI bridge to llama.cpp (pinned at tag b6000, see CMakeLists).
// Strings that may hold emoji / non-BMP characters travel as UTF-8 byte arrays: JNI's own
// string functions use "modified UTF-8" and would corrupt them.
#include <jni.h>

#include <algorithm>
#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "llama.h"

namespace {

struct Handle {
    llama_model *model = nullptr;
    llama_context *ctx = nullptr;
    int n_ctx = 0;
    std::atomic<bool> stop{false};
};

std::once_flag g_backend_once;

std::string to_string(JNIEnv *env, jbyteArray arr) {
    if (!arr) return {};
    jsize n = env->GetArrayLength(arr);
    std::string s(static_cast<size_t>(n), '\0');
    if (n > 0) env->GetByteArrayRegion(arr, 0, n, reinterpret_cast<jbyte *>(&s[0]));
    return s;
}

jbyteArray to_bytes(JNIEnv *env, const std::string &s) {
    jbyteArray arr = env->NewByteArray(static_cast<jsize>(s.size()));
    if (arr && !s.empty()) env->SetByteArrayRegion(arr, 0, static_cast<jsize>(s.size()), reinterpret_cast<const jbyte *>(s.data()));
    return arr;
}

void throw_java(JNIEnv *env, const char *cls, const std::string &msg) {
    jclass c = env->FindClass(cls);
    if (c) env->ThrowNew(c, msg.c_str());
}

// Length of the longest prefix of s that does not end in the middle of a UTF-8 character.
size_t valid_utf8_prefix(const std::string &s) {
    size_t n = s.size();
    if (n == 0) return 0;
    size_t i = n;
    int back = 0;
    while (i > 0 && back < 4) {
        unsigned char c = static_cast<unsigned char>(s[i - 1]);
        if ((c & 0xC0) == 0x80) {
            i--;
            back++;
            continue;
        }
        size_t need = (c >= 0xF0) ? 4 : (c >= 0xE0) ? 3 : (c >= 0xC0) ? 2 : 1;
        size_t have = n - (i - 1);
        return have >= need ? n : i - 1;
    }
    return n;
}

}  // namespace

extern "C" {

JNIEXPORT jstring JNICALL Java_com_picochat_llama_LlamaBridge_systemInfo(JNIEnv *env, jclass) {
    return env->NewStringUTF(llama_print_system_info());
}

JNIEXPORT jlong JNICALL Java_com_picochat_llama_LlamaBridge_nativeLoad(JNIEnv *env, jclass, jbyteArray path, jint contextSize, jint threads) {
    std::call_once(g_backend_once, [] { llama_backend_init(); });
    std::string p = to_string(env, path);

    llama_model_params mp = llama_model_default_params();
    llama_model *model = llama_model_load_from_file(p.c_str(), mp);
    if (!model) {
        throw_java(env, "java/lang/IllegalStateException", "Could not load the model file");
        return 0;
    }
    llama_context_params cp = llama_context_default_params();
    cp.n_ctx = static_cast<uint32_t>(contextSize);
    cp.n_batch = 512;
    int t = threads > 0 ? threads : std::max(2, static_cast<int>(std::thread::hardware_concurrency()) / 2);
    cp.n_threads = t;
    cp.n_threads_batch = t;
    llama_context *ctx = llama_init_from_model(model, cp);
    if (!ctx) {
        llama_model_free(model);
        throw_java(env, "java/lang/IllegalStateException", "Not enough memory for this context size");
        return 0;
    }
    auto *h = new Handle();
    h->model = model;
    h->ctx = ctx;
    h->n_ctx = static_cast<int>(llama_n_ctx(ctx));
    return reinterpret_cast<jlong>(h);
}

JNIEXPORT void JNICALL Java_com_picochat_llama_LlamaBridge_nativeStop(JNIEnv *, jclass, jlong handle) {
    if (handle) reinterpret_cast<Handle *>(handle)->stop = true;
}

JNIEXPORT void JNICALL Java_com_picochat_llama_LlamaBridge_nativeFree(JNIEnv *, jclass, jlong handle) {
    auto *h = reinterpret_cast<Handle *>(handle);
    if (!h) return;
    if (h->ctx) llama_free(h->ctx);
    if (h->model) llama_model_free(h->model);
    delete h;
}

// callback.onToken(bytes): returns false to stop.
JNIEXPORT void JNICALL Java_com_picochat_llama_LlamaBridge_nativeGenerate(
    JNIEnv *env, jclass, jlong handle, jobjectArray roles, jobjectArray contents, jfloat temperature, jint maxTokens, jobject callback) {
    auto *h = reinterpret_cast<Handle *>(handle);
    if (!h) {
        throw_java(env, "java/lang/IllegalStateException", "No model loaded");
        return;
    }
    h->stop = false;

    jclass cbClass = env->GetObjectClass(callback);
    jmethodID onToken = env->GetMethodID(cbClass, "onToken", "([B)Z");
    if (!onToken) {
        throw_java(env, "java/lang/IllegalStateException", "Bad callback");
        return;
    }

    // ---- build the prompt with the model's own chat template
    const jsize n_msgs = env->GetArrayLength(contents);
    std::vector<std::string> role_s, content_s;
    for (jsize i = 0; i < n_msgs; i++) {
        auto r = static_cast<jstring>(env->GetObjectArrayElement(roles, i));
        const char *rc = env->GetStringUTFChars(r, nullptr);
        role_s.emplace_back(rc);
        env->ReleaseStringUTFChars(r, rc);
        env->DeleteLocalRef(r);
        auto c = static_cast<jbyteArray>(env->GetObjectArrayElement(contents, i));
        content_s.push_back(to_string(env, c));
        env->DeleteLocalRef(c);
    }
    std::vector<llama_chat_message> msgs(static_cast<size_t>(n_msgs));
    for (jsize i = 0; i < n_msgs; i++) msgs[i] = {role_s[i].c_str(), content_s[i].c_str()};

    const char *tmpl = llama_model_chat_template(h->model, nullptr);
    if (!tmpl) tmpl = "chatml";
    std::vector<char> buf(8192);
    int len = llama_chat_apply_template(tmpl, msgs.data(), msgs.size(), true, buf.data(), static_cast<int32_t>(buf.size()));
    if (len > static_cast<int>(buf.size())) {
        buf.resize(static_cast<size_t>(len));
        len = llama_chat_apply_template(tmpl, msgs.data(), msgs.size(), true, buf.data(), static_cast<int32_t>(buf.size()));
    }
    if (len < 0) {
        throw_java(env, "java/lang/IllegalStateException", "Chat template not supported by this model");
        return;
    }
    std::string prompt(buf.data(), static_cast<size_t>(len));

    // ---- tokenize
    const llama_vocab *vocab = llama_model_get_vocab(h->model);
    int n_prompt = -llama_tokenize(vocab, prompt.c_str(), static_cast<int32_t>(prompt.size()), nullptr, 0, true, true);
    if (n_prompt <= 0) {
        throw_java(env, "java/lang/IllegalStateException", "Tokenization failed");
        return;
    }
    if (n_prompt >= h->n_ctx - 8) {
        throw_java(env, "java/lang/IllegalStateException", "The conversation is too long for the context size");
        return;
    }
    std::vector<llama_token> tokens(static_cast<size_t>(n_prompt));
    if (llama_tokenize(vocab, prompt.c_str(), static_cast<int32_t>(prompt.size()), tokens.data(), n_prompt, true, true) < 0) {
        throw_java(env, "java/lang/IllegalStateException", "Tokenization failed");
        return;
    }

    // ---- fresh context (the whole history is re-sent every turn)
    llama_memory_clear(llama_get_memory(h->ctx), true);

    // ---- sampler
    llama_sampler *smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    if (temperature <= 0.01f) {
        llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40));
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.95f, 1));
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
    }

    std::string error;
    // ---- read the prompt in chunks
    const int n_batch = 512;
    for (int i = 0; i < n_prompt && error.empty() && !h->stop; i += n_batch) {
        int n = std::min(n_batch, n_prompt - i);
        llama_batch b = llama_batch_get_one(tokens.data() + i, n);
        if (llama_decode(h->ctx, b) != 0) error = "Decoding failed while reading the prompt";
    }

    // ---- generate
    std::string pending;
    int n_past = n_prompt;
    int produced = 0;
    while (error.empty() && !h->stop && produced < maxTokens && n_past < h->n_ctx - 1) {
        llama_token tok = llama_sampler_sample(smpl, h->ctx, -1);
        if (llama_vocab_is_eog(vocab, tok)) break;

        char piece[256];
        int n = llama_token_to_piece(vocab, tok, piece, sizeof(piece), 0, true);
        if (n > 0) pending.append(piece, static_cast<size_t>(n));
        size_t ok = valid_utf8_prefix(pending);
        if (ok > 0) {
            jbyteArray arr = to_bytes(env, pending.substr(0, ok));
            jboolean go = env->CallBooleanMethod(callback, onToken, arr);
            env->DeleteLocalRef(arr);
            pending.erase(0, ok);
            if (env->ExceptionCheck() || !go) break;
        }
        produced++;

        llama_batch b = llama_batch_get_one(&tok, 1);
        if (llama_decode(h->ctx, b) != 0) {
            error = "Decoding failed";
            break;
        }
        n_past++;
    }
    llama_sampler_free(smpl);
    if (!error.empty() && !env->ExceptionCheck()) throw_java(env, "java/lang/IllegalStateException", error);
}

}  // extern "C"
