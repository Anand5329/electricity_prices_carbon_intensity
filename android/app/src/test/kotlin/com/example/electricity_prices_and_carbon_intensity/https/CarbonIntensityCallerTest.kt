package dev.green.anand.electricity_prices_and_carbon_intensity.https

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.*
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import org.junit.Test
import kotlin.time.ExperimentalTime
import org.slf4j.LoggerFactory


class CarbonIntensityCallerTest {

    var testClient: CarbonIntensityCaller = CarbonIntensityCaller()
    val logger = LoggerFactory.getLogger(CarbonIntensityCallerTest.Companion::class.java)

    @Test
    @org.junit.jupiter.api.Test
    fun getCurrentIntensity() {
        val intensityData: IntensityData? = runBlocking { testClient?.getCurrentIntensity() }
        assertTrue(intensityData != null)
    }

    @Test
    @org.junit.jupiter.api.Test
    fun getIntensityForDateInPast() {
        val date: LocalDate = LocalDate(2023, 3, 9)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityForDate(date) }

        assertTrue(periodData.size == 24 * 2)
    }

    @Test
    @org.junit.jupiter.api.Test
    fun getIntensityFromSingle() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date) }

        assertTrue(periodData.size == 1)
    }

    @OptIn(ExperimentalTime::class)
    @Test
    @org.junit.jupiter.api.Test
    fun getIntensityFromForward24() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date, FromModifier.FORWARD_24) }

        assertTrue(periodData.size == 48, "expected 48 was ${periodData.size}")

        val start = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.get(0).to).toInstant(
            TIMEZONE)
        val end = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.last().to).toInstant(
            TIMEZONE)
        assertTrue(start > date.toInstant(TIMEZONE))
        assertTrue(end > start)
        assertTrue(end.minus(start).inWholeHours == 23L)
    }

    @OptIn(ExperimentalTime::class)
    @Test
    @org.junit.jupiter.api.Test
    fun getIntensityFromForward48() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date, FromModifier.FORWARD_48) }

        assertTrue(periodData.size == 96, "expected 96 was ${periodData.size}")

        val start = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.get(0).to).toInstant(
            TIMEZONE)
        val end = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.last().to).toInstant(
            TIMEZONE)
        assertTrue(start > date.toInstant(TIMEZONE))
        assertTrue(end > start)
        assertTrue(end.minus(start).inWholeHours == 47L)
    }

    @OptIn(ExperimentalTime::class)
    @Test
    @org.junit.jupiter.api.Test
    fun getIntensityFromPast24() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date, FromModifier.PAST_24) }

        assertTrue(periodData.size == 48, "expected 48 was ${periodData.size}")

        val start = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.get(0).from).toInstant(
            TIMEZONE)
        val end = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.last().from).toInstant(
            TIMEZONE)
        assertTrue(start < date.toInstant(TIMEZONE))
        assertTrue(end > start)
        assertTrue(end.minus(start).inWholeHours == 23L)
    }

    @Test
    @org.junit.jupiter.api.Test
    fun getIntensityFromTo() {
        val from = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val to = LocalDateTime(2023, 3, 9, 19, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(from, FromModifier.TO, to) }

        assertTrue(periodData.size == 6)
    }

    companion object {
        val TIMEZONE = TimeZone.UTC
    }
}