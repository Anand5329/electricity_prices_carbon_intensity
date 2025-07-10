import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ApiCaller {
  final client = Client();
  final String baseUrl;

  ApiCaller(this.baseUrl);

  Future<Response> getHtttps({
    required String endpoint,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) {
    return this.client.get(Uri.https(baseUrl + endpoint, "", queryParams));
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

  static int convertToInt(IntensityData intensity) {
    return intensity.actual != null
        ? intensity.actual!
        : intensity.forecast != null
        ? intensity.forecast!
        : -1;
  }

  Future<IntensityData> getCurrentIntensity() async {
    final response = await _get('$_intensity/');
    if (!isValidResponse(response)) {
      throw Exception("No intensity found");
    }

    final List<IntensityData> data = await _parseIntensity(response);
    if (data.isEmpty) {
      throw Exception("No intensity found");
    }

    return data.first;
  }

  Future<List<PeriodData>> getIntensityForDate(DateTime date) async {
    final formattedDate = _dateFormatter.format(date);
    final response = await _get('$_intensity/date/$formattedDate/');
    return !isValidResponse(response)
        ? []
        : await _parseIntensityAndTime(response);
  }

  Future<List<PeriodData>> getIntensityFrom({
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
        : await _parseIntensityAndTime(response);
  }

  Future<Response> _get(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    return await client.get(url);
  }

  Future<List<IntensityData>> _parseIntensity(Response response) async {
    final periods = await _parseIntensityAndTime(response);
    return periods.map((p) => p.intensity).toList();
  }

  Future<List<PeriodData>> _parseIntensityAndTime(Response response) async {
    final json = jsonDecode(response.body);
    final List data = json['data'];
    return data.map((e) => PeriodData.fromJson(e)).toList();
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

class PeriodData {
  final String from;
  final String to;
  final IntensityData intensity;

  PeriodData({required this.from, required this.to, required this.intensity});

  factory PeriodData.fromJson(Map<String, dynamic> json) {
    return PeriodData(
      from: json['from'],
      to: json['to'],
      intensity: IntensityData.fromJson(json['intensity']),
    );
  }
}

// ---------------- Modifier Enum ----------------

enum FromModifier { none, forward24, forward48, past24, to }
