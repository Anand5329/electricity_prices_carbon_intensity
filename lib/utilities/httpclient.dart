import 'package:electricity_prices_and_carbon_intensity/widgets/chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';

class ApiCaller {
  final client = Client();
  final String baseUrl;

  ApiCaller(this.baseUrl);

  @protected
  Future<Response> getHttps({
    required String endpoint,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) {
    return this.client.get(
      Uri.https(baseUrl, "/$endpoint/", queryParams),
      headers: headers,
    );
  }

  @protected
  Future<Response> getRaw(String path) async {
    final url = Uri.parse('$baseUrl$path');
    return await client.get(url);
  }

  @protected
  PeriodData<T> parseTimePeriod<T extends Comparable<T>>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonFn,
  ) {
    return PeriodData<T>(
      from: json["from"],
      to: json["to"],
      value: fromJsonFn(json),
    );
  }

  bool isValidResponse(Response response) {
    return 200 <= response.statusCode && response.statusCode <= 299;
  }
}

class PeriodData<T extends Comparable<T>> implements Comparable<PeriodData<T>> {
  static final DateTime start = DateTime.utc(-271821, 04, 20);
  static final DateTime end = DateTime.utc(275760, 09, 13);
  final DateTime from;
  final DateTime to;
  final T value;

  PeriodData.raw(this.from, this.to, this.value);

  PeriodData({String? from, String? to, required T value})
    : this.raw(
        from == null ? start : DateTime.parse(from),
        to == null ? end : DateTime.parse(to),
        value,
      );

  bool operator ==(Object other) {
    return other is PeriodData<T> &&
        this.value == other.value &&
        this.from == other.from &&
        this.to == other.to;
  }

  bool operator >(PeriodData<T> other) {
    return this.value.compareTo(other.value) > 0;
  }

  bool operator <(PeriodData<T> other) {
    return this.value.compareTo(other.value) < 0;
  }

  bool operator >=(PeriodData<T> other) {
    return this.value.compareTo(other.value) >= 0;
  }

  bool operator <=(PeriodData<T> other) {
    return this.value.compareTo(other.value) <= 0;
  }

  @override
  int compareTo(PeriodData<T> other) {
    return this.value.compareTo(other.value);
  }

  String prettyPrintPeriod() {
    return "${from.toLocal().prettyPrintDateTime()} - ${to.toLocal().prettyPrintTime()}";
  }
}
