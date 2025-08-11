import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/shimmerLoad.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../utilities/carbonIntensityApiCaller.dart';
import '../utilities/regionalCarbonIntensityGenerationMixApiCaller.dart';
import '../utilities/settings.dart';
import 'carbonIntensity.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class HistoricalCarbonIntensityPage extends StatefulWidget {
  final String title;
  const HistoricalCarbonIntensityPage({
    super.key,
    this.title = "Historical Carbon Intensity",
  });

  @override
  State<HistoricalCarbonIntensityPage> createState() {
    return _HistoricalCarbonIntensityPageState();
  }
}

class _HistoricalCarbonIntensityPageState
    extends State<HistoricalCarbonIntensityPage>
    with AutomaticKeepAliveClientMixin<HistoricalCarbonIntensityPage> {
  static final DateTime firstDate = DateTime(1985, 01, 01);
  static final DateTime lastDate = DateTime(2101, 01, 01);
  static final DateTime initialStartDate = DateTime(2023, 03, 09);
  static final DateTime initialEndDate = DateTime(2023, 03, 11);

  static late DateFormat dateFormat = DateFormat.yMMMd(Intl.systemLocale);

  bool _keepAlive = true;

  bool get keepAlive => _keepAlive;
  set keepAlive(bool value) {
    _keepAlive = value;
    updateKeepAlive();
  }

  @override
  bool get wantKeepAlive => keepAlive;

  final Settings settings = Settings();

  DateTime start = initialStartDate;
  DateTime end = initialEndDate;

  final _caller = RegionalCarbonIntensityGenerationMixCaller();
  String? _regionName;
  late HistoricalCarbonIntensityChartGeneratorFactory
  _regionalChartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;
  PeriodData<IntensityData>? _minPeriod;

  final _postcodeController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  @override
  void dispose() {
    keepAlive = false;
    _postcodeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchPostcode() async {
    String text = _postcodeController.text;
    String savedPostcode = text;
    if (text.isEmpty) {
      savedPostcode = await settings.readSavedPostcode();
      if (savedPostcode.isEmpty) {
        savedPostcode = Settings.defaultPostcode;
      }
    }
    setState(() {
      _postcodeController.text = savedPostcode;
    });
    _caller.postcode = _postcodeController.text;
  }

  Future<void> _selectDateFor(BuildContext context) async {
    final DateTimeRange<DateTime>? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: "Select date range upto 14 days long",
      initialDateRange: DateTimeRange(
        start: initialStartDate,
        end: initialEndDate,
      ),
    );

    if (picked != null) {
      this.start = picked.start;
      this.end = picked.end;
      _startDateController.text = dateFormat.format(start);
      _endDateController.text = dateFormat.format(end);
    }
  }

  void _setLoading() {
    setState(() {
      _regionName = null;
      _adaptiveChartWidgetBuilder = null;
    });
  }

  Future<void> _refreshChartData() async {
    _setLoading();
    await _fetchPostcode();
    _regionalChartGeneratorFactory.setDateRange(start, end);
    final _chartGenerator = await _regionalChartGeneratorFactory
        .getChartGenerator();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(_chartGenerator);
      _regionName = _regionalChartGeneratorFactory.regionName;
      _minPeriod = _regionalChartGeneratorFactory.minPeriod;
    });
  }

  @override
  void initState() {
    super.initState();
    _regionalChartGeneratorFactory =
        HistoricalCarbonIntensityChartGeneratorFactory(_caller, setState);
    _initAsyncHelper();
  }

  void _initAsyncHelper() async {
    _startDateController.text = dateFormat.format(start);
    _endDateController.text = dateFormat.format(end);
    dateFormat = DateFormat.yMMMd(Intl.systemLocale);
    _refreshAsync();
  }

  void _refreshAsync() async {
    await _refreshChartData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final style = StyleComponents(Theme.of(context));
    return SingleChildScrollView(
      child: StyleComponents.pagePaddingWrapper(
        Center(
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
                          labelText: "Outer Postcode",
                        ),
                        controller: _postcodeController,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                              decoration: const InputDecoration(
                                labelText: "Start",
                                hintText: "Input a date",
                                icon: Icon(Icons.calendar_today),
                              ),
                              controller: _startDateController,
                              readOnly: true,
                              onTap: () => _selectDateFor(context),
                            ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child:
                            TextField(
                              decoration: const InputDecoration(
                                labelText: "End",
                                hintText: "Input a date",
                                icon: Icon(Icons.calendar_today),
                              ),
                              controller: _endDateController,
                              readOnly: true,
                              onTap: () => _selectDateFor(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  StyleComponents.paddingWrapper(
                    TextButton(
                      style: style.simpleButtonStyle(),
                      child: Icon(Icons.refresh_rounded),
                      onPressed: _refreshAsync,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20,),
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
                    const SizedBox(height: 20),
                    ShimmerLoading(
                      isLoading: _adaptiveChartWidgetBuilder == null,
                      childGenerator: () => LayoutBuilder(
                        builder: _adaptiveChartWidgetBuilder!.builder,
                      ),
                      placeholder: ShimmerLoading.squarePlaceholder,
                    ),
                    const SizedBox(height: 20),
                    ShimmerLoading(
                      isLoading: _minPeriod == null,
                      childGenerator: () => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Lowest value:"),
                          Text(
                            _minPeriod!.prettyPrintPeriod(),
                            style: StyleComponents.smallText,
                          ),
                          Text(
                            "${_minPeriod?.value.get()} ${CarbonIntensityChartGeneratorFactory.unit}",
                            style: StyleComponents.smallText,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                      placeholder: ShimmerLoading.textPlaceholder,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoricalCarbonIntensityChartGeneratorFactory
    extends CarbonIntensityChartGeneratorFactory {
  final RegionalCarbonIntensityGenerationMixCaller caller;
  final void Function(VoidCallback) setStateFn;

  HistoricalCarbonIntensityChartGeneratorFactory(this.caller, this.setStateFn)
    : super(caller, setStateFn);

  late DateTime from;
  late DateTime to;
  late String regionName;
  late PeriodData<IntensityData> minPeriod;

  void setDateRange(DateTime from, DateTime to) {
    this.from = from;
    this.to = to;
  }

  /// ensure postcode is set in caller before calling
  /// ensure from and to are set before calling
  @override
  Future<LineChartData Function(BuildContext p1, DeviceSize p2)>
  getChartGenerator() async {
    List<RegionalData> historical = await caller.getRegionalDataForPostcodeFrom(
      caller.postcode!,
      from: from,
      modifier: FromModifier.to,
      to: to,
    );

    List<PeriodData<IntensityData>> all = historical.first.intensityData;
    regionName = historical.first.shortname;
    minPeriod = _calculateMinimumPeriod(all);

    int intensityIndex = all.length ~/ 2;

    List<FlSpot> spots = convertToChartData(all);
    return (BuildContext context, DeviceSize size) {
      this.backgroundColor = Theme.of(context).colorScheme.surface;
      return getChartData(spots, intensityIndex, size, context);
    };
  }

  static PeriodData<IntensityData> _calculateMinimumPeriod(
    List<PeriodData<IntensityData>> data,
  ) {
    return data.reduce(
      (first, second) => first.value < second.value ? first : second,
    );
  }
}
