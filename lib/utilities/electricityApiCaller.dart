import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

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

  /// the date format that the api expects
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

  /// fetches the valid products available at given availableAt time
  ///
  /// availableAt should be in the UTC timezone
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

  /// fetches the product information for the given code with tariffs
  ///
  /// tariffsActiveAt datetime should in the UTC timezone
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

  /// fetches the current price for the given product and tariff code
  Future<PeriodData<Rate>> getCurrentPrice(String productCode, String tariffCode) async {
    List<PeriodData<Rate>> prices = await getTariffsFrom(productCode, tariffCode, DateTime.now().toUtc());
    return prices.first;
  }

  /// fetches tariffs given product and tariff code inclusive from given date time from
  ///
  /// Can optionally pass a to date time that will return tariffs until that time (exclusive)
  /// Can optionally pass a RateType to rateType for type of rates fetched
  /// All date times must be in the UTC timezone
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