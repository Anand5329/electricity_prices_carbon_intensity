import 'package:electricity_prices_and_carbon_intensity/httpclient.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class CarbonIntensityChartGeneratorFactory {
  final CarbonIntensityCaller caller;
  final void Function(VoidCallback) setStateFn;
  bool handleBuiltInTouches = false;

  late Color backgroundColor;

  CarbonIntensityChartGeneratorFactory(this.caller, this.setStateFn);

  Future<LineChartData Function(BuildContext, DeviceSize)>
  getChartGenerator() async {
    DateTime today = DateTime.now();
    List<PeriodData> past = await this.caller.getIntensityFrom(
      from: today,
      modifier: FromModifier.past24,
    );
    List<PeriodData> future = await this.caller.getIntensityFrom(
      from: today,
      modifier: FromModifier.forward24,
    );
    int currentIntensityIndex = _getCurrentIntensityIndex(past);

    List<PeriodData> all = List.from(past);
    all.addAll(future);

    List<FlSpot> spots = _convertToChartData(all);

    return (BuildContext context, DeviceSize size) {
      this.backgroundColor = Theme.of(context).colorScheme.surface;
      return _getChartData(spots, currentIntensityIndex, size);
    };
  }

  LineChartData _getChartData(
    List<FlSpot> data,
    int currentIntensityIndex,
    DeviceSize size,
  ) {
    double? minT, maxT, minI, maxI;
    if (data.isNotEmpty) {
      [minT, maxT] = _getMinMaxForTime(data);
      [minI, maxI] = _getMinMaxForCI(data);
    }
    final lineChartBar = _getLineChartBarData(
      data,
      currentIntensityIndex,
      minI,
      maxI,
    );
    final touchData = _getTouchData();
    return LineChartData(
      lineBarsData: [lineChartBar],
      maxX: maxT,
      minX: minT,
      maxY: maxI,
      minY: minI,
      titlesData: _getTitlesData(size),
      borderData: FlBorderData(show: false),
      lineTouchData: touchData,
      gridData: gridData,
      backgroundColor: backgroundColor,
      showingTooltipIndicators: [
        ShowingTooltipIndicators([
          LineBarSpot(
            lineChartBar,
            0,
            lineChartBar.spots[currentIntensityIndex],
          ),
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
        getTooltipItems: _intensityAndTimeTooltipItems,
      ),
    );
  }

  static List<double> _getMinMaxForTime(List<FlSpot> dots) {
    double minT = dots.first.x;
    double maxT = dots.last.x;
    return [minT, maxT];
  }

  static List<double> _getMinMaxForCI(List<FlSpot> dots) {
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

  static int _getCurrentIntensityIndex(List<PeriodData> past) {
    for (var i = past.length - 1; i >= 0; i--) {
      // return the latest valid actual point of data
      if (past[i].intensity.actual != null) {
        return i;
      }
    }
    return 0;
  }

  static FlSpot _convertPeriodToSpot(PeriodData period) {
    final double y = CarbonIntensityCaller.convertToInt(period) + 0.0;
    final DateTime from = DateTime.parse(period.from);
    final DateTime to = DateTime.parse(period.to);
    final double x =
        (from.toLocal().millisecondsSinceEpoch +
            to.toLocal().millisecondsSinceEpoch) /
        2;
    return FlSpot(x, y);
  }

  static List<FlSpot> _convertToChartData(List<PeriodData> periods) {
    return periods.map(_convertPeriodToSpot).toList();
  }

  static LineChartBarData _getLineChartBarData(
    List<FlSpot> data,
    int currentSpotIndex,
    double? minIntensity,
    double? maxIntensity,
  ) {
    _constrainGradientToSpecific(minIntensity, maxIntensity);

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

  static void _constrainGradientToSpecific(
    double? minIntensity,
    double? maxIntensity,
  ) {
    double minStop = minIntensity! / maxPossibleIntensity;
    double maxStop = maxIntensity! / maxPossibleIntensity;
    List<Color> colors = List.from(ciGradient.colors);
    List<double> stops = List.from(ciGradient.stops!);
    Color? minColor = lerp(ciGradient, minStop);
    Color? maxColor = lerp(ciGradient, maxStop);
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

    minI = minIntensity;
    maxI = maxIntensity;

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

  // Carbon intensity by source:
  // Coal: ~820 gCO₂e/kWh
  // Natural Gas: ~490 gCO₂e/kWh
  // Solar PV: ~48 gCO₂e/kWh
  // Wind: ~11 gCO₂e/kWh
  // Nuclear: ~12 gCO₂e/kWh
  static double minI = 0;
  static double maxI = 500;
  static const double maxPossibleIntensity = 500;
  static const List<double> intensityStops = [0, 100, 200, 300, 500];
  static final List<double> fractionStops = intensityStops
      .map((x) => x / maxPossibleIntensity)
      .toList();
  static const List<Color> ciColors = [
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.red,
    Colors.black,
  ];
  static final LinearGradient ciGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: ciColors,
    stops: fractionStops,
  );
  static LinearGradient specificGradient = ciGradient;
  static const Color defaultTouchColor = Colors.black;
  static LineTouchData ciTouchData = LineTouchData(
    enabled: true,
    handleBuiltInTouches: false,
    getTouchedSpotIndicator: _getTouchedIndicator,
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (touchedSpot) => defaultTouchColor,
      getTooltipItems: _intensityAndTimeTooltipItems,
    ),
  );

  static List<TouchedSpotIndicatorData?> _getTouchedIndicator(
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

  static List<LineTooltipItem?> _intensityAndTimeTooltipItems(
    List<LineBarSpot> spots,
  ) {
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
  static Color? _getColorForY(double y) =>
      lerp(specificGradient, (y - minI) / (maxI - minI));

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

  static FlTitlesData _getTitlesData(DeviceSize size) {
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
        axisNameWidget: Text("Time"),
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
      leftTitles: const AxisTitles(
        axisNameWidget: Text("Carbon Intensity ($UNIT)"),
        axisNameSize: 23,
        sideTitles: SideTitles(
          showTitles: true,
          interval: intensityInterval,
          getTitlesWidget: _leftTitleWidgets,
          reservedSize: 50,
          minIncluded: false,
          maxIncluded: false,
        ),
      ),
    );
  }

  static const String UNIT = "gCO2/kWh";
  static const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);
  static const int intervalHoursForLargeWidth = 5;
  static const int intervalHours = 12;
  static const double hour = 60 * 60 * 1000;
  static const double intensityInterval = 25;

  static Widget _leftTitleWidgets(double value, TitleMeta meta) {
    return Text(
      value.round().toString(),
      style: textStyle,
      textAlign: TextAlign.center,
    );
  }

  static Widget _bottomTitleWidgets(
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

  static String _toReadableTimeStamp(
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
