import 'package:flutter/material.dart';

class StyleComponents {
  static const TextStyle smallText = const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle centerText = const TextStyle(fontSize: 10);

  static const List<Color> defaultColors = const [
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.red,
    Colors.black,
  ];
  static const List<double> defaultStops = [0, 100, 200, 300, 500];
  static const List<double> defaultFractionStops = [0, 0.2, 0.4, 0.6, 1];
  static const LinearGradient defaultGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: defaultColors,
    stops: defaultFractionStops,
  );

  static const List<Color> energyColors = const [
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.red,
  ];
  static const List<double> energyStops = [0, 0.3, 0.6, 1];
  static const LinearGradient energyGradient = LinearGradient(
    colors: energyColors,
    stops: energyStops,
  );

  static Color? lerp(Gradient gradient, double t) {
    // return lerpGradient(gradient.colors, gradient.stops!, t);// this is used in fl_chart to render.
    final colors = gradient.colors;
    final stops = gradient.stops!;
    for (var s = 0; s < stops.length - 1; s++) {
      final leftStop = stops[s], rightStop = stops[s + 1];
      final leftColor = colors[s], rightColor = colors[s + 1];
      if (t <= leftStop) {
        return leftColor;
      } else if (t < rightStop) {
        final sectionT = (t - leftStop) / (rightStop - leftStop);
        return Color.lerp(leftColor, rightColor, sectionT);
      }
    }
    return colors.last;
  }

  final ThemeData _theme;

  StyleComponents(this._theme);

  Widget headlineTextWithPadding(String text) {
    return paddingWrapper(headlineTextWrapper(text, _theme));
  }

  Widget subHeadingTextWithPadding(String text) {
    return paddingWrapper(subHeadingTextWrapper(text, _theme));
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

  LinearGradient shimmerGradient() {
    return LinearGradient(
      colors: [
        _theme.colorScheme.surfaceDim,
        _theme.colorScheme.surfaceBright,
        _theme.colorScheme.surfaceContainer,
      ],
      stops: [0.1, 0.3, 0.4],
      begin: Alignment(-1.0, -0.3),
      end: Alignment(1.0, 0.3),
      tileMode: TileMode.clamp,
    );
  }

  Widget getInvalidApiKeyWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.warning),
        const SizedBox(height: 24),
        Text("Please input a valid API key on the Settings page"),
      ],
    );
  }

  static Widget headlineTextWrapper(String text, ThemeData theme) {
    final textStyle = theme.textTheme.displayLarge!.copyWith(
      color: theme.colorScheme.primary,
    );
    return Text(text, style: textStyle);
  }

  static Widget subHeadingTextWrapper(String text, ThemeData theme) {
    final textStyle = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.primary,
    );
    return Text(text, style: textStyle);
  }

  static Widget paddingWrapper(Widget inner) {
    return Padding(padding: const EdgeInsets.all(8.0), child: inner);
  }

  static Widget pagePaddingWrapper(Widget inner) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      child: inner,
    );
  }
}
