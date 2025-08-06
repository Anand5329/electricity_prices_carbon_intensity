import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/settings.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/style.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../utilities/gasApiCaller.dart';
import '../utilities/octopusApiCaller.dart';
import 'animatedCounter.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class GasPricesPage extends StatefulWidget {
  final String title;
  static const String defaultProductCode = "VAR-BB-23-04-01";
  static const String defaultTariffCode = "G-1R-VAR-BB-23-04-01-P";

  const GasPricesPage({super.key, this.title = "Gas Prices"});

  @override
  State<GasPricesPage> createState() => _GasPricesPageState();
}

class _GasPricesPageState extends State<GasPricesPage>
    with AutomaticKeepAliveClientMixin<GasPricesPage> {
  static Product defaultProduct = Product(
    "Variable 2024 v1",
    DateTime.now().toUtc(),
    GasPricesPage.defaultProductCode,
  );
  static Tariff defaultTariff = Tariff(
    "_P",
    GasPricesPage.defaultTariffCode,
    "",
    TariffType.gas,
  );

  static const double _widthThreshold = 600;
  static const double _menuWidth = 120;

  double _currentPrice = 0;
  PeriodData<Rate>? _currentPeriod;
  String _productCode = GasPricesPage.defaultProductCode;
  String _tariffCode = GasPricesPage.defaultTariffCode;

  List<Product> _productList = [defaultProduct];
  List<Tariff> _tariffList = [defaultTariff];

  late GasApiCaller _caller;
  bool _isApiKeyValid = false;

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
    _caller = GasApiCaller(_productCode, _tariffCode);
    _setupProductsAndTariffs();
    _refreshAsync();
  }

  void _refreshAsync() {
    _refreshCurrentPrice();
  }

  Future<void> _setupProductsAndTariffs() async {
    try {
      _productList = await _caller.getProducts();
      _refreshTariffCodeList();
    } on InvalidApiKeyError {
      setState(() {
        _isApiKeyValid = false;
      });
    }
  }

  Future<void> _refreshTariffCodeList() async {
    final product = await _caller.getProductWithCode(code: _productCode);
    setState(() {
      _tariffList = product.tariffCodes
          .where((tariff) => tariff.type == TariffType.gas)
          .toList(growable: false);
    });
  }

  Future<void> _refreshCurrentPrice() async {
    setState(() {
      _currentPrice = 0;
    });
    try {
      PeriodData<Rate> period = await _caller.getCurrentPrice(
        productCode: _productCode,
        tariffCode: _tariffCode,
      );
      setState(() {
        _currentPrice = period.value.valueIncVat;
        _currentPeriod = period;
        _isApiKeyValid = true;
      });
    } on InvalidApiKeyError {
      setState(() {
        _isApiKeyValid = false;
      });
    }
    keepAlive = _isApiKeyValid;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    StyleComponents style = StyleComponents(Theme.of(context));
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return !_isApiKeyValid
            ? style.getInvalidApiKeyWidget()
            : SingleChildScrollView(
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
                                  GasPricesPage.defaultProductCode;
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
                                  GasPricesPage.defaultTariffCode;
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BigAnimatedCounter(
                            count: _currentPrice,
                            doublePrinter: AnimatedCounter.toNDecimalPlaces(2),
                          ),
                          const SizedBox(width: 10),
                          style.subHeadingTextWithPadding("p/kWh"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _currentPeriod == null
                          ? const SizedBox(height: 20)
                          : Text(
                              "Price valid since ${_currentPeriod!.prettyPrintPeriod()}",
                              style: StyleComponents.smallText,
                            ),
                    ],
                  ),
                ),
              );
      },
    );
  }
}
