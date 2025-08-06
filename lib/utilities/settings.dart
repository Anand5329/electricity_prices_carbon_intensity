import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class Settings {
  static const String defaultPostcode = "N1";
  static const String saveFilePath = "postcodeCache.txt";
  static late File _preferredPostcodeFile;
  static bool isInit = false;

  Settings() {
    if (!isInit) {
      _setupAsync();
    }
  }

  static Future<void> _setupAsync() async {
    if (!kIsWeb && !isInit) {
      Directory docDir = await getApplicationDocumentsDirectory();
      _preferredPostcodeFile = File("${docDir.path}/$saveFilePath");
    }
    isInit = true;
  }

  Future<File?> savePostcode(String postcode) async {
    if (kIsWeb) {
      return null;
    }
    await _setupAsync();
    try {
      return await _preferredPostcodeFile.writeAsString(postcode);
    } catch (e) {
      logger.e("Error encountered while saving postcode: $e");
      return _preferredPostcodeFile;
    }
  }

  Future<String> readSavedPostcode() async {
    if (kIsWeb) {
      return defaultPostcode;
    }
    await _setupAsync();
    try {
      return await _preferredPostcodeFile.readAsString();
    } catch (e) {
      logger.e("Error encountered while reading saved postcode: $e");
      return defaultPostcode;
    }
  }
}
