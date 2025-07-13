package com.example.electricity_prices_and_carbon_intensity

import android.util.Log
import com.example.electricity_prices_and_carbon_intensity.https.CarbonIntensityCaller
import com.example.electricity_prices_and_carbon_intensity.https.IntensityData
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking

class MainActivity : FlutterActivity() {
    private val CHANNEL_NAME = "carbon_intensity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor, CHANNEL_NAME)
        channel.setMethodCallHandler(MainActivity::channelHandler)
    }

    companion object {
        const val TAG = "MainActivity.channel"
        private fun channelHandler(call: MethodCall, result: Result) {
            if (call.method == "getCarbonIntensity") {
                var caller: CarbonIntensityCaller? = null
                try {
                    caller = CarbonIntensityCaller()
                    val ci: IntensityData = runBlocking { caller!!.getCurrentIntensity() }
                    caller!!.close()
                    result.success(ci.actual?: ci.forecast?: -1)
                } catch (e: Exception) {
                    Log.v(TAG, e.message!!, e)
                } finally {
                    caller?.close()
                    result.notImplemented()
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
