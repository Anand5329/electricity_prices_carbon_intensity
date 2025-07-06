package com.example.electricity_prices_and_carbon_intensity.https

import io.ktor.client.*
import io.ktor.client.engine.cio.*
import io.ktor.client.request.get
import io.ktor.client.statement.HttpResponse
import kotlinx.coroutines.runBlocking
import java.io.Closeable

import io.ktor.client.call.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.plugins.logging.Logging
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
data class IntensityData(val forecast: Int, val actual: Int, val index: String)

@Serializable
data class PeriodData(val from: String, val to: String, val intensity: IntensityData)

@Serializable
data class ResponseData(val data: List<PeriodData>)

class CarbonIntensityCaller: Closeable {
    
    private val client = HttpClient(CIO) {
        install(ContentNegotiation) {
            json(Json {
                prettyPrint = true
                isLenient = true
            })
        }
        install(Logging)
    }

    suspend fun getCurrentIntensity(): IntensityData {
        val response: HttpResponse = get("intensity/")
        var intensity: IntensityData? = null
        if (isValidResponse(response)) {
            intensity = parseIntensity(response)
        }
        if (intensity == null) {
            throw Error("No intensity found")
        }
        return intensity
    }

    private suspend fun parseIntensity(response: HttpResponse): IntensityData? {
        val data: ResponseData = response.body()
        if (data.data.isNotEmpty()) {
            return data.data[0].intensity
        } else {
            return null
        }
    }

    private suspend fun get(endpoint: String): HttpResponse {
        return client.get(BASE_URL + endpoint)
    }

    private fun isValidResponse(response: HttpResponse): Boolean {
        return response.status.value in 200..299
    }

    override fun close() {
        client.close()
    }

    protected fun finalize() {
        client.close()
    }

    companion object {
        const val BASE_URL: String = "https://api.carbonintensity.org.uk/"
    }
}

fun main() = runBlocking {
    val ci = CarbonIntensityCaller()
    val response = ci.getCurrentIntensity()
    println(response)
    ci.close()
}