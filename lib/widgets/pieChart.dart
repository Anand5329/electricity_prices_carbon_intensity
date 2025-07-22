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

  PieChart Function(BuildContext, DeviceSize) getChartGenerator();

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
      double radius = 80;
      double fontSize = 16;
      T factor = keys[i];
      if (touchedIndex == i) {
        radius = 100;
        fontSize = 20;
      }
      sections.add(
        PieChartSectionData(
          value: chartValues[factor],
          title: factor.toString(),
          color: colorMap[factor],
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.inversePrimary,
          ),
          radius: radius,
        ),
      );
    }
    return sections;
  }
}

class AdaptivePieChartWidgetBuilder {
  static const double widthThreshold = 600;
  final PieChart Function(BuildContext, DeviceSize) _chartGenerator;

  AdaptivePieChartWidgetBuilder(this._chartGenerator);

  Widget builder(BuildContext context, BoxConstraints constraints) {
    if (constraints.maxWidth > widthThreshold) {
      return _getLargeWidthWidget(context);
    } else {
      return _getSmallWidthWidget(context);
    }
  }

  Widget _getSmallWidthWidget(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 5, top: 0, bottom: 0),
        child: _chartGenerator(context, DeviceSize.small),
      ),
    );
  }

  Widget _getLargeWidthWidget(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 0, bottom: 0),
        child: _chartGenerator(context, DeviceSize.large),
      ),
    );
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
