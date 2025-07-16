import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

abstract class ChartGeneratorFactory<T extends Comparable<T>> {
  double minY;
  double maxY;
  final double maxPossibleY;
  final List<double> yStops;
  final List<double> fractionYStops;
  final List<Color> yColors;
  final LinearGradient yGradient;
  LinearGradient specificGradient;

  static const Color defaultTouchColor = Colors.black;
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

  final String xAxisName;
  final String yAxisName;
  final TextStyle textStyle;
  final int intervalHoursForLargeWidth;
  final int intervalHours;
  final double hour;
  final double yInterval;

  final void Function(VoidCallback) setStateFn;
  bool handleBuiltInTouches = false;
  late Color backgroundColor;

  ChartGeneratorFactory({
    required this.setStateFn,
    required this.xAxisName,
    required this.yAxisName,
    required this.intervalHoursForLargeWidth,
    required this.intervalHours,
    this.hour = 60 * 60 * 1000,
    required this.yInterval,
    required this.maxPossibleY,
    required this.yStops,
    required this.fractionYStops,
    required this.yColors,
    required this.yGradient,
    required this.maxY,
    required this.minY,
    required this.specificGradient,
    this.textStyle = const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
  });

  Future<LineChartData Function(BuildContext, DeviceSize)> getChartGenerator();

  LineChartData getChartData(
    List<FlSpot> data,
    int currentSpotIndex,
    DeviceSize size,
  ) {
    double? minX, maxX, minY, maxY;
    if (data.isNotEmpty) {
      [minX, maxX] = _getMinMaxForX(data);
      [minY, maxY] = _getMinMaxForY(data);
    }
    final lineChartBar = _getLineChartBarData(
      data,
      currentSpotIndex,
      minY,
      maxY,
    );
    final touchData = _getTouchData();
    return LineChartData(
      lineBarsData: [lineChartBar],
      maxX: maxX,
      minX: minX,
      maxY: maxY,
      minY: minY,
      titlesData: _getTitlesData(size),
      borderData: FlBorderData(show: false),
      lineTouchData: touchData,
      gridData: gridData,
      backgroundColor: backgroundColor,
      showingTooltipIndicators: [
        ShowingTooltipIndicators([
          LineBarSpot(lineChartBar, 0, lineChartBar.spots[currentSpotIndex]),
        ]),
      ],
    );
  }

