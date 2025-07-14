import 'package:electricity_prices_and_carbon_intensity/utilities/electricityApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';


var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class ElectricityPrices extends StatefulWidget {
  final String title = "Electricity Prices";

  const ElectricityPrices();

  @override
  State<ElectricityPrices> createState() => _ElectricityState();
}

class _ElectricityState extends State<ElectricityPrices> {
  static const String defaultProductCode = "AGILE-24-10-01";
  static const String defaultTariffCode = "E-1R-AGILE-24-10-01-C";

  String _productCode = defaultProductCode;
  String _tariffCode = defaultTariffCode;
  late ElectricityPricesChartGeneratorFactory _chartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;

  @override
  void initState() {
    _chartGeneratorFactory = ElectricityPricesChartGeneratorFactory(ElectricityApiCaller(), defaultProductCode, defaultTariffCode, setState);
    _refreshElectricityPricesChart();
  }

  Future<void> _refreshElectricityPricesChart() async {
    var generator = await _chartGeneratorFactory.getChartGenerator();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(generator);
    });
  }
  //TODO: add selector for product and tariff


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _adaptiveChartWidgetBuilder == null
                ? SizedBox()
                : LayoutBuilder(builder: _adaptiveChartWidgetBuilder!.builder),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshElectricityPricesChart,
        tooltip: 'Refresh Electricity Prices',
        child: const Icon(Icons.refresh_rounded),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}