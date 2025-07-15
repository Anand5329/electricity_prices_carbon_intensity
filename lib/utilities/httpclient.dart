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

  bool isValidResponse(Response response) {
    return 200 <= response.statusCode && response.statusCode <= 299;
  }
}


class PeriodData<T> {
  final DateTime from;
  final DateTime to;
  final T value;

  PeriodData.raw(this.from, this.to, this.value);

  PeriodData({required String from, required String to, required T value})
      : this.raw(DateTime.parse(from), DateTime.parse(to), value);
}
