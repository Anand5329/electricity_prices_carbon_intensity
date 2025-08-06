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
    _refreshTextField();
  }

  Future<void> _save() async {
    String postcode = _postcodeController.text;
    if (postcode.isNotEmpty) {
      await settings.savePostcode(postcode);
    }
  }

  Future<void> _refreshTextField() async {
    String savedPostcode = await settings.readSavedPostcode();
    _postcodeController.text = savedPostcode;
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
