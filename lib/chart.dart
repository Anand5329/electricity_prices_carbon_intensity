import 'dart:ui';

import 'package:electricity_prices_and_carbon_intensity/httpclient.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CarbonIntensityChartGenerator {
  final CarbonIntensityCaller caller;

  CarbonIntensityChartGenerator(this.caller);

  Future<LineChartData> generateChart({Color bgColor = Colors.white}) async {
    DateTime today = DateTime.now();
    List<PeriodData> past = await this.caller.getIntensityFrom(from: today, modifier: FromModifier.past24);
    List<PeriodData> future = await this.caller.getIntensityFrom(from: today, modifier: FromModifier.forward24);

    List<PeriodData> all = List.from(past);
    all.addAll(future);

    return getChartData(convertToChartData(all), bgColor);
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
    return LineChartData(
      lineBarsData: [getLineChartBarData(data)],
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
      shadow: const Shadow(blurRadius: 8),
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
  static const List<double> ciStops = [50, 100, 500, 800];
  static const List<Color> ciColors = [Colors.green, Colors.yellow, Colors.red, Colors.black];
  static const Gradient ciGradient = LinearGradient(colors: ciColors, stops: ciStops);

  static FlTitlesData getTitlesData() {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 1,
          getTitlesWidget: bottomTitleWidgets,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: leftTitleWidgets,
          reservedSize: 42,
        ),
      ),
    );
  }

  static const String UNIT = "gCO2/kWh";
  static const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

  static Widget leftTitleWidgets(double value, TitleMeta meta) {
    return Text("$value $UNIT", style: textStyle, textAlign: TextAlign.left);
  }

  static Widget bottomTitleWidgets(double timestamp, TitleMeta meta) {
    final datetime = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return Text(DateFormat.Hm().format(datetime), style: textStyle, textAlign: TextAlign.end);
  }

  static FlLine getGridLine(value) {
    return const FlLine(
      color: Colors.white,
      strokeWidth: 1,
    );
  }

  static const gridData = FlGridData(
    show: true,
    drawVerticalLine: true,
    horizontalInterval: 1,
    verticalInterval: 1,
    getDrawingHorizontalLine: getGridLine,
    getDrawingVerticalLine: getGridLine,
  );

}