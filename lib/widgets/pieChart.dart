import 'package:electricity_prices_and_carbon_intensity/utilities/generationMixApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'chart.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

abstract class PieChartGeneratorFactory<T> {
  static const Color defaultTouchColor = Colors.black;
  static const Map<EnergySource, Color> colorMap = const <EnergySource, Color>{
    EnergySource.coal: Colors.black,
    EnergySource.biomass: Colors.brown,
    EnergySource.nuclear: Colors.lightBlue,
    EnergySource.other: Colors.blueGrey,
    EnergySource.gas: Colors.red,
    EnergySource.hydro: Colors.indigo,
    EnergySource.imports: Colors.purple,
    EnergySource.wind: Colors.lightGreen,
    EnergySource.solar: Colors.yellow,
  };

  final void Function(VoidCallback) setStateFn;
  late Color backgroundColor;
  late ThemeData theme;

  final TextStyle textStyle;

  int touchedIndex = -1;

  PieChartGeneratorFactory(
    this.setStateFn, {
    this.textStyle = StyleComponents.smallText,
  });

  Widget Function(BuildContext, DeviceSize) getChartGenerator();

  PieChart getChart(
    Map<T, double> data,
    Map<T, Color> colorMap,
    DeviceSize size,
  ) {
    return PieChart(getChartData(data, colorMap, size));
  }

  PieChartData getChartData(
    Map<T, double> data,
    Map<T, Color> colorMap,
    DeviceSize size,
  ) {
    final touchData = _getTouchData();
    return PieChartData(
      sections: getPieSectionsData(data, colorMap: colorMap),
      centerSpaceRadius: double.infinity,
      centerSpaceColor: backgroundColor,
      pieTouchData: touchData,
      borderData: FlBorderData(show: false),
    );
  }

  PieTouchData _getTouchData() {
    return PieTouchData(
      enabled: true,
      touchCallback: (FlTouchEvent event, pieTouchResponse) {
        setStateFn(() {
          if (!event.isInterestedForInteractions ||
              pieTouchResponse == null ||
              pieTouchResponse.touchedSection == null) {
            touchedIndex = -1;
            return;
          }
          touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
        });
      },
    );
  }

  List<PieChartSectionData> getPieSectionsData(
    Map<T, double> chartValues, {
    required Map<T, Color> colorMap,
  }) {
    List<PieChartSectionData> sections = [];
    List<T> keys = chartValues.keys.toList();
    for (var i = 0; i < chartValues.length; i++) {
      double radius = 120;
      double fontSize = 16;
      T factor = keys[i];
      String title = factor.toString();
      if (touchedIndex == i) {
        radius = 150;
        fontSize = 20;
        title =
            "${factor.toString()}\n${chartValues[factor]!.toStringAsFixed(2)}%";
      }
      sections.add(
        PieChartSectionData(
          value: chartValues[factor],
          title: title,
          color: colorMap[factor],
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
          radius: radius,
        ),
      );
    }
    return sections;
  }

  List<Widget> generateLegend({required Map colorMap}) {
    return colorMap.keys
        .map(
          (src) => <Widget>[
            Indicator(
              color: colorMap[src]!,
              text: src.toString(),
              isSquare: true,
              textColor: theme.colorScheme.primary,
            ),
          ],
        )
        .reduce((srcs1, srcs2) {
          List<Widget> newSrcs = List.from(srcs1);
          newSrcs.add(SizedBox(height: 4));
          newSrcs.addAll(srcs2);
          return newSrcs;
        });
  }

  static Map<EnergySource, Color> getDefaultColorMap({
    GenerationMix? genMix,
    LinearGradient gradient = StyleComponents.energyGradient,
  }) {
    double accumulator = 0;
    genMix ??= GenerationMix.uniform;
    Map<EnergySource, double> percMap = genMix.toMap();
    return Map.fromEntries(
      EnergySource.values.map((source) {
        accumulator += percMap[source]! / 100;
        return MapEntry(source, StyleComponents.lerp(gradient, accumulator)!);
      }),
    );
  }
}

class AdaptivePieChartWidgetBuilder {
  static const double widthThreshold = 600;
  final Widget Function(BuildContext, DeviceSize) _chartGenerator;

  AdaptivePieChartWidgetBuilder(this._chartGenerator);

  Widget builder(BuildContext context, BoxConstraints constraints) {
    if (constraints.maxWidth > widthThreshold) {
      return _getChart(context, DeviceSize.large);
    } else {
      return _getChart(context, DeviceSize.small);
    }
  }

  Widget _getChart(BuildContext context, DeviceSize size) {
    return _chartGenerator(context, size);
  }
}

/// an indicator for pie chart legend from examples in fl_chart
class Indicator extends StatelessWidget {
  const Indicator({
    super.key,
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
