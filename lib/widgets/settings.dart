import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../utilities/settings.dart';
import '../utilities/style.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class SettingsPage extends StatefulWidget {
  const SettingsPage();
  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Settings settings = Settings();
  final _postcodeController = TextEditingController();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupAsync();
  }

  @override
  void dispose() {
    _postcodeController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _setupAsync() async {
    _refreshTextFields();
  }

  Future<void> _save() async {
    String postcode = _postcodeController.text;
    if (postcode.isNotEmpty) {
      await settings.savePostcode(postcode);
    }

    String apiKey = _apiKeyController.text;
    if (apiKey.isNotEmpty) {
      await settings.saveApiKey(apiKey);
    }
  }

  Future<void> _refreshTextFields() async {
    String savedPostcode = await settings.readSavedPostcode();
    _postcodeController.text = savedPostcode;

    String savedApiKey = "";
    try {
      savedApiKey = await settings.readSavedApiKey();
    } on InvalidApiKeyError {
      logger.d("API Key not initialised");
    } catch (e) {
      logger.e("Error reading API Key: $e");
    }
    _apiKeyController.text = savedApiKey;
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
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: StyleComponents.paddingWrapper(
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    hintText: 'Enter your Octopus Agile API key',
                    labelText: "Octopus API Key",
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: StyleComponents.paddingWrapper(
                TextButton(
                  style: style.simpleButtonStyle(),
                  onPressed: _save,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save),
                      const SizedBox(width: 12),
                      Text("Save", style: StyleComponents.smallText),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
