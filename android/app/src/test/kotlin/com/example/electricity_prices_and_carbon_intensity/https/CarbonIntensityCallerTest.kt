package com.example.electricity_prices_and_carbon_intensity.https

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.*
import java.time.LocalDate

class CarbonIntensityCallerTest {

    var testClient: CarbonIntensityCaller = CarbonIntensityCaller()

    @org.junit.jupiter.api.Test
    fun getCurrentIntensity() {
        val intensityData: IntensityData? = runBlocking { testClient?.getCurrentIntensity() }
        assertTrue(intensityData != null)
    }

    @org.junit.jupiter.api.Test
    fun getIntensityForDateInPast() {
        val date: LocalDate = LocalDate.of(2023, 3, 9)
        val periodData: List<PeriodData> = runBlocking { testClient.getIntensityForDate(date) }

        assertTrue(periodData.size == 24 * 2)
    }
}