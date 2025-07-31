import 'dart:io';

import 'package:electricity_prices_and_carbon_intensity/utilities/generationMixApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/pieChart.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/shimmerLoad.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../utilities/carbonIntensityApiCaller.dart';
import '../utilities/regionalCarbonIntensityGenerationMixApiCaller.dart';
import 'animatedCounter.dart';
import 'carbonIntensity.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class RegionalPage extends StatefulWidget {
  final String title;
  const RegionalPage({super.key, this.title = "Carbon Intensity"});

  @override
  State<RegionalPage> createState() {
    return _RegionalPageState();
  }
}

class _RegionalPageState extends State<RegionalPage>
    with AutomaticKeepAliveClientMixin<RegionalPage> {
  static const String saveFilePath = "postcodeCache.txt";
  static const String defaultPostcode = "N1";

  bool _keepAlive = true;

  bool get keepAlive => _keepAlive;
  set keepAlive(bool value) {
    _keepAlive = value;
    updateKeepAlive();
  }

  @override
  bool get wantKeepAlive => keepAlive;

  late String _docDir;
  late File _saveFile;

  late int _counter = 0;
  late PeriodData<GenerationMix> _generation;
  final _caller = RegionalCarbonIntensityGenerationMixCaller();
  String? _regionName;
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
    keepAlive = false;
    _postcodeController.dispose();
    super.dispose();
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  Future<void> _fetchPostcode() async {
    String text = _postcodeController.text;
    String savedPostcode = text;
    if (text.isEmpty) {
      savedPostcode = await _readSavedPostcode();
      if (savedPostcode.isEmpty) {
        savedPostcode = defaultPostcode;
      }
    } else if (savedPostcode != defaultPostcode) {
      _saveFile = await _savePostcodetoFile(savedPostcode);
    }
    setState(() {
      _postcodeController.text = savedPostcode;
    });
    _caller.postcode = _postcodeController.text;
  }

  Future<File> _savePostcodetoFile(String postcode) {
    return _saveFile.writeAsString(postcode);
  }

  Future<String> _readSavedPostcode() async {
    try {
      final contents = await _saveFile.readAsString();
      return contents;
    } catch (e) {
      logger.e(e);
      return defaultPostcode;
    }
  }

  Future<void> _refreshCarbonIntensityAndGenerationMix() async {
    _resetCounter();
    _setLoading();
    int ci = -1;
    await _fetchPostcode();

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
      _regionName = regional.shortname;
      _generation = generation;
    });
  }

  void _setLoading() {
    setState(() {
      _regionName = null;
      _adaptivePieChartWidgetBuilder = null;
      _adaptiveChartWidgetBuilder = null;
    });
  }

  Future<void> _refreshChartData() async {
    await _fetchPostcode();
    final _chartGenerator = await _regionalChartGeneratorFactory
        .getChartGenerator();
    final minPeriod = await _caller.forecastMinimum();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(_chartGenerator);
      _minPeriod = minPeriod;
    });
  }

  Future<void> _refreshPieChartData() async {
    await _fetchPostcode();
    _regionalPieChartGeneratorFactory =
        RegionalGenerationMixChartGeneratorFactory(_generation.value, setState);
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
    _initAsyncHelper();
  }

  void _initAsyncHelper() async {
    _docDir = (await getApplicationDocumentsDirectory()).path;
    _saveFile = File("$_docDir/$saveFilePath");
    _refreshAsync();
  }

  void _refreshAsync() async {
    await _refreshCarbonIntensityAndGenerationMix();
    _refreshChartData();
    _refreshPieChartData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            Shimmer(
              linearGradient: style.shimmerGradient(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerLoading(
                    isLoading: _regionName == null,
                    childGenerator: () => Text(
                      "Region: $_regionName",
                      style: StyleComponents.smallText,
                    ),
                    placeholder: ShimmerLoading.smallPlaceholder,
                  ),
                  SizedBox(height: 20),
                  BigAnimatedCounter(count: _counter.toDouble()),
                  SizedBox(height: 40),
                  ShimmerLoading(
                    isLoading: _adaptiveChartWidgetBuilder == null,
                    childGenerator: () => LayoutBuilder(
                      builder: _adaptiveChartWidgetBuilder!.builder,
                    ),
                    placeholder: StyleComponents.paddingWrapper(
                      ShimmerLoading.squarePlaceholder,
                    ),
                  ),
                  SizedBox(height: 20),
                  ShimmerLoading(
                    isLoading: _minPeriod == null,
                    childGenerator: () => Column(
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
                    placeholder: StyleComponents.paddingWrapper(
                      ShimmerLoading.textPlaceholder,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            StyleComponents.subHeadingTextWrapper(
              "Generation Mix",
              Theme.of(context),
            ),
            Shimmer(
              linearGradient: style.shimmerGradient(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerLoading(
                    isLoading: _adaptivePieChartWidgetBuilder == null,
                    childGenerator: () => LayoutBuilder(
                      builder: _adaptivePieChartWidgetBuilder!.builder,
                    ),
                    placeholder: StyleComponents.paddingWrapper(
                      ShimmerLoading.squarePlaceholder,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ShimmerLoading(
                    isLoading: _adaptivePieChartWidgetBuilder == null,
                    childGenerator: () => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Generation data as of: ${_generation.prettyPrintPeriod()}",
                          style: StyleComponents.smallText,
                        ),
                      ],
                    ),
                    placeholder: StyleComponents.paddingWrapper(
                      ShimmerLoading.textPlaceholder,
                    ),
                  ),
                ],
              ),
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
