import 'package:electricity_prices_and_carbon_intensity/utilities/generationMixApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/pieChart.dart';
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
  late GenerationMix _generationMix;
  final _caller = RegionalCarbonIntensityGenerationMixCaller();
  late RegionalCarbonIntensityChartGeneratorFactory
  _regionalChartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;
  PeriodData<IntensityData>? _minPeriod;

  late RegionalGenerationMixChartGeneratorFactory
  _regionalPieChartGeneratorFactory;
  AdaptivePieChartWidgetBuilder? _adaptivePieChartWidgetBuilder;

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

  Future<void> _refreshCarbonIntensityAndGenerationMix() async {
    _resetCounter();
    int ci = -1;
    _fetchPostcode();

    final regional = await _caller.getRegionalDataForPostcode(
      _caller.postcode!,
    );
    final intensity = regional.intensityData.first;
    final generation = regional.generationData.first;

    ci = CarbonIntensityCaller.convertToInt(intensity);

    if (ci != -1) {
      setState(() {
        _counter = ci;
      });
    } else {
      logger.e("Could not fetch latest CI");
    }

    setState(() {
      _generationMix = generation.value;
    });
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

  Future<void> _refreshPieChartData() async {
    _fetchPostcode();
    _regionalPieChartGeneratorFactory =
        RegionalGenerationMixChartGeneratorFactory(_generationMix, setState);
    final _pieChartGenerator = await _regionalPieChartGeneratorFactory
        .getChartGenerator();
    setState(() {
      _adaptivePieChartWidgetBuilder = AdaptivePieChartWidgetBuilder(
        _pieChartGenerator,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _regionalChartGeneratorFactory =
        RegionalCarbonIntensityChartGeneratorFactory(_caller, setState);
    _refreshAsync();
  }

  void _refreshAsync() async {
    await _refreshCarbonIntensityAndGenerationMix();
    _refreshChartData();
    _refreshPieChartData();
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
            const SizedBox(height: 40),
            StyleComponents.headlineTextWrapper(
              "Generation Mix",
              Theme.of(context),
            ),
            _adaptivePieChartWidgetBuilder == null
                ? SizedBox()
                : LayoutBuilder(
                    builder: _adaptivePieChartWidgetBuilder!.builder,
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
    List<PeriodData<IntensityData>> past = pastData.first.intensityData;

    List<RegionalData> futureData = await this.caller
        .getRegionalDataForPostcodeFrom(
          caller.postcode!,
          from: today,
          modifier: FromModifier.forward24,
        );
    List<PeriodData<IntensityData>> future = futureData.first.intensityData;

    int currentIntensityIndex = _getCurrentIntensityIndex(past);

    List<PeriodData<IntensityData>> all = List.from(past);
    all.addAll(future);

    List<FlSpot> spots = convertToChartData(all);
    return (BuildContext context, DeviceSize size) {
      this.backgroundColor = Theme.of(context).colorScheme.surface;
      return getChartData(spots, currentIntensityIndex, size);
    };
  }

  static int _getCurrentIntensityIndex(List<PeriodData<IntensityData>> past) {
    DateTime now = DateTime.now().toUtc();

    for (var i = 0; i < past.length; i++) {
      if (past[i].from.isBefore(now) && past[i].to.isAfter(now)) {
        return i;
      }
    }
    return past.length - 1;
  }
}

class RegionalGenerationMixChartGeneratorFactory
    extends PieChartGeneratorFactory<EnergySource> {
  final GenerationMix genMix;
  late Map<EnergySource, Color> colorMap;
  RegionalGenerationMixChartGeneratorFactory(this.genMix, super.setStateFn);

  @override
  Row Function(BuildContext context, DeviceSize size) getChartGenerator() {
    return (BuildContext context, DeviceSize size) {
      this.theme = Theme.of(context);
      this.backgroundColor = theme.colorScheme.surface;
      this.colorMap = PieChartGeneratorFactory.getDefaultColorMap();
      PieChart chart = getChart(genMix.toMap(), colorMap, size);
      double aspectRatio = size == DeviceSize.small ? 1 : 1.7;
      return _getWidgetHelper(chart, aspectRatio);
    };
  }

  Row _getWidgetHelper(PieChart chart, double aspectRatio) {
    Map genMap = genMix.toMap();
    colorMap.removeWhere((source, value) => genMap[source] == 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Padding(
              padding: const EdgeInsets.only(
                right: 18,
                left: 5,
                top: 0,
                bottom: 0,
              ),
              child: chart,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: generateLegend(colorMap: this.colorMap),
          ),
        ),
      ],
    );
  }
}
