package com.picochat.app.util

import io.ktor.client.HttpClient
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.UserAgent

/** Two shared HTTP clients: one for short API calls, one for big downloads (redirects handled by hand). */
object Http {
    val api: HttpClient = HttpClient {
        install(UserAgent) { agent = "PicoChat" }
        install(HttpTimeout) {
            connectTimeoutMillis = 15_000
            requestTimeoutMillis = 25_000
        }
    }

    val download: HttpClient = HttpClient {
        followRedirects = false
        install(UserAgent) { agent = "PicoChat" }
        install(HttpTimeout) {
            connectTimeoutMillis = 20_000
            socketTimeoutMillis = 60_000
        }
    }
}
