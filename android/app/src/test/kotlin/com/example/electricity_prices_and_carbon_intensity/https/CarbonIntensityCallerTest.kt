package com.example.electricity_prices_and_carbon_intensity.https

import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.*

class CarbonIntensityCallerTest {

    var testClient: CarbonIntensityCaller = CarbonIntensityCaller()

    @org.junit.jupiter.api.Test
    fun getCurrentIntensity() {
        val intensityData: IntensityData? = runBlocking { testClient?.getCurrentIntensity() }
        assertTrue(intensityData != null)
    }
}