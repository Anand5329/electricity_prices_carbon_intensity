import 'package:electricity_prices_and_carbon_intensity/utilities/minimumForecaster.dart';
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
    return await _getFirstFromIntensityList(response);
  }

  Future<PeriodData<IntensityData>> _getFirstFromIntensityList(
    Response response,
  ) async {
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
    String modifyString = _getModifierString(modifier, to);

    final fromFormatted = from.toIso8601String();
    final response = await _get('$_intensity/$fromFormatted/$modifyString');
    return !isValidResponse(response) ? [] : _parseIntensityAndTime(response);
  }

  static String _getModifierString(FromModifier modifier, DateTime? to) {
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

  List<IntensityData> _parseIntensity(Response response) {
    final periods = _parseIntensityAndTime(response);
    return periods.map((p) => p.value).toList();
  }

  List<PeriodData<IntensityData>> _parseIntensityAndTime(Response response) {
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

class RegionalCarbonIntensityCaller extends CarbonIntensityCaller
    with MinimumForecaster<IntensityData> {
  static const String _regional = "regional/";
  static const String _regionid = "${RegionalIntensityData._regionid}/";
  static const String _postcode = "postcode/";

  String? postcode;
  int? regionId;

  RegionalCarbonIntensityCaller({this.postcode, this.regionId}) : super();

  /// fetches current intensity data for postcode
  Future<PeriodData<IntensityData>> getCurrentIntensityForPostcode(
    String postcode,
  ) async {
    final regionalIntensity = await getRegionalIntensityDataForPostcode(
      postcode,
    );
    if (regionalIntensity.intensityData.isEmpty) {
      throw Exception("No intensity data found!");
    }
    return regionalIntensity.intensityData.first;
  }

  /// fetches current intensity data for region id
  Future<PeriodData<IntensityData>> getCurrentIntensityForRegionId(
    int regionId,
  ) async {
    final regionalIntensity = await getRegionalIntensityDataForRegionId(
      regionId,
    );
    if (regionalIntensity.intensityData.isEmpty) {
      throw Exception("No intensity data found!");
    }
    return regionalIntensity.intensityData.first;
  }

  /// fetches current regional intensity data for postcode
  Future<RegionalIntensityData> getRegionalIntensityDataForPostcode(
    String postcode,
  ) async {
    Response response = await _getResponseForPostcode(postcode);
    List<RegionalIntensityData> regions = _parseRegionalData(response);
    if (regions.isEmpty) {
      throw Exception("No regional data found after parsing!");
    }
    return regions.first;
  }

  /// fetches current regional intensity data for region id
  Future<RegionalIntensityData> getRegionalIntensityDataForRegionId(
    int regionId,
  ) async {
    Response response = await _getResponseForRegionId(regionId);
    List<RegionalIntensityData> regions = _parseRegionalData(response);
    if (regions.isEmpty) {
      throw Exception("No regional data found after parsing!");
    }
    return regions.first;
  }

  /// fetches regional data for postcode from a particular date
  Future<List<RegionalIntensityData>> getRegionalDataForPostcodeFrom(
    String postcode, {
    required DateTime from,
    FromModifier modifier = FromModifier.none,
    DateTime? to,
  }) {
    return _getRegionalDataFromHelper(
      "$_postcode$postcode",
      from: from,
      modifier: modifier,
      to: to,
    );
  }

  /// fetches regional data for region id from a particular date
  Future<List<RegionalIntensityData>> getRegionalDataForRegionIdFrom(
    int regionId, {
    required DateTime from,
    FromModifier modifier = FromModifier.none,
    DateTime? to,
  }) {
    return _getRegionalDataFromHelper(
      "$_regionid$regionId",
      from: from,
      modifier: modifier,
      to: to,
    );
  }

  /// fetches the forecast regional intensity data
  ///
  /// one of instance members postcode and regionId will be used to fetch data
  /// postcode is preferred over regionId if both are set
  @override
  Future<List<PeriodData<IntensityData>>> forecast() async {
    DateTime now = DateTime.now().toUtc();
    final regionalData = postcode != null
        ? await getRegionalDataForPostcodeFrom(
            postcode!,
            from: now,
            modifier: FromModifier.forward24,
          )
        : await getRegionalDataForRegionIdFrom(
            regionId!,
            from: now,
            modifier: FromModifier.forward24,
          );

    if (regionalData.isEmpty) {
      throw Exception("No regional data found for $postcode ($regionId)");
    }

    return regionalData.first.intensityData;
  }

  /// returns the least amount in the future
  ///
  /// one of instance members postcode and regionId will be used to fetch data
  /// postcode is preferred over regionId if both are set
  /// fetches the forecast data and then calls predictMinimumWith
  @override
  Future<PeriodData<IntensityData>> forecastMinimum() async {
    List<PeriodData<IntensityData>> forecastData = await forecast();
    return forecastMinimumWith(forecastData);
  }

  Future<List<RegionalIntensityData>> _getRegionalDataFromHelper(
    String postfix, {
    required DateTime from,
    FromModifier modifier = FromModifier.forward24,
    DateTime? to,
  }) async {
    String modifierString = CarbonIntensityCaller._getModifierString(
      modifier,
      to,
    );
    String fromString = from.toIso8601String();

    final response = await _get(
      "$_regional${CarbonIntensityCaller._intensity}/$fromString/$modifierString$postfix",
    );
    return _parseRegionalData(response);
  }

  Future<Response> _getResponseForPostcode(String postcode) async {
    postcode = postcode.trim();
    final response = await _get("$_regional$_postcode$postcode");
    return response;
  }

  Future<Response> _getResponseForRegionId(int regionId) async {
    final response = await _get("$_regional$_regionid$regionId");
    return response;
  }

  List<RegionalIntensityData> _parseRegionalData(Response response) {
    if (!isValidResponse(response)) {
      throw Exception(
        "No regional data found: Error code ${response.statusCode}",
      );
    }

    var json = jsonDecode(response.body)["data"];

    if (json is Map<String, dynamic>) {
      json = List.of([json]);
    } else {
      if (json.isEmpty) {
        throw Exception("No regional data found!");
      }
    }

    List<RegionalIntensityData> regions = [];

    json.forEach((elemJson) {
      List innerJsons = elemJson["data"];
      final regionalIntensityData = RegionalIntensityData.fromJson(elemJson);
      List<PeriodData<IntensityData>> intensityData = [];
      innerJsons.forEach((innerJson) {
        intensityData.add(_parseIntensityAndTimeFromJson(innerJson));
      });
      regionalIntensityData.intensityData = intensityData;
      regions.add(regionalIntensityData);
    });

    return regions;
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

class RegionalIntensityData {
  static const String _regionid = "regionid";
  static const String _shortname = "shortname";

  final String shortname;
  final String dnoregion;
  final int regionId;

  late final List<PeriodData<IntensityData>> intensityData;

  RegionalIntensityData(this.shortname, this.dnoregion, this.regionId);

  factory RegionalIntensityData.fromJson(Map<String, dynamic> json) {
    return RegionalIntensityData(
      json[_shortname],
      json["dnoregion"] ?? json[_shortname],
      json[_regionid],
    );
  }
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