  LineTouchData _getTouchData() {
    return LineTouchData(
      enabled: true,
      handleBuiltInTouches: this.handleBuiltInTouches,
      getTouchedSpotIndicator: _getTouchedIndicator,
      touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
        if (response == null || response.lineBarSpots == null) {
          return;
        }
        double y = response.lineBarSpots!.first.y;

        if (event is FlPointerEnterEvent ||
            event is FlPointerHoverEvent ||
            event is FlTapDownEvent) {
          setStateFn(() {
            this.handleBuiltInTouches = true;
          });
        } else if (event is FlPointerExitEvent ||
            event is FlTapUpEvent ||
            event is FlTapCancelEvent ||
            event is FlPanEndEvent ||
            event is FlPanCancelEvent ||
            event is FlLongPressEnd) {
          // TODO: fix: FlPanUpdate event detected when should be FlPanEndEvent. Not resetting to False.
          setStateFn(() {
            this.handleBuiltInTouches = false;
          });
        } else {
          // logger.d(event);
        }
      },
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (touchedSpot) => defaultTouchColor,
        getTooltipItems: _yAndXTimeTooltipItems,
      ),
    );
  }

  static List<double> _getMinMaxForX(List<FlSpot> dots) {
    double minX = dots.first.x;
    double maxX = dots.last.x;
    return [minX, maxX];
  }

  static List<double> _getMinMaxForY(List<FlSpot> dots) {
    double max = dots.first.y;
    double min = dots.first.y;
    for (var spot in dots) {
      if (spot.y > max) {
        max = spot.y;
      }
      if (spot.y < min) {
        min = spot.y;
      }
    }
    return [min, max];
  }

  FlSpot convertPeriodToSpot(PeriodData<T> period);

  List<FlSpot> convertToChartData(List<PeriodData<T>> periods) {
    return periods.map(convertPeriodToSpot).toList();
  }

  LineChartBarData _getLineChartBarData(
    List<FlSpot> data,
    int currentSpotIndex,
    double? minY,
    double? maxY,
  ) {
    _constrainGradientToSpecific(minY, maxY);

    return LineChartBarData(
      showingIndicators: [currentSpotIndex],
      spots: data,
      isCurved: true,
      barWidth: 4,
      belowBarData: BarAreaData(
        show: true,
        gradient: specificGradient.withOpacity(0.5),
      ),
      dotData: const FlDotData(show: false),
      gradient: specificGradient,
    );
  }

  void _constrainGradientToSpecific(double? minY, double? maxY) {
    double minStop = minY! / maxPossibleY;
    double maxStop = maxY! / maxPossibleY;
    List<Color> colors = List.from(yGradient.colors);
    List<double> stops = List.from(yGradient.stops!);
    Color? minColor = lerp(yGradient, minStop);
    Color? maxColor = lerp(yGradient, maxStop);
    int i, j;
    for (i = 0; i < stops.length; i++) {
      if (stops[i] > minStop) {
        i--;
        break;
      }
    }
    for (j = stops.length - 1; j >= 0; j--) {
      if (stops[j] < maxStop) {
        j = stops.length - j - 2;
        break;
      }
    }

    while (i >= 0) {
      stops.removeAt(i);
      colors.removeAt(i);
      i--;
    }

    while (j >= 0) {
      stops.removeLast();
      colors.removeLast();
      j--;
    }

    colors.insert(0, minColor ?? defaultTouchColor);
    stops.insert(0, minStop);
    colors.add(maxColor ?? defaultTouchColor);
    stops.add(maxStop);

    this.minY = minY;
    this.maxY = maxY;

    //normalise stops
    stops = stops
        .map((stop) => (stop - minStop) / (maxStop - minStop))
        .toList();

    // logger.d(colors);
    // logger.d(stops);

    specificGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: colors,
      stops: stops,
    );
    // specificGradient = ciGradient;
  }

  LineTouchData yTouchData() => LineTouchData(
    enabled: true,
    handleBuiltInTouches: false,
    getTouchedSpotIndicator: _getTouchedIndicator,
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (touchedSpot) => defaultTouchColor,
      getTooltipItems: _yAndXTimeTooltipItems,
    ),
  );

  List<TouchedSpotIndicatorData?> _getTouchedIndicator(
    LineChartBarData bar,
    List<int> indices,
  ) {
    return indices.map((index) {
      final spot = bar.spots[index];
      final color = _getColorForY(spot.y);
      return TouchedSpotIndicatorData(
        FlLine(color: color),
        FlDotData(
          getDotPainter: (spot, xPercent, barData, dotIndex) =>
              FlDotCirclePainter(color: color ?? defaultTouchColor),
        ),
      );
    }).toList();
  }

  List<LineTooltipItem?> _yAndXTimeTooltipItems(List<LineBarSpot> spots) {
    return spots
        .map(
          (spot) => LineTooltipItem(
            "${spot.y}\n${_toReadableTimeStamp(spot.x)}",
            TextStyle(color: _getColorForY(spot.y)),
          ),
        )
        .toList();
  }

  // normalize Y as it would inside the gradient paint
  // just dividing by maxPossibleIntensity does not work, have to use L1 norm
  Color? _getColorForY(double y) =>
      lerp(specificGradient, (y - minY) / (maxY - minY));

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

  FlTitlesData _getTitlesData(DeviceSize size) {
    double interval;
    switch (size) {
      case DeviceSize.large:
        interval = hour * intervalHoursForLargeWidth;
        break;
      case DeviceSize.small:
        interval = hour * intervalHours;
        break;
    }

    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: Text(xAxisName),
        axisNameSize: 20,
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          interval: interval,
          getTitlesWidget: (timestamp, meta) =>
              _bottomTitleWidgets(timestamp, meta, size),
          minIncluded: false,
          maxIncluded: false,
        ),
      ),
      leftTitles: AxisTitles(
        axisNameWidget: Text(yAxisName),
        axisNameSize: 23,
        sideTitles: SideTitles(
          showTitles: true,
          interval: yInterval,
          getTitlesWidget: _leftTitleWidgets,
          reservedSize: 50,
          minIncluded: false,
          maxIncluded: false,
        ),
      ),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    return Text(
      value.round().toString(),
      style: textStyle,
      textAlign: TextAlign.center,
    );
  }

  Widget _bottomTitleWidgets(
    double timestamp,
    TitleMeta meta,
    DeviceSize size,
  ) {
    return Text(
      _toReadableTimeStamp(timestamp, includeDateAtMidnight: true, size: size),
      style: textStyle,
      textAlign: TextAlign.center,
    );
  }

  String _toReadableTimeStamp(
    double timestamp, {
    bool includeDateAtMidnight = false,
    DeviceSize? size,
  }) {
    final datetime = DateTime.fromMillisecondsSinceEpoch(timestamp.round());
    String date = "";
    int newDayThreshold;
    switch (size) {
      case DeviceSize.small:
        newDayThreshold = intervalHours;
        break;
      case DeviceSize.large:
        newDayThreshold = intervalHoursForLargeWidth;
        break;
      default:
        newDayThreshold = 0;
    }
    if (includeDateAtMidnight &&
        datetime.hour < newDayThreshold &&
        datetime.minute == 0) {
      date = "\n${DateFormat.yMMMd().format(datetime)}";
    }
    return DateFormat.Hm().format(datetime) + date;
  }

  static FlLine _getGridLine(value) {
    return const FlLine(color: Colors.orange, strokeWidth: 1);
  }

  static const gridData = FlGridData(
    show: true,
    drawVerticalLine: false,
    drawHorizontalLine: false,
  );
}

class AdaptiveChartWidgetBuilder {
  static const double widthThreshold = 600;
  final LineChartData Function(BuildContext, DeviceSize) _chartGenerator;

  AdaptiveChartWidgetBuilder(this._chartGenerator);

  Widget builder(BuildContext context, BoxConstraints constraints) {
    if (constraints.maxWidth > widthThreshold) {
      return _getLargeWidthWidget(context);
    } else {
      return _getSmallWidthWidget(context);
    }
  }

  Widget _getSmallWidthWidget(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.20,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 5, top: 0, bottom: 0),
        child: LineChart(_chartGenerator(context, DeviceSize.small)),
      ),
    );
  }

  Widget _getLargeWidthWidget(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.70,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 0, bottom: 0),
        child: LineChart(_chartGenerator(context, DeviceSize.large)),
      ),
    );
  }
}

enum DeviceSize { small, large }
