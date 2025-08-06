import 'package:electricity_prices_and_carbon_intensity/utilities/electricityApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../utilities/octopusApiCaller.dart';
import 'animatedCounter.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class ElectricityPricesPage extends StatefulWidget {
  final String title;
  static const String defaultProductCode = "AGILE-24-10-01";
  static const String defaultTariffCode = "E-1R-AGILE-24-10-01-C";

  const ElectricityPricesPage({super.key, this.title = "Electricity Prices"});

  @override
  State<ElectricityPricesPage> createState() => _ElectricityPricesPageState();
}

class _ElectricityPricesPageState extends State<ElectricityPricesPage>
    with AutomaticKeepAliveClientMixin<ElectricityPricesPage> {
  static Product defaultProduct = Product(
    "Agile Octopus October 2024 v1",
    DateTime.now().toUtc(),
    ElectricityPricesPage.defaultProductCode,
  );
  static Tariff defaultTariff = Tariff(
    "_C",
    ElectricityPricesPage.defaultTariffCode,
    "",
    TariffType.electricity,
  );

  static const double _widthThreshold = 600;
  static const double _menuWidth = 120;

  double _currentPrice = 0;
  String _productCode = ElectricityPricesPage.defaultProductCode;
  String _tariffCode = ElectricityPricesPage.defaultTariffCode;

  List<Product> _productList = [defaultProduct];
  List<Tariff> _tariffList = [defaultTariff];

  late ElectricityApiCaller _caller;
  late ElectricityPricesChartGeneratorFactory _chartGeneratorFactory;
  AdaptiveChartWidgetBuilder? _adaptiveChartWidgetBuilder;
  PeriodData<Rate>? _minPeriod;

  bool _keepAlive = true;

  bool get keepAlive => _keepAlive;
  set keepAlive(bool value) {
    _keepAlive = value;
    updateKeepAlive();
  }

  @override
  bool get wantKeepAlive => keepAlive;

  @override
  void initState() {
    super.initState();
    _caller = ElectricityApiCaller(_productCode, _tariffCode);
    _chartGeneratorFactory = ElectricityPricesChartGeneratorFactory(
      _caller,
      _productCode,
      _tariffCode,
      setState,
    );
    _setupProductsAndTariffs();
    _refreshAsync();
  }

  void _refreshAsync() {
    _refreshElectricityPricesChart();
    _refreshCurrentPrice();
  }

  Future<void> _setupProductsAndTariffs() async {
    _productList = await _caller.getProducts();
    _refreshTariffCodeList();
  }

  Future<void> _refreshTariffCodeList() async {
    final product = await _caller.getProductWithCode(code: _productCode);
    setState(() {
      _tariffList = product.tariffCodes
          .where((tariff) => tariff.type == TariffType.electricity)
          .toList(growable: false);
    });
  }

  Future<void> _refreshCurrentPrice() async {
    PeriodData<Rate> price = await _caller.getCurrentPrice(
      productCode: _productCode,
      tariffCode: _tariffCode,
    );
    setState(() {
      _currentPrice = price.value.valueIncVat;
    });
  }

  Future<void> _refreshElectricityPricesChart() async {
    _chartGeneratorFactory.productCode = _productCode;
    _chartGeneratorFactory.tariffCode = _tariffCode;
    final generator = await _chartGeneratorFactory.getChartGenerator();
    _caller.productCode = _productCode;
    _caller.tariffCode = _tariffCode;
    final minPeriod = await _caller.forecastMinimum();
    setState(() {
      _adaptiveChartWidgetBuilder = AdaptiveChartWidgetBuilder(generator);
      _minPeriod = minPeriod;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    StyleComponents style = StyleComponents(Theme.of(context));
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DropdownMenu<Product>(
                      width: constraints.maxWidth > _widthThreshold
                          ? null
                          : _menuWidth,
                      initialSelection: defaultProduct,
                      dropdownMenuEntries: _productList
                          .map(
                            (product) => DropdownMenuEntry(
                              value: product,
                              label: product.name,
                            ),
                          )
                          .toList(),
                      onSelected: (Product? product) {
                        _productCode =
                            product?.code ??
                            ElectricityPricesPage.defaultProductCode;
                        _refreshTariffCodeList();
                      },
                      requestFocusOnTap: true,
                      label: const Text("Product"),
                    ),
                    const SizedBox(width: 40),
                    DropdownMenu<Tariff>(
                      width: constraints.maxWidth > _widthThreshold
                          ? null
                          : _menuWidth,
                      initialSelection: defaultTariff,
                      dropdownMenuEntries: _tariffList
                          .map(
                            (tariff) => DropdownMenuEntry(
                              value: tariff,
                              label: tariff.name,
                            ),
                          )
                          .toList(),
                      onSelected: (Tariff? tariff) {
                        _tariffCode =
                            tariff?.code ??
                            ElectricityPricesPage.defaultTariffCode;
                      },
                      requestFocusOnTap: true,
                      label: const Text("Tariff"),
                    ),
                    const SizedBox(width: 24),
                    TextButton(
                      style: style.simpleButtonStyle(),
                      child: Icon(Icons.refresh_rounded),
                      onPressed: _refreshAsync,
                    ),
                  ],
                ),
                BigAnimatedCounter(
                  count: _currentPrice,
                  doublePrinter: AnimatedCounter.toNDecimalPlaces(2),
                ),
                SizedBox(height: 20),
                _adaptiveChartWidgetBuilder == null
                    ? SizedBox()
                    : LayoutBuilder(
                        builder: _adaptiveChartWidgetBuilder!.builder,
                      ),
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
                            "${_minPeriod?.value} ${ElectricityPricesChartGeneratorFactory.unit}",
                            style: StyleComponents.smallText,
                          ),
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ElectricityPricesChartGeneratorFactory
    extends ChartGeneratorFactory<Rate> {
  static const String unit = "p/kWh";

  final ElectricityApiCaller _caller;
  String productCode;
  String tariffCode;

  static const List<double> priceStops = [10, 20, 50, 75, 100];
  static const List<double> fractionPriceStops = [0.1, 0.2, 0.5, 0.75, 1];
  static const LinearGradient priceGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: ChartGeneratorFactory.defaultColors,
    stops: fractionPriceStops,
  );

  ElectricityPricesChartGeneratorFactory.all(
    this._caller,
    this.productCode,
    this.tariffCode, {
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

  ElectricityPricesChartGeneratorFactory(
    ElectricityApiCaller caller,
    String productCode,
    String tariffCode,
    void Function(VoidCallback) setState,
  ) : this.all(
        caller,
        productCode,
        tariffCode,
        setStateFn: setState,
        xAxisName: "Time",
        yAxisName: "Price ($unit)",
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
        specificGradient: priceGradient,
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
    List<PeriodData<Rate>> rates = await _caller.getTariffsFrom(
      productCode: productCode,
      tariffCode: tariffCode,
      yesterday,
      to: tomorrow,
    );
    int currentSpotIndex = _getCurrentSpotIndex(rates);
    List<FlSpot> spots = convertToChartData(rates);

    return (BuildContext context, DeviceSize size) {
      this.backgroundColor = Theme.of(context).colorScheme.surface;
      return getChartData(spots, currentSpotIndex, size, context);
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
