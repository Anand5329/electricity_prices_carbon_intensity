import 'dart:ui';

import 'package:electricity_prices_and_carbon_intensity/httpclient.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger(
  filter: null,
  printer: PrettyPrinter(),
  output: null,
);

class CarbonIntensityChartGenerator {
  final CarbonIntensityCaller caller;

  CarbonIntensityChartGenerator(this.caller);

  Future<LineChartData> generateChart({Color bgColor = Colors.white}) async {
    DateTime today = DateTime.now();
    List<PeriodData> past = await this.caller.getIntensityFrom(from: today, modifier: FromModifier.past24);
    List<PeriodData> future = await this.caller.getIntensityFrom(from: today, modifier: FromModifier.forward24);

    List<PeriodData> all = List.from(past);
    all.addAll(future);

    List<FlSpot> spots = convertToChartData(all);
    LineChartData chart = getChartData(spots, bgColor);

    return chart;
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

  static FlSpot _convertPeriodToSpot(PeriodData period) {
    final double y = CarbonIntensityCaller.convertToInt(period.intensity) + 0.0;
    final DateTime from = DateTime.parse(period.from);
    final DateTime to = DateTime.parse(period.to);
    final double x = (from.toLocal().millisecondsSinceEpoch + to.toLocal().millisecondsSinceEpoch) / 2;
    return FlSpot(x, y);
  }

  static List<FlSpot> convertToChartData(List<PeriodData> periods) {
    return List.from(periods.map(_convertPeriodToSpot));
  }

  static LineChartData getChartData(List<FlSpot> data, Color? backgroundColor) {
    double? minT, maxT, minI, maxI;
    if (data.isNotEmpty) {
      [minT, maxT] = _getMinMaxForTime(data);
      [minI, maxI] = _getMinMaxForCI(data);
    }
    return LineChartData(
      lineBarsData: [getLineChartBarData(data)],
      maxX: maxT,
      minX: minT,
      maxY: maxI,
      minY: minI,
      titlesData: getTitlesData(),
      lineTouchData: const LineTouchData(enabled: true),
      gridData: gridData,
      backgroundColor: backgroundColor
    );
  }

  static LineChartBarData getLineChartBarData(List<FlSpot> data) {
    return LineChartBarData(
      showingIndicators: [],
      spots: data,
      isCurved: true,
      barWidth: 4,
      belowBarData: null,
      dotData: const FlDotData(show: false),
      gradient: ciGradient,
    );
  }

  // Carbon intensity by source:
  // Coal: ~820 gCO₂e/kWh
  // Natural Gas: ~490 gCO₂e/kWh
  // Solar PV: ~48 gCO₂e/kWh
  // Wind: ~11 gCO₂e/kWh
  // Nuclear: ~12 gCO₂e/kWh
  static const List<double> ciStops = [0.2, 0.4, 0.6, 1];// [100, 200, 300, 500] / 500
  static const List<Color> ciColors = [Colors.green, Colors.yellow, Colors.red, Colors.black];
  static const Gradient ciGradient = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: ciColors, stops: ciStops);

  static FlTitlesData getTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: const AxisTitles(
        axisNameWidget: Text("Time"),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: timeInterval,
          getTitlesWidget: bottomTitleWidgets,
          minIncluded: false,
          maxIncluded: false,
        ),
      ),
      leftTitles: const AxisTitles(
        axisNameWidget: Text("Carbon Intensity ($UNIT)"),
        sideTitles: SideTitles(
          showTitles: true,
          interval: intensityInterval,
          getTitlesWidget: leftTitleWidgets,
          reservedSize: 70,
          minIncluded: false,
          maxIncluded: false,
        ),
      ),
    );
  }

  static const String UNIT = "gCO2/kWh";
  static const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);
  static const double timeInterval = 5 * 60 * 60 * 1000;
  static const double intensityInterval = 25;

  static Widget leftTitleWidgets(double value, TitleMeta meta) {
    return Text(value.round().toString(), style: textStyle, textAlign: TextAlign.center);
  }

  static Widget bottomTitleWidgets(double timestamp, TitleMeta meta) {
    final datetime = DateTime.fromMillisecondsSinceEpoch(timestamp.round());
    return Text(DateFormat.Hm().format(datetime), style: textStyle, textAlign: TextAlign.end);
  }

  static FlLine getGridLine(value) {
    return const FlLine(
      color: Colors.orange,
      strokeWidth: 1,
    );
  }

  static const gridData = FlGridData(
    show: true,
    drawVerticalLine: false,
    drawHorizontalLine: true,
    getDrawingHorizontalLine: getGridLine,
  );

}