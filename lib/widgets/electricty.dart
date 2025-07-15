import 'package:electricity_prices_and_carbon_intensity/utilities/electricityApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import 'animatedCounter.dart';


var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class ElectricityPricesPage extends StatefulWidget {
  final String title;

  const ElectricityPricesPage({super.key, this.title = "Electricity Prices"});

  @override
  State<ElectricityPricesPage> createState() => _ElectricityPricesPageState();
}

class _ElectricityPricesPageState extends State<ElectricityPricesPage> {
  static const String defaultProductCode = "AGILE-24-10-01";
  static const String defaultTariffCode = "E-1R-AGILE-24-10-01-C";

  double _currentPrice = 0;
  String _productCode = defaultProductCode;
  String _tariffCode = defaultTariffCode;

  late ElectricityApiCaller _caller;
  late ElectricityPricesChartGeneratorFactory _chartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;

  @override
  void initState() {
    super.initState();
    _caller = ElectricityApiCaller();
    _chartGeneratorFactory = ElectricityPricesChartGeneratorFactory(_caller, defaultProductCode, defaultTariffCode, setState);
    _refreshElectricityPricesChart();
    _refreshCurrentPrice();
  }

  Future<void> _refreshCurrentPrice() async {
    PeriodData<Rate> price = await _caller.getCurrentPrice(_productCode, _tariffCode);
    setState(() {
      _currentPrice = price.value.valueIncVat;
    });
  }

  Future<void> _refreshElectricityPricesChart() async {
    final generator = await _chartGeneratorFactory.getChartGenerator();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(generator);
    });
  }
  //TODO: add selector for product and tariff


  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            BigAnimatedCounter(count: _currentPrice, doublePrinter: AnimatedCounter.toNDecimalPlaces(2)),
            SizedBox(height: 40),
            _adaptiveChartWidgetBuilder == null
                ? SizedBox()
                : LayoutBuilder(builder: _adaptiveChartWidgetBuilder!.builder),
          ],
        ),
      );
  }
}

class ElectricityPricesChartGeneratorFactory
    extends ChartGeneratorFactory<Rate> {

  final ElectricityApiCaller _caller;
  String _productCode;
  String _tariffCode;

  static const List<double> priceStops = [10, 20, 50, 75, 100];
  static const List<double> fractionPriceStops = [0.1, 0.2, 0.5, 0.75, 1];
  static const LinearGradient priceGradient =
  LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: ChartGeneratorFactory.defaultColors, stops: fractionPriceStops);

  ElectricityPricesChartGeneratorFactory.all(
      this._caller,
      this._productCode,
      this._tariffCode,
      {
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
        super.textStyle = const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      });

  ElectricityPricesChartGeneratorFactory(ElectricityApiCaller caller, String productCode, String tariffCode, void Function(VoidCallback) setState):
        this.all(caller, productCode, tariffCode,
          setStateFn: setState,
          xAxisName: "Time",
          yAxisName: "Price (p/kWh)",
          intervalHoursForLargeWidth: 5,
          intervalHours: 12,
          maxPossibleY: 100,
          yInterval: 4,
          maxY: 100,
          minY: 0,
          yStops: priceStops,
          fractionYStops: fractionPriceStops,
          yColors: ChartGeneratorFactory.defaultColors,
          yGradient: priceGradient,
          specificGradient: priceGradient
      );


  @override
  FlSpot convertPeriodToSpot(PeriodData<Rate> period) {
    return FlSpot(
      (period.from.toLocal().millisecondsSinceEpoch +
          period.to.toLocal().millisecondsSinceEpoch) /
          2,
      period.value.valueIncVat,
    );
  }

  @override
  Future<LineChartData Function(BuildContext context, DeviceSize size)>
  getChartGenerator() async {
    DateTime yesterday = DateTime.now().toUtc().subtract(Duration(days: 1));
    DateTime tomorrow = yesterday.add(Duration(days: 2));
    List<PeriodData<Rate>> rates = await _caller.getTariffsFrom(_productCode, _tariffCode, yesterday, to: tomorrow);
    int currentSpotIndex = _getCurrentSpotIndex(rates);
    List<FlSpot> spots = convertToChartData(rates);

    return (BuildContext context, DeviceSize size) {
      this.backgroundColor = Theme.of(context).colorScheme.surface;
      return getChartData(spots, currentSpotIndex, size);
    };
  }

  static int _getCurrentSpotIndex(List<PeriodData<Rate>> rates) {
    DateTime now = DateTime.now().toUtc();
    for (var i = 0; i < rates.length; i++) {
      if (rates[i].from.isBefore(now) && rates[i].to.isAfter(now)) {
        return i;
      }
    }
    return rates.length - 1;
  }
}