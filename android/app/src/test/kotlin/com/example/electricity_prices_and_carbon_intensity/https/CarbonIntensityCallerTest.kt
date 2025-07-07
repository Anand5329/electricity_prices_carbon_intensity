package com.example.electricity_prices_and_carbon_intensity.https

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.*
import kotlinx.datetime.LocalDate
import kotlinx.datetime.LocalDateTime
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toInstant
import kotlin.time.ExperimentalTime


class CarbonIntensityCallerTest {

    var testClient: CarbonIntensityCaller = CarbonIntensityCaller()

    @org.junit.jupiter.api.Test
    fun getCurrentIntensity() {
        val intensityData: IntensityData? = runBlocking { testClient?.getCurrentIntensity() }
        assertTrue(intensityData != null)
    }

    @org.junit.jupiter.api.Test
    fun getIntensityForDateInPast() {
        val date: LocalDate = LocalDate(2023, 3, 9)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityForDate(date) }

        assertTrue(periodData.size == 24 * 2)
    }

    @org.junit.jupiter.api.Test
    fun getIntensityFromSingle() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date) }

        assertTrue(periodData.size == 1)
    }

    @OptIn(ExperimentalTime::class)
    @org.junit.jupiter.api.Test
    fun getIntensityFromForward24() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date, FromModifier.FORWARD_24) }

        assertTrue(periodData.size == 48)

        val start = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.get(0).from).toInstant(
            TIMEZONE)
        val end = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.last().from).toInstant(
            TIMEZONE)
        assertTrue(start > date.toInstant(TIMEZONE))
        assertTrue(end > start)
        assertTrue(end.minus(start).inWholeHours == 23L)
    }

    @OptIn(ExperimentalTime::class)
    @org.junit.jupiter.api.Test
    fun getIntensityFromForward48() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date, FromModifier.FORWARD_48) }

        assertTrue(periodData.size == 96)

        val start = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.get(0).from).toInstant(
            TIMEZONE)
        val end = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.last().from).toInstant(
            TIMEZONE)
        assertTrue(start > date.toInstant(TIMEZONE))
        assertTrue(end > start)
        assertTrue(end.minus(start).inWholeHours == 47L)
    }

    @OptIn(ExperimentalTime::class)
    @org.junit.jupiter.api.Test
    fun getIntensityFromPast24() {
        val date = LocalDateTime(2023, 3, 9, 16, 20, 0, 0)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityFrom(date, FromModifier.PAST_24) }

        assertTrue(periodData.size == 48)

        val start = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.get(0).from).toInstant(
            TIMEZONE)
        val end = CarbonIntensityCaller.DATE_TIME_FORMATTER.parse(periodData.last().from).toInstant(
            TIMEZONE)
        assertTrue(start < date.toInstant(TIMEZONE))
        assertTrue(end > start)
        assertTrue(end.minus(start).inWholeHours == 23L)
    }

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