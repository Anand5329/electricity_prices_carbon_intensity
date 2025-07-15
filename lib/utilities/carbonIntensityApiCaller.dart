import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'httpclient.dart';

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

    final List<PeriodData<IntensityData>> data = await _parseIntensityAndTime(
      response,
    );
    if (data.isEmpty) {
      throw Exception("No intensity found");
    }

    return data.first;
  }

  Future<List<PeriodData<IntensityData>>> getIntensityForDate(
      DateTime date,
      ) async {
    final formattedDate = _dateFormatter.format(date);
    final response = await _get('$_intensity/date/$formattedDate/');
    return !isValidResponse(response)
        ? []
        : await _parseIntensityAndTime(response);
  }

  // TODO: add docstring to mention that from and to should be UTC datetime
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
        modifyString = '${to.toIso8601String()}/';
        break;
      case FromModifier.none:
        modifyString = '';
    }

    final fromFormatted = from.toIso8601String();
    final response = await _get('$_intensity/$fromFormatted/$modifyString');
    return !isValidResponse(response) ? [] : _parseIntensityAndTime(response);
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
      return PeriodData<IntensityData>(
        from: e["from"],
        to: e["to"],
        value: IntensityData.fromJson(e["intensity"]),
      );
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

// ---------------- Modifier Enum ----------------

enum FromModifier { none, forward24, forward48, past24, to }
