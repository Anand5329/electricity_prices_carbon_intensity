package com.example.electricity_prices_and_carbon_intensity.https

import io.ktor.client.call.body
import io.ktor.client.statement.HttpResponse
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable

@Serializable
data class IntensityData(val forecast: Int, val actual: Int, val index: String)

@Serializable
data class PeriodData(val from: String, val to: String, val intensity: IntensityData)

@Serializable
data class ResponseData(val data: List<PeriodData>)

class CarbonIntensityCaller: ApiCaller(BASE_URL) {

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