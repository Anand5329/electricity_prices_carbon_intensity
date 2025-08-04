import 'dart:async';
import 'dart:io';

import 'package:electricity_prices_and_carbon_intensity/widgets/regionaldata.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../utilities/style.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class SettingsPage extends StatefulWidget {
  static const String saveFilePath = "postcodeCache.txt";
  const SettingsPage();
  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final File _preferredPostcodeFile;
  final _postcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupAsync();
  }

  @override
  void dispose() {
    _postcodeController.dispose();
    super.dispose();
  }

  Future<void> _setupAsync() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    _preferredPostcodeFile = File(
      "${docDir.path}/${SettingsPage.saveFilePath}",
    );
    _refreshTextField();
  }

  Future<File> _savePostcode(String postcode) async {
    try {
      return await _preferredPostcodeFile.writeAsString(postcode);
    } catch (e) {
      logger.e("Error encountered while saving postcode: $e");
      return _preferredPostcodeFile;
    }
  }

  Future<void> _save() async {
    String postcode = _postcodeController.text;
    if (postcode.isNotEmpty) {
      await _savePostcode(postcode);
    }
  }

  Future<String?> _readSavedPostcode() async {
    try {
      return await _preferredPostcodeFile.readAsString();
    } catch (e) {
      logger.e("Error encountered while reading saved postcode: $e");
      return null;
    }
  }

  Future<void> _refreshTextField() async {
    String? savedPostcode = await _readSavedPostcode();
    if (savedPostcode != null) {
      _postcodeController.text = savedPostcode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = StyleComponents(Theme.of(context));
    return ListView(
      children: [
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: StyleComponents.paddingWrapper(
                TextField(
                  controller: _postcodeController,
                  decoration: InputDecoration(
                    hintText: 'Enter an outer postcode (e.g. NW5)',
                    labelText: "Default Postcode",
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            TextButton(
              style: style.simpleButtonStyle(),
              child: Icon(Icons.save),
              onPressed: _save,
            ),
          ],
        ),
      ],
    );
  }
}
