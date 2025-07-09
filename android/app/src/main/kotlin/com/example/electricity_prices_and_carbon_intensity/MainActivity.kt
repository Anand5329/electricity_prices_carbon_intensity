package com.example.electricity_prices_and_carbon_intensity

import android.util.Log
import com.example.electricity_prices_and_carbon_intensity.https.CarbonIntensityCaller
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
    private fun channelHandler(call: MethodCall, result: Result) {
      if (call.method == "getCarbonIntensity") {
        val ci = runBlocking { CarbonIntensityCaller().getCurrentIntensity() }
        Log.v("MainActivity.channelHandler", "here $ci")
        result.success(ci.actual)
      } else {
         result.notImplemented()
      }
    }
  }
}
