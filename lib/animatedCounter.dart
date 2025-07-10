

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AnimatedCounter extends ImplicitlyAnimatedWidget {
  final int count;
  final Widget Function(String, ThemeData) textWrapper;

  const AnimatedCounter({
    Key? key,
    required this.count,
    required Duration duration,
    Curve curve = Curves.linear,
    this.textWrapper = _plainText
  }) : super(duration: duration, curve: curve, key: key);

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() => _AnimatedCounterState();

  static Widget _plainText(String text, ThemeData theme) {
    return Text(text, style: theme.textTheme.bodyMedium);
  }
}

class _AnimatedCounterState extends AnimatedWidgetBaseState<AnimatedCounter> {
  IntTween _count = IntTween(begin: 0);


  @override
  Widget build(BuildContext context) {
    return widget.textWrapper(_count.evaluate(animation).toString(), Theme.of(context));
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _count = visitor(_count, widget.count, (dynamic value) => new IntTween(begin: value)) as IntTween;
  }
}