import 'package:electricity_prices_and_carbon_intensity/utilities/electricityApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';


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
    final style = StyleComponents(Theme.of(context));
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            style.headlineTextWithPadding(widget.title),
            _adaptiveChartWidgetBuilder == null
                ? SizedBox()
                : LayoutBuilder(builder: _adaptiveChartWidgetBuilder!.builder),
          ],
        ),
      );
  }
}