import 'package:electricity_prices_and_carbon_intensity/utilities/minimumForecaster.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import 'httpclient.dart';

final logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class CarbonIntensityCaller extends ApiCaller
    with MinimumForecaster<IntensityData> {
  CarbonIntensityCaller() : super(_baseUrl);

  static const String _baseUrl = 'https://api.carbonintensity.org.uk/';
  static const String intensity = 'intensity';

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
    final response = await _get('$intensity/');
    return await _getFirstFromIntensityList(response);
  }

  Future<PeriodData<IntensityData>> _getFirstFromIntensityList(
    Response response,
  ) async {
    if (!isValidResponse(response)) {
      throw Exception("No intensity found");
    }

    final List<PeriodData<IntensityData>> data = parseIntensityAndTime(
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
    final response = await _get('$intensity/date/$formattedDate/');
    return !isValidResponse(response) ? [] : parseIntensityAndTime(response);
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
    String modifyString = getModifierString(modifier, to);

    final fromFormatted = from.toIso8601String();
    final response = await _get('$intensity/$fromFormatted/$modifyString');
    return !isValidResponse(response) ? [] : parseIntensityAndTime(response);
  }

  static String getModifierString(FromModifier modifier, DateTime? to) {
    switch (modifier) {
      case FromModifier.forward24:
        return '${FromModifier.forward24}/';
      case FromModifier.forward48:
        return '${FromModifier.forward48}/';
      case FromModifier.past24:
        return '${FromModifier.past24}/';
      case FromModifier.to:
        if (to == null) {
          throw ArgumentError('Please supply a valid "to" datetime.');
        }
        return '${to.toIso8601String()}/';
      case FromModifier.none:
        return FromModifier.none.toString();
    }
  }

  /// forecasts intensity 24 hrs into the future
  @override
  Future<List<PeriodData<IntensityData>>> forecast() async {
    DateTime now = DateTime.now().toUtc();
    return await getIntensityFrom(from: now, modifier: FromModifier.forward24);
  }

  Future<Response> _get(String path) async {
    return getRaw(path);
  }

  @protected
  List<IntensityData> parseIntensity(Response response) {
    final periods = parseIntensityAndTime(response);
    return periods.map((p) => p.value).toList();
  }

  @protected
  List<PeriodData<IntensityData>> parseIntensityAndTime(Response response) {
    final json = jsonDecode(response.body);
    final List data = json['data'];

    return data
        .map((innerJson) => _parseIntensityAndTimeFromJson(innerJson))
        .toList();
  }

  PeriodData<IntensityData> _parseIntensityAndTimeFromJson(
    Map<String, dynamic> innerJson,
  ) {
    return parseTimePeriod(innerJson, IntensityData.fromJson);
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
    Map<String, dynamic> intensity = json["intensity"];
    return IntensityData(
      forecast: intensity['forecast'],
      actual: intensity['actual'],
      index: intensity['index'],
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

  @override
  int get hashCode =>
      (actual ?? 0) * 31 + (forecast ?? 0) * 73 + (index?.hashCode ?? 0);
}

// ---------------- Modifier Enum ----------------

enum FromModifier {
  none(""),
  forward24("fw24h"),
  forward48("fw48h"),
  past24("pt24h"),
  to("to");

  final String _rep;

  const FromModifier(this._rep);

  @override
  String toString() {
    return _rep;
  }
}
