import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../utilities/carbonIntensityApiCaller.dart';
import 'animatedCounter.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class CarbonIntensityPage extends StatefulWidget {
  final String title;
  const CarbonIntensityPage({super.key, this.title = "Carbon Intensity"});

  @override
  State<CarbonIntensityPage> createState() => _CarbonIntensityPageState();
}

class _CarbonIntensityPageState extends State<CarbonIntensityPage> {
  late int _counter = 0;
  final _caller = CarbonIntensityCaller();
  late CarbonIntensityChartGeneratorFactory _chartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;
  PeriodData<IntensityData>? _minPeriod;

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  Future<int> _getCarbonIntensity() async {
    try {
      // return await NativeAdapter.updateCarbonIntensity();
      final intensity = await _caller.getCurrentIntensity();
      return CarbonIntensityCaller.convertToInt(intensity);
    } on Exception catch (e) {
      logger.e(e.toString());
      return -1;
    }
  }

  Future<void> _refreshCarbonIntensity() async {
    _resetCounter();
    int ci = -1;
    ci = await _getCarbonIntensity();

    if (ci != -1) {
      setState(() {
        _counter = ci;
      });
    } else {
      logger.e("Could not fetch latest CI");
    }
  }

  Future<void> _refreshChartData() async {
    final _chartGenerator = await _chartGeneratorFactory.getChartGenerator();
    final minPeriod = await _caller.forecastMinimum();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(_chartGenerator);
      _minPeriod = minPeriod;
    });
  }

  @override
  void initState() {
    super.initState();
    _chartGeneratorFactory = CarbonIntensityChartGeneratorFactory(
      _caller,
      setState,
    );
    _refreshCarbonIntensity();
    _refreshChartData();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 40),
            BigAnimatedCounter(count: _counter.toDouble()),
            SizedBox(height: 40),
            _adaptiveChartWidgetBuilder == null
                ? SizedBox()
                : LayoutBuilder(builder: _adaptiveChartWidgetBuilder!.builder),
            SizedBox(height: 20),
            _minPeriod == null
                ? SizedBox()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Next lowest:"),
                      Text(
                        _minPeriod!.prettyPrintPeriod(),
                        style: StyleComponents.smallText,
                      ),
                      Text(
                        "${_minPeriod?.value.get()} ${CarbonIntensityChartGeneratorFactory.unit}",
                        style: StyleComponents.smallText,
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class CarbonIntensityChartGeneratorFactory
    extends ChartGeneratorFactory<IntensityData> {
  static const String unit = "gCO2/kWh";

  final CarbonIntensityCaller caller;

  // Carbon intensity by source:
  // Coal: ~820 gCO₂e/kWh
  // Natural Gas: ~490 gCO₂e/kWh
  // Solar PV: ~48 gCO₂e/kWh
  // Wind: ~11 gCO₂e/kWh
  // Nuclear: ~12 gCO₂e/kWh

  CarbonIntensityChartGeneratorFactory.all(
    this.caller, {
    required super.setStateFn,
    required super.xAxisName,
    required super.yAxisName,
    required super.intervalHoursForLargeWidth,
    required super.intervalHours,
    required super.yInterval,
    required super.maxPossibleY,
    required super.yStops,
    required super.fractionYStops,
    required super.yColors,
    required super.yGradient,
    required super.maxY,
    required super.minY,
    required super.specificGradient,
    super.textStyle = StyleComponents.smallText,
  });

  CarbonIntensityChartGeneratorFactory(
    CarbonIntensityCaller caller,
    void Function(VoidCallback) setStateFn,
  ) : this.all(
        caller,
        setStateFn: setStateFn,
        yAxisName: "Carbon Intensity ($unit)",
        xAxisName: "Time",
        intervalHoursForLargeWidth: 5,
        intervalHours: 12,
        yInterval: 25,
        maxPossibleY: 500,
        yStops: ChartGeneratorFactory.defaultStops,
        fractionYStops: ChartGeneratorFactory.defaultFractionStops,
        yColors: ChartGeneratorFactory.defaultColors,
        yGradient: ChartGeneratorFactory.defaultGradient,
        maxY: 500,
        minY: 0,
        specificGradient: ChartGeneratorFactory.defaultGradient,
      );

  @override
  Future<LineChartData Function(BuildContext, DeviceSize)>
  getChartGenerator() async {
    DateTime today = DateTime.now().toUtc();
    List<PeriodData<IntensityData>> past = await this.caller.getIntensityFrom(
      from: today,
      modifier: FromModifier.past24,
    );
    DateTime time1 = DateTime.now().toUtc();
    List<PeriodData<IntensityData>> future = await this.caller.getIntensityFrom(
      from: today,
      modifier: FromModifier.forward24,
    );
    DateTime time2 = DateTime.now().toUtc();
    int currentIntensityIndex = _getCurrentIntensityIndex(past);

    List<PeriodData<IntensityData>> all = List.from(past);
    all.addAll(future);

    List<FlSpot> spots = convertToChartData(all);
    DateTime time3 = DateTime.now().toUtc();
    // logger.d(today.difference(time1));
    // logger.d(time1.difference(time2));
    // logger.d(time2.difference(time3));
    return (BuildContext context, DeviceSize size) {
      this.backgroundColor = Theme.of(context).colorScheme.surface;
      return getChartData(spots, currentIntensityIndex, size);
    };
  }

  static int _getCurrentIntensityIndex(List<PeriodData<IntensityData>> past) {
    for (var i = past.length - 1; i >= 0; i--) {
      // return the latest valid actual point of data
      if (past[i].value.actual != null) {
        return i;
      }
    }
    return 0;
  }

  @override
  FlSpot convertPeriodToSpot(PeriodData<IntensityData> period) {
    final double y = CarbonIntensityCaller.convertToInt(period) + 0.0;
    final double x =
        (period.from.toLocal().millisecondsSinceEpoch +
            period.to.toLocal().millisecondsSinceEpoch) /
        2;
    return FlSpot(x, y);
  }

  @override
  List<FlSpot> convertToChartData(List<PeriodData<IntensityData>> periods) {
    return periods.map(convertPeriodToSpot).toList();
  }
}
