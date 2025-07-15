import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../widgets/chart.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class ElectricityApiCaller extends ApiCaller {
  static const String _baseUrl = "api.octopus.energy";
  static const String _apiPostFix = "v1/";
  static const String _apiKey = "";
  static final Map<String, String> _authenticationHeader = <String, String>{
    "Authorization": _apiKey,
  };

  static const String _electricityTariffString = "electricity-tariffs";
  static const String _products = "products";

  static const String _periodFrom = "period_from";
  static const String _periodTo = "period_to";
  static const String _availableAt = "available_at";
  static const String _tariffsActiveAt = "tariffs_active_at";

  static final DateFormat dateFormat = DateFormat(
    "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'",
  );

  ElectricityApiCaller() : super(_baseUrl);

  Future<Response> _get(String endpoint, {Map<String, dynamic>? queryParams}) {
    return this.getHttps(
      endpoint: _apiPostFix + endpoint,
      queryParams: queryParams,
      headers: _authenticationHeader,
    );
  }

  // TODO: add docstring to mention that availableAt should be UTC datetime
  Future<List<Product>> getProducts({DateTime? availableAt}) async {
    final String endpoint = "$_products/";
    final Map<String, dynamic> queryParams = {};
    if (availableAt != null) {
      queryParams.putIfAbsent(
        _availableAt,
        () => dateFormat.format(availableAt),
      );
    }
    Response response = await _get(endpoint, queryParams: queryParams);
    if (isValidResponse(response)) {
      return _parseProducts(response);
    } else {
      throw Exception("Products not found. Response: ${response.body}");
    }
  }

  Future<Product> getProductWithCode(
    String code, {
    DateTime? tariffsActiveAt,
  }) async {
    String endpoint = "$_products/$code/";
    Map<String, dynamic> queryParams = {};
    if (tariffsActiveAt != null) {
      queryParams.putIfAbsent(
        _tariffsActiveAt,
        () => dateFormat.format(tariffsActiveAt),
      );
    }
    Response response = await _get(endpoint, queryParams: queryParams);
    if (isValidResponse(response)) {
      return _parseProduct(response);
    } else {
      throw Exception(
        "Could not fetch product with code $code. \nError: ${response.body}",
      );
    }
  }

  Future<PeriodData<Rate>> getCurrentPrice(String productCode, String tariffCode) async {
    List<PeriodData<Rate>> prices = await getTariffsFrom(productCode, tariffCode, DateTime.now().toUtc());
    return prices.first;
  }

  // TODO: add docstring to mention that from and to should be UTC datetime
  Future<List<PeriodData<Rate>>> getTariffsFrom(
    String product,
    String tariffCode,
    DateTime from, {
    DateTime? to,
    RateType rateType = RateType.standardUnitRate,
  }) async {
    String endpoint =
        "$_products/$product/$_electricityTariffString/$tariffCode/$rateType/";
    Map<String, dynamic> queryParams = <String, dynamic>{
      _periodFrom: from.toIso8601String(),
    };
    if (to != null) {
      queryParams.putIfAbsent(_periodTo, () => to.toIso8601String());
    }
    // logger.d(queryParams);
    Response response = await _get(endpoint, queryParams: queryParams);
    if (isValidResponse(response)) {
      return _parseRates(response);
    } else {
      throw Exception(
        "Rates not found for product $product with tariff band $tariffCode from $from"
        "\nError: ${response.body}",
      );
    }
  }

  static List<Product> _parseProducts(Response response) {
    List<dynamic> data = _parseListHelper(response);
    return data.map((product) => Product.fromJson(product)).toList();
  }

  static Product _parseProduct(Response response) {
    final json = jsonDecode(response.body);
    return Product.fromJson(json);
  }

  static List<PeriodData<Rate>> _parseRates(Response response) {
    List<dynamic> data = _parseListHelper(response);
    return data.reversed
        .map(
          (json) => PeriodData<Rate>(
            from: json['valid_from'],
            to: json['valid_to'],
            value: Rate.fromJson(json),
          ),
        )
        .toList();
  }

  static List<dynamic> _parseListHelper(Response response) {
    final json = jsonDecode(response.body);
    final int count = json["count"];
    final List data = json["results"];
    if (data.length != count) {
      if (json["next"] == null) {
        throw Exception(
          "Count $count did not match number of results: ${data.length}",
        );
      }
    }
    return data;
  }
}

class Product {
  static const String tariffsKey = "single_register_electricity_tariffs";

  final String name;
  final DateTime availableFrom;
  final String code;
  final List<String> tariffCodes = List.of([]);

  Product(this.name, this.availableFrom, this.code);

  // TODO: fix timezone parsing
  factory Product.fromJson(jsonData) {
    String date = jsonData["available_from"];
    int index = date.lastIndexOf("+");
    index = (index == -1) ? date.length : index;
    date = "${date.substring(0, index)}Z";
    DateTime availableFrom = ElectricityApiCaller.dateFormat.parse(date);
    final Product product = Product(
      jsonData["full_name"],
      availableFrom,
      jsonData["code"],
    );
    _addTariffCodes(jsonData, product);
    return product;
  }

  static void _addTariffCodes(json, Product product) {
    if (json is Map && json.containsKey(tariffsKey)) {
      Map<String, dynamic> tariffs = json[tariffsKey];
      tariffs.forEach((_, tariff) {
        product.tariffCodes.add(tariff["code"].toString());
      });
    }
  }
}

enum RateType {
  standardUnitRate("standard-unit-rates"),
  dayUnitRate("day-unit-rates"),
  nightUnitRate("night-unit-rates"),
  standingChargeRate("standing-charges");

  const RateType(this.stringRep);

  final String stringRep;

  @override
  String toString() {
    return stringRep;
  }
}

class Rate {
  final double valueExcVat;
  final double valueIncVat;
  final String? paymentMethod;

  const Rate(this.valueExcVat, this.valueIncVat, this.paymentMethod);

  factory Rate.fromJson(Map<String, dynamic> jsonData) {
    return Rate(
      jsonData['value_exc_vat'],
      jsonData['value_inc_vat'],
      jsonData['payment_method'],
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
