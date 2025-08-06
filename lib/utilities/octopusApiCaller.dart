import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

abstract base class OctopusApiCaller extends ApiCaller {
  static const String _baseUrl = "api.octopus.energy";
  static const String _apiPostFix = "v1/";
  static const String _apiKey = "";
  static const String _auth = "Authorization";

  static const int apiKeyNotFoundStatusCode = -400;

  static const String _products = "products";

  static const String _periodFrom = "period_from";
  static const String _periodTo = "period_to";
  static const String _availableAt = "available_at";
  static const String _tariffsActiveAt = "tariffs_active_at";

  /// the date format that the api expects
  static final DateFormat dateFormat = DateFormat(
    "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'",
  );

  /// the product code that will be used on subsequent calls if none passed
  String productCode;

  /// the tariff code that will be used on subsequent calls if none passed
  String tariffCode;

  /// contains full products at the time when _initProducts was last called with
  /// availableAt or when called the first time
  List<Product>? _fullProducts;

  final Settings _settings = Settings();
  final Map<String, String> _authenticationHeader = {};

  OctopusApiCaller(this.productCode, this.tariffCode) : super(_baseUrl);

  Future<Response> _get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      Map<String, String> _authHeader = await _getAuthenticationHeader();
      assert(_authHeader == _authenticationHeader);
    } catch (e) {
      return Response(e.toString(), apiKeyNotFoundStatusCode);
    }
    return this.getHttps(
      endpoint: _apiPostFix + endpoint,
      queryParams: queryParams,
      headers: _authenticationHeader,
    );
  }

  Future<Map<String, String>> _getAuthenticationHeader() async {
    try {
      String apiKey = await _settings.readSavedApiKey();
      _authenticationHeader.putIfAbsent(_auth, () => apiKey);
      return _authenticationHeader;
    } on InvalidApiKeyError {
      logger.d("API Key not provided yet");
      rethrow;
    } catch (e) {
      logger.e("Error encountered while reading API key: $e");
      rethrow;
    }
  }

  Future<List<Product>> _initProducts({DateTime? availableAt}) async {
    if (_fullProducts != null && availableAt == null) {
      return _fullProducts!;
    }
    _fullProducts = [];
    List<Product> allProducts = await getAllProducts();
    for (var product in allProducts) {
      Product fullProduct = await getProductWithCode(code: product.code);
      _fullProducts!.add(fullProduct);
    }
    return _fullProducts!;
  }

  /// fetches fullProducts that have valid tariffs
  ///
  /// availableAt should be in the UTC timezone
  Future<List<Product>> getProducts({DateTime? availableAt});

  /// fetches specific products that have valid tariffs of type passed in
  ///
  /// availableAt should be in the UTC timezone
  @protected
  Future<List<Product>> getProductsOf(
    TariffType tariffType, {
    DateTime? availableAt,
  }) async {
    List<Product> allProducts = await _initProducts(availableAt: availableAt);
    return allProducts
        .where(
          (product) => product.tariffCodes
              .where((tariff) => tariff.type == tariffType)
              .isNotEmpty,
        )
        .toList(growable: false);
  }

  /// fetches the valid products available at given availableAt time
  ///
  /// availableAt should be in the UTC timezone
  Future<List<Product>> getAllProducts({DateTime? availableAt}) async {
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
      if (response.statusCode == apiKeyNotFoundStatusCode) {
        throw InvalidApiKeyError();
      }
      throw Exception("Products not found. Response: ${response.body}");
    }
  }

  /// fetches the product information for the given code with tariffs
  ///
  /// tariffsActiveAt datetime should in the UTC timezone
  Future<Product> getProductWithCode({
    String? code,
    DateTime? tariffsActiveAt,
  }) async {
    code = code ?? productCode;
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
      if (response.statusCode == apiKeyNotFoundStatusCode) {
        throw InvalidApiKeyError();
      }
      throw Exception(
        "Could not fetch product with code $code. \nError: ${response.body}",
      );
    }
  }

  /// fetches the current price for the given product and tariff code
  ///
  /// If either code is null, will use as replacement instance fields productCode and tariffCode
  Future<PeriodData<Rate>> getCurrentPrice({
    String? productCode,
    String? tariffCode,
  });

  /// fetches tariffs given product code, tariff string and tariff code inclusive from given date time from
  ///
  /// If either code is null, will use as replacement instance fields productCode and tariffCode
  /// Can optionally pass a to date time that will return tariffs until that time (exclusive)
  /// Can optionally pass a RateType to rateType for type of rates fetched
  /// All date times must be in the UTC timezone
  @protected
  Future<List<PeriodData<Rate>>> getGenericTariffsFrom(
    DateTime from, {
    String? productCode,
    required TariffType tariffType,
    String? tariffCode,
    DateTime? to,
    RateType rateType = RateType.standardUnitRate,
  }) async {
    productCode = productCode ?? this.productCode;
    tariffCode = tariffCode ?? this.tariffCode;
    String endpoint =
        "$_products/$productCode/$tariffType/$tariffCode/$rateType/";
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
      if (response.statusCode == apiKeyNotFoundStatusCode) {
        throw InvalidApiKeyError();
      }
      throw Exception(
        "$tariffType rates not found for product $productCode with tariff band $tariffCode from $from"
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
  static const String electricityTariffsKey =
      "single_register_electricity_tariffs";
  static const String gasTariffsKey = "single_register_gas_tariffs";

  final String name;
  final DateTime availableFrom;
  final String code;
  final List<Tariff> tariffCodes = List.of([]);

  Product(this.name, this.availableFrom, this.code);

  factory Product.fromJson(jsonData) {
    String date = jsonData["available_from"];
    DateTime availableFrom = DateTime.parse(date);
    final Product product = Product(
      jsonData["full_name"],
      availableFrom,
      jsonData["code"],
    );
    _addTariffCodes(jsonData, product);
    return product;
  }

  static void _addTariffCodes(json, Product product) {
    _addTariffCodesHelper(json, product, tariffType: TariffType.electricity);
    _addTariffCodesHelper(json, product, tariffType: TariffType.gas);
  }

  static void _addTariffCodesHelper(
    json,
    Product product, {
    required TariffType tariffType,
  }) {
    String tariffsKey;
    switch (tariffType) {
      case TariffType.electricity:
        tariffsKey = electricityTariffsKey;
        break;
      case TariffType.gas:
        tariffsKey = gasTariffsKey;
        break;
    }
    if (json is Map && json.containsKey(tariffsKey)) {
      Map<String, dynamic> tariffs = json[tariffsKey];
      tariffs.forEach((name, payment) {
        payment.forEach((method, tariff) {
          product.tariffCodes.add(
            Tariff(name, tariff[Tariff.codeKey], method, tariffType),
          );
        });
      });
    }
  }
}

class Tariff {
  static const String codeKey = "code";

  final String name;
  final String code;
  final String paymentMethod;
  final TariffType type;

  Tariff(this.name, this.code, this.paymentMethod, this.type);

  bool operator ==(Object other) {
    return other is Tariff &&
        this.code == other.code &&
        this.name == other.name &&
        this.type == other.type &&
        this.paymentMethod == other.paymentMethod;
  }

  @override
  int get hashCode =>
      37 * code.hashCode +
      73 * name.hashCode +
      103 * type.hashCode +
      113 * paymentMethod.hashCode;
}

enum TariffType {
  gas("gas-tariffs"),
  electricity("electricity-tariffs");

  const TariffType(this.stringRep);

  final String stringRep;

  @override
  String toString() {
    return stringRep;
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

class Rate implements Comparable<Rate> {
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

  bool operator >(Rate other) {
    return this.valueIncVat > other.valueIncVat;
  }

  bool operator <(Rate other) {
    return this.valueIncVat < other.valueIncVat;
  }

  bool operator >=(Rate other) {
    return this.valueIncVat >= other.valueIncVat;
  }

  bool operator <=(Rate other) {
    return this.valueIncVat <= other.valueIncVat;
  }

  bool operator ==(Object other) {
    return other is Rate &&
        this.valueIncVat == other.valueIncVat &&
        this.valueExcVat == other.valueExcVat &&
        this.paymentMethod == other.paymentMethod;
  }

  @override
  String toString() {
    return valueIncVat.toStringAsFixed(2);
  }

  @override
  int compareTo(Rate other) {
    return (this.valueIncVat - other.valueIncVat).compareTo(0);
  }

  @override
  int get hashCode =>
      (valueIncVat * 31).round() +
      (valueExcVat * 73).round() +
      113 * paymentMethod.hashCode;
}
