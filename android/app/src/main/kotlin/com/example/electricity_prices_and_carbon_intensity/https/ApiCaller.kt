package com.example.electricity_prices_and_carbon_intensity.https

import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.request.get
import io.ktor.client.statement.HttpResponse
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import java.io.Closeable

open class ApiCaller(val baseUrl: String): Closeable {

    private val client = HttpClient(CIO) {
        install(ContentNegotiation) {
            json(Json {
                prettyPrint = true
                isLenient = true
            })
        }
        install(Logging)
    }

    suspend fun get(endpoint: String): HttpResponse {
        return client.get(baseUrl + endpoint)
    }

    fun isValidResponse(response: HttpResponse): Boolean {
        return response.status.value in VALID_RANGE
    }

    override fun close() {
        client.close()
    }

    protected fun finalize() {
        client.close()
    }

    companion object {
        val VALID_RANGE = 200..299
    }
}