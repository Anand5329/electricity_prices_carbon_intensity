import 'package:electricity_prices_and_carbon_intensity/utilities/electricityApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
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
    final style = StyleComponents(Theme.of(context));
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            BigAnimatedCounter(count: _currentPrice, doublePrinter: AnimatedCounter.toNDecimalPlaces(2)),
            _adaptiveChartWidgetBuilder == null
                ? SizedBox()
                : LayoutBuilder(builder: _adaptiveChartWidgetBuilder!.builder),
          ],
        ),
      );
  }
}