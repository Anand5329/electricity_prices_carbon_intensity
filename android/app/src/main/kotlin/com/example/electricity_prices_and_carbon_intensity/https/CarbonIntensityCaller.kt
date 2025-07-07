package com.example.electricity_prices_and_carbon_intensity.https

import io.ktor.client.call.body
import io.ktor.client.statement.HttpResponse
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable

import java.time.LocalDate
import java.time.format.DateTimeFormatter


@Serializable
data class IntensityData(val forecast: Int, val actual: Int, val index: String)

@Serializable
data class PeriodData(val from: String, val to: String, val intensity: IntensityData)

@Serializable
data class ResponseData(val data: List<PeriodData>)

class CarbonIntensityCaller: ApiCaller(BASE_URL) {

    suspend fun getCurrentIntensity(): IntensityData {
        val response: HttpResponse = get("intensity/")
        var intensity: List<IntensityData> = listOf()
        if (isValidResponse(response)) {
            intensity = parseIntensity(response)
        }
        if (intensity.isEmpty()) {
            throw Error("No intensity found")
        }
        return intensity.get(0)
    }

    suspend fun getIntensityForDate(date: LocalDate): List<PeriodData> {
        val response: HttpResponse = get("intensity/date/${date.format(DATE_FORMATTER)}")
        if (!isValidResponse(response)) {
            return listOf()
        } else {
            return parseIntensityAndTime(response)
        }
    }

    private suspend fun parseIntensity(response: HttpResponse): List<IntensityData> {
        return parseIntensityFromPeriod(parseIntensityAndTime(response))
    }

    private suspend fun parseIntensityFromPeriod(periods: List<PeriodData>): List<IntensityData> {
        return periods.map { it.intensity }
    }

    private suspend fun parseIntensityAndTime(response: HttpResponse): List<PeriodData> {
        val data: ResponseData = response.body()
        return data.data
    }

    companion object {
        const val BASE_URL: String = "https://api.carbonintensity.org.uk/"
        val DATE_FORMATTER: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    }
}

fun main() = runBlocking {
    val ci = CarbonIntensityCaller()
    val response = ci.getCurrentIntensity()
    println(response)
    ci.close()
}