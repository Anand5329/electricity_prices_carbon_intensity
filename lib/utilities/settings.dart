import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class Settings {
  static const String defaultPostcode = "N1";
  static const String savePostcodeFilePath = "postcodeCache.txt";
  static const String saveApiKeyFilePath = "apiKeyCache.txt";

  static late Directory _docDir;

  static late SharedPreferences prefs;
  static bool isInit = false;

  Settings() {
    if (!isInit) {
      _setupAsync();
    }
  }

  static Future<void> _setupAsync() async {
    if (!kIsWeb && !isInit) {
      _docDir = await getApplicationDocumentsDirectory();
    } else if (kIsWeb && !isInit) {
      prefs = await SharedPreferences.getInstance();
    }
    isInit = true;
  }

  Future<void> savePostcode(String postcode) async {
    try {
      return _saveString(SaveKeys.postcode, postcode);
    } catch (e) {
      logger.e("Error encountered while saving postcode to disk: $e");
    }
  }

  Future<String> readSavedPostcode() async {
    try {
      String postcode = await _readSavedString(
        SaveKeys.postcode,
        defaultStr: defaultPostcode,
      );
      return postcode;
    } catch (e) {
      logger.e("Error encountered while reading postcode from disk: $e");
      return defaultPostcode;
    }
  }

  Future<void> saveApiKey(String apiKey) async {
    try {
      return _saveString(SaveKeys.apiKey, apiKey);
    } catch (e) {
      logger.e("Error encountered while saving API Key to disk: $e");
    }
  }

  Future<String> readSavedApiKey() async {
    try {
      String apiKey = await _readSavedString(SaveKeys.apiKey, defaultStr: "");
      if (apiKey.isEmpty) {
        throw InvalidApiKeyError();
      }
      return apiKey;
    } catch (e) {
      logger.e("Error encountered while reading API Key from disk: $e");
      rethrow;
    }
  }

  Future<void> _saveString(SaveKeys key, String saveStr) async {
    await _setupAsync();
    if (kIsWeb) {
      prefs.setString(key.key, saveStr);
      return;
    }
    File saveTo = File("${_docDir.path}/${key.filepath}");
    try {
      await saveTo.writeAsString(saveStr);
    } catch (e) {
      logger.e("Error encountered while saving string to disk: $e");
    }
  }

  Future<String> _readSavedString(SaveKeys key, {String? defaultStr}) async {
    await _setupAsync();
    if (kIsWeb) {
      try {
        String? saved = prefs.getString(key.key);
        if (saved != null) {
          return saved;
        }
      } catch (e) {
        logger.e("Error encountered while reading from saved preferences: $e");
      }
      if (defaultStr == null) {
        throw UnsupportedError("No valid default string passed");
      }
      return defaultStr;
    }

    File savedTo = File("${_docDir.path}/${key.filepath}");
    try {
      return await savedTo.readAsString();
    } catch (e) {
      logger.e("Error encountered while reading saved string: $e");
      if (defaultStr == null) {
        throw UnsupportedError("No valid default string passed");
      }
      return defaultStr;
    }
  }
}

class InvalidApiKeyError extends Error {}

enum SaveKeys {
  postcode("postcode", Settings.savePostcodeFilePath),
  apiKey("apiKey", Settings.saveApiKeyFilePath);

  final String key;
  final String filepath;

  const SaveKeys(this.key, this.filepath);
}
