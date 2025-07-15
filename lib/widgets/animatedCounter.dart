

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utilities/style.dart';

class AnimatedCounter extends ImplicitlyAnimatedWidget {
  final double count;
  final Widget Function(String, ThemeData) textWrapper;
  final String Function(double) doublePrinter;

  const AnimatedCounter({
    Key? key,
    required this.count,
    required Duration duration,
    Curve curve = Curves.linear,
    this.textWrapper = _plainText,
    this.doublePrinter = integerRepresentation,
  }) : super(duration: duration, curve: curve, key: key);

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() => _AnimatedCounterState();

  static Widget _plainText(String text, ThemeData theme) {
    return Text(text, style: theme.textTheme.bodyMedium);
  }

  static String integerRepresentation(double value) {
    return value.round().toString();
  }

  static String Function(double) toNDecimalPlaces(int n) {
    return (value) => value.toStringAsFixed(n);
  }
}

class _AnimatedCounterState extends AnimatedWidgetBaseState<AnimatedCounter> {
  Tween<dynamic> _count = Tween<double>(begin: 0.0);

  @override
  Widget build(BuildContext context) {
    return widget.textWrapper(widget.doublePrinter(_count.evaluate(animation)), Theme.of(context));
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _count = visitor(_count, widget.count, (dynamic value) => new Tween<double>(begin: value)) as Tween<dynamic>;
  }
}


class BigAnimatedCounter extends AnimatedCounter {
  static const Duration ONE_SECOND = Duration(seconds: 1);

  const BigAnimatedCounter({
    super.key,
    required super.count,
    super.curve = Curves.fastOutSlowIn,
    super.doublePrinter = AnimatedCounter.integerRepresentation,
  }) : super(duration: ONE_SECOND, textWrapper: _bigText);

  static Widget _bigText(String text, ThemeData theme) {
    return StyleComponents.paddingWrapper(StyleComponents.headlineTextWrapper(text, theme));
  }
}
