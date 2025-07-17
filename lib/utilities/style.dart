import 'package:flutter/material.dart';

class StyleComponents {
  static const TextStyle smallText = const TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
  );


  final ThemeData _theme;

  StyleComponents(this._theme);

  Widget headlineTextWithPadding(String text) {
    return paddingWrapper(headlineTextWrapper(text, _theme));
  }

  ButtonStyle simpleButtonStyle() {
    return ButtonStyle(
      textStyle: WidgetStateProperty.all(_theme.textTheme.displaySmall),
      foregroundColor: WidgetStateProperty.all(_theme.colorScheme.primary),
      backgroundColor: WidgetStateProperty.all(
        _theme.colorScheme.inversePrimary,
      ),
    );
  }

  static Widget headlineTextWrapper(String text, ThemeData theme) {
    final textStyle = theme.textTheme.displayLarge!.copyWith(
      color: theme.colorScheme.primary,
    );
    return Text(text, style: textStyle);
  }

  static Widget paddingWrapper(Widget inner) {
    return Padding(padding: const EdgeInsets.all(8.0), child: inner);
  }
}
