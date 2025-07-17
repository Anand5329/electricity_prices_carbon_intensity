import 'dart:async';
import 'package:flutter/services.dart';

class NativeAdapter {
  const NativeAdapter();

  static const platform = MethodChannel('carbon_intensity');

  static Future<int> updateCarbonIntensity() async {
    try {
      final int result = await platform.invokeMethod("getCarbonIntensity");
      // final int result = 0;
      return result;
    } on PlatformException catch (e) {
      print("Error:${e.message!}");
      return -1;
    }
  }
}
