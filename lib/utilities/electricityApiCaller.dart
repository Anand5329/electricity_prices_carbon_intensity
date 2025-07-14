import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ElectricityApiCaller extends ApiCaller {
  static const String _baseUrl = "api.octopus.energy";
  static const String _apiPostFix = "v1/";
  static const String _apiKey = "";
  static final Map<String, String> _authenticationHeader = <String, String>{
    "Authorization": _apiKey,
  };

  static const String _electricityTariffString = "electricity-tariffs";
  static const String _tariffPrefix = "E-1R";
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

  Future<Product> getProductWithCode(String code, {DateTime? tariffsActiveAt}) async {
    String endpoint = "$_products/$code/";
    Map<String, dynamic> queryParams = {};
    if (tariffsActiveAt != null) {
      queryParams.putIfAbsent(_tariffsActiveAt, () => dateFormat.format(tariffsActiveAt));
    }
    Response response = await _get(endpoint, queryParams: queryParams);
    if (isValidResponse(response)) {
      return _parseProduct(response);
    } else {
      throw Exception("Could not fetch product with code $code. \nError: ${response.body}");
    }
  }

  Future<List<Rate>> getTariffsFrom(
    String product,
    String tariffCode,
    DateTime from, {
    DateTime? to,
    RateType rateType = RateType.standardUnitRate,
  }) async {
    String endpoint =
        "$_products/$product/$_electricityTariffString/$tariffCode/$rateType/";
    Map<String, dynamic> queryParams = <String, dynamic>{
      _periodFrom: dateFormat.format(from),
    };
    if (to != null) {
      queryParams.putIfAbsent(_periodTo, () => dateFormat.format(to));
    }
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

  static List<Rate> _parseRates(Response response) {
    List<dynamic> data = _parseListHelper(response);
    return data.map((rate) => Rate.fromJson(rate)).toList();
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

  factory Product.fromJson(jsonData) {
    String date = jsonData["available_from"];
    int index = date.lastIndexOf("+");
    index = (index == -1) ? date.length : index;
    date = "${date.substring(0, index)}Z";
    DateTime availableFrom = ElectricityApiCaller.dateFormat.parse(date);
    final Product product = Product(jsonData["full_name"], availableFrom, jsonData["code"]);
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
  final String validFrom;
  final String validTo;
  final String? paymentMethod;

  const Rate(
    this.valueExcVat,
    this.valueIncVat,
    this.validFrom,
    this.validTo,
    this.paymentMethod,
  );

  factory Rate.fromJson(Map<String, dynamic> jsonData) {
    return Rate(
      jsonData['value_exc_vat'],
      jsonData['value_inc_vat'],
      jsonData['valid_from'],
      jsonData['valid_to'],
      jsonData['payment_method'],
    );
  }
}
