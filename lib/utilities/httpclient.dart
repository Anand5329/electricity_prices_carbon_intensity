import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

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
    return this.client.get(Uri.https(baseUrl, "/$endpoint/", queryParams), headers: headers);
  }

  bool isValidResponse(Response response) {
    return 200 <= response.statusCode && response.statusCode <= 299;
  }
}

class CarbonIntensityCaller extends ApiCaller {
  CarbonIntensityCaller() : super(_baseUrl);

  static const String _baseUrl = 'https://api.carbonintensity.org.uk/';
  static const String _intensity = 'intensity';

  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormatter = DateFormat(
    "yyyy-MM-dd'T'HH:mm'Z'",
  );

  static int convertToInt(PeriodData period) {
    final intensity = period.value;
    return intensity.actual ?? intensity.forecast ?? -1;
  }

  Future<PeriodData<IntensityData>> getCurrentIntensity() async {
    final response = await _get('$_intensity/');
    if (!isValidResponse(response)) {
      throw Exception("No intensity found");
    }

    final List<PeriodData<IntensityData>> data = await _parseIntensityAndTime(response);
    if (data.isEmpty) {
      throw Exception("No intensity found");
    }

    return data.first;
  }

  Future<List<PeriodData<IntensityData>>> getIntensityForDate(DateTime date) async {
    final formattedDate = _dateFormatter.format(date);
    final response = await _get('$_intensity/date/$formattedDate/');
    return !isValidResponse(response)
        ? []
        : await _parseIntensityAndTime(response);
  }

  Future<List<PeriodData<IntensityData>>> getIntensityFrom({
    required DateTime from,
    FromModifier modifier = FromModifier.none,
    DateTime? to,
  }) async {
    String modifyString = '';
    switch (modifier) {
      case FromModifier.forward24:
        modifyString = 'fw24h/';
        break;
      case FromModifier.forward48:
        modifyString = 'fw48h/';
        break;
      case FromModifier.past24:
        modifyString = 'pt24h/';
        break;
      case FromModifier.to:
        if (to == null) {
          throw ArgumentError('Please supply a valid "to" datetime.');
        }
        modifyString = '${_dateTimeFormatter.format(to)}/';
        break;
      case FromModifier.none:
        modifyString = '';
    }

    final fromFormatted = _dateTimeFormatter.format(from);
    final response = await _get('$_intensity/$fromFormatted/$modifyString');
    return !isValidResponse(response)
        ? []
        : _parseIntensityAndTime(response);
  }

  Future<Response> _get(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    return await client.get(url);
  }

  List<IntensityData> _parseIntensity(Response response) {
    final periods = _parseIntensityAndTime(response);
    return periods.map((p) => p.value).toList();
  }

  List<PeriodData<IntensityData>> _parseIntensityAndTime(Response response) {
    final json = jsonDecode(response.body);
    final List data = json['data'];
    return data.map((e) {
      return PeriodData<IntensityData>(from: e["from"], to: e["to"], value: IntensityData.fromJson(e["intensity"]));
    }).toList();
  }
}

// ---------------- Data Classes ----------------

class IntensityData {
  final int? forecast;
  final int? actual;
  final String? index;

  IntensityData({this.forecast, this.actual, this.index});

  factory IntensityData.fromJson(Map<String, dynamic> json) {
    return IntensityData(
      forecast: json['forecast'],
      actual: json['actual'],
      index: json['index'],
    );
  }
}

class PeriodData<T> {
  final String from;
  final String to;
  final T value;

  PeriodData({required this.from, required this.to, required this.value});
}

// ---------------- Modifier Enum ----------------

enum FromModifier { none, forward24, forward48, past24, to }
