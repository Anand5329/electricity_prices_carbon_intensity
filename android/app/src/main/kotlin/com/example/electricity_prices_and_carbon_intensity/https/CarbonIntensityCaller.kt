package com.example.electricity_prices_and_carbon_intensity.https

import io.ktor.client.call.body
import io.ktor.client.statement.HttpResponse
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.Serializable

import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalTime
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.format
import kotlinx.datetime.format.*


@Serializable
data class IntensityData(val forecast: Int, val actual: Int, val index: String)

@Serializable
data class PeriodData(val from: String, val to: String, val intensity: IntensityData)

@Serializable
data class ResponseData(val data: List<PeriodData>)

class CarbonIntensityCaller : ApiCaller(BASE_URL) {

    suspend fun getCurrentIntensity(): IntensityData {
        val response: HttpResponse = get("$INTENSITY/")
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
        val response: HttpResponse = get("$INTENSITY/date/${date.format(DATE_FORMATTER)}/")
        return if (!isValidResponse(response)) {
            listOf()
        } else {
            parseIntensityAndTime(response)
        }
    }

    suspend fun getIntensityFrom(
        from: LocalDateTime,
        modifier: FromModifier = FromModifier.NONE,
        to: LocalDateTime? = null
    ): List<PeriodData> {
        val modifyString: String = when (modifier) {
            FromModifier.FORWARD_24 -> "fw24h/"
            FromModifier.FORWARD_48 -> "fw48h/"
            FromModifier.PAST_24 -> "pt24h/"
            FromModifier.TO -> (to
                ?: throw IllegalArgumentException("Please supply a valid to date time")).format(
                DATE_TIME_FORMATTER
            ).toString() + "/"

            FromModifier.NONE -> ""
        }
        val response: HttpResponse =
            get("$INTENSITY/${from.format(DATE_TIME_FORMATTER)}/$modifyString")
        return if (!isValidResponse(response)) {
            listOf()
        } else {
            parseIntensityAndTime(response)
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
        const val INTENSITY: String = "intensity"
        val DATE_FORMATTER = LocalDate.Format { date(LocalDate.Formats.ISO) }
        val DATE_TIME_FORMATTER = LocalDateTime.Format {
            date(LocalDate.Formats.ISO)
            char('T')
            hour(); char(':'); minute()
            char('Z')
        }
    }
}

enum class FromModifier {
    NONE,
    FORWARD_24,
    FORWARD_48,
    PAST_24,
    TO
}

fun main() {
    val ci = runBlocking { CarbonIntensityCaller().getCurrentIntensity() }
    println(ci)
}