import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../utilities/carbonIntensityApiCaller.dart';
import '../utilities/regionalCarbonIntensityGenerationMixApiCaller.dart';
import 'animatedCounter.dart';
import 'carbonIntensity.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class RegionalPage extends StatefulWidget {
  final String title;
  const RegionalPage({super.key, this.title = "Carbon Intensity"});

  @override
  State<RegionalPage> createState() => _RegionalPageState();
}

class _RegionalPageState extends State<RegionalPage> {
  static const String defaultPostcode = "N1";

  late int _counter = 0;
  final _caller = RegionalCarbonIntensityGenerationMixCaller();
  late RegionalCarbonIntensityChartGeneratorFactory
  _regionalChartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;
  PeriodData<IntensityData>? _minPeriod;

  final _postcodeController = TextEditingController();

  @override
  void dispose() {
    _postcodeController.dispose();
    super.dispose();
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  void _fetchPostcode() {
    String text = _postcodeController.text;
    if (text.length == 0) {
      text = defaultPostcode;
      setState(() {
        _postcodeController.text = defaultPostcode;
      });
    }
    _caller.postcode = _postcodeController.text;
  }

  Future<int> _getCarbonIntensity() async {
    try {
      _fetchPostcode();
      final intensity = await _caller.getCurrentIntensityForPostcode(
        _caller.postcode!,
      );
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
      for (int i = 0; i <= ci; i++) {
        setState(() {
          _counter = i;
        });
      }
    } else {
      logger.e("Could not fetch latest CI");
    }
  }

  Future<void> _refreshChartData() async {
    _fetchPostcode();
    final _chartGenerator = await _regionalChartGeneratorFactory
        .getChartGenerator();
    final minPeriod = await _caller.forecastMinimum();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(_chartGenerator);
      _minPeriod = minPeriod;
    });
  }

  @override
  void initState() {
    super.initState();
    _regionalChartGeneratorFactory =
        RegionalCarbonIntensityChartGeneratorFactory(_caller, setState);
    _refreshCarbonIntensity();
    _refreshChartData();
  }

  void _refreshAsync() {
    _refreshCarbonIntensity();
    _refreshChartData();
  }

  @override
  Widget build(BuildContext context) {
    final style = StyleComponents(Theme.of(context));
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: StyleComponents.paddingWrapper(
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter an outer postcode (e.g. NW5)',
                      ),
                      controller: _postcodeController,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                TextButton(
                  style: style.simpleButtonStyle(),
                  child: Icon(Icons.refresh_rounded),
                  onPressed: _refreshAsync,
                ),
              ],
            ),
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
                SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RegionalCarbonIntensityChartGeneratorFactory
    extends CarbonIntensityChartGeneratorFactory {
  final RegionalCarbonIntensityGenerationMixCaller caller;
  final void Function(VoidCallback) setStateFn;

  RegionalCarbonIntensityChartGeneratorFactory(this.caller, this.setStateFn)
      : super(caller, setStateFn);

  /// ensure postcode is set in caller before calling
  @override
  Future<LineChartData Function(BuildContext p1, DeviceSize p2)>
  getChartGenerator() async {
    DateTime today = DateTime.now().toUtc();
    List<RegionalData> pastData = await this.caller
        .getRegionalDataForPostcodeFrom(
      caller.postcode!,
      from: today,
      modifier: FromModifier.past24,
    );
    DateTime time1 = DateTime.now().toUtc();
    List<PeriodData<IntensityData>> past = pastData.first.intensityData;
    List<RegionalData> futureData = await this.caller
        .getRegionalDataForPostcodeFrom(
      caller.postcode!,
      from: today,
      modifier: FromModifier.forward24,
    );
    DateTime time2 = DateTime.now().toUtc();
    List<PeriodData<IntensityData>> future = futureData.first.intensityData;

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
    // TODO: make this inline with getCurrentIntensity
    DateTime now = DateTime.now().toUtc();

    for (var i = 0; i < past.length; i++) {
      if (past[i].from.isBefore(now) && past[i].to.isAfter(now)) {
        return i;
      }
    }
    return past.length - 1;
  }
}
