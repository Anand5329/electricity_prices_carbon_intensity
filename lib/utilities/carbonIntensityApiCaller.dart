import 'package:electricity_prices_and_carbon_intensity/utilities/minimumForecaster.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'httpclient.dart';

class CarbonIntensityCaller extends ApiCaller
    with MinimumForecaster<IntensityData> {
  CarbonIntensityCaller() : super(_baseUrl);

  static const String _baseUrl = 'https://api.carbonintensity.org.uk/';
  static const String _intensity = 'intensity';

  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormatter = DateFormat(
    "yyyy-MM-dd'T'HH:mm'Z'",
  );

  /// converts PeriodData period to an int value
  static int convertToInt(PeriodData<IntensityData> period) {
    final intensity = period.value;
    return intensity.actual ?? intensity.forecast ?? -1;
  }

  /// fetches the current (latest) carbon intensity
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

  /// fetches carbon intensity data for a particular date
  Future<List<PeriodData<IntensityData>>> getIntensityForDate(
    DateTime date,
  ) async {
    final formattedDate = _dateFormatter.format(date);
    final response = await _get('$_intensity/date/$formattedDate/');
    return !isValidResponse(response)
        ? []
        : await _parseIntensityAndTime(response);
  }

  /// fetches intensity data for the time period after the given from date and time
  ///
  /// Can optionally pass in a to date time (exclusive) until which carbon intensity data
  /// will be fetched. The modifier must be se to 'to'
  /// Can optionally pass in different modifiers: fw24h, pt24h, fw48h and to
  /// All date time values must be in the UTC timezone.
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

  /// forecasts intensity 24 hrs into the future
  @override
  Future<List<PeriodData<IntensityData>>> forecast() async {
    DateTime now = DateTime.now().toUtc();
    return await getIntensityFrom(from: now, modifier: FromModifier.forward24);
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

class IntensityData implements Comparable<IntensityData> {
  final int? forecast;
  final int? actual;
  final String? index;

  IntensityData({this.forecast, this.actual, this.index});

  int get() {
    return actual ?? forecast ?? -1;
  }

  factory IntensityData.fromJson(Map<String, dynamic> json) {
    return IntensityData(
      forecast: json['forecast'],
      actual: json['actual'],
      index: json['index'],
    );
  }

  @override
  int compareTo(IntensityData other) {
    return this.get().compareTo(other.get());
  }

  bool operator >(IntensityData other) {
    return this.get() > other.get();
  }

  bool operator <(IntensityData other) {
    return this.get() < other.get();
  }

  bool operator >=(IntensityData other) {
    return this.get() >= other.get();
  }

  bool operator <=(IntensityData other) {
    return this.get() <= other.get();
  }

  @override
  bool operator ==(other) {
    return other is IntensityData &&
        this.actual == other.actual &&
        this.forecast == other.forecast &&
        this.index == other.index;
  }
}

// ---------------- Modifier Enum ----------------

enum FromModifier { none, forward24, forward48, past24, to }
