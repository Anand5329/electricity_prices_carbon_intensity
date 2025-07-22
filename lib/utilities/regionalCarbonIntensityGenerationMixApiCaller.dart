import 'dart:convert';

import 'package:electricity_prices_and_carbon_intensity/utilities/generationMixApiCaller.dart';
import 'package:http/http.dart';

import 'carbonIntensityApiCaller.dart';
import 'httpclient.dart';
import 'minimumForecaster.dart';

class RegionalCarbonIntensityGenerationMixCaller extends CarbonIntensityCaller
    with MinimumForecaster<IntensityData> {
  static const String _regional = "regional/";
  static const String _regionid = "${RegionalData._regionid}/";
  static const String _postcode = "postcode/";

  String? postcode;
  int? regionId;

  RegionalCarbonIntensityGenerationMixCaller({this.postcode, this.regionId})
    : super();

  /// fetches current intensity data for postcode
  Future<PeriodData<IntensityData>> getCurrentIntensityForPostcode(
    String postcode,
  ) async {
    final regionalIntensity = await getRegionalDataForPostcode(postcode);
    if (regionalIntensity.intensityData.isEmpty) {
      throw Exception("No intensity data found!");
    }
    return regionalIntensity.intensityData.first;
  }

  /// fetches current intensity data for region id
  Future<PeriodData<IntensityData>> getCurrentIntensityForRegionId(
    int regionId,
  ) async {
    final regionalIntensity = await getRegionalDataForRegionId(regionId);
    if (regionalIntensity.intensityData.isEmpty) {
      throw Exception("No intensity data found!");
    }
    return regionalIntensity.intensityData.first;
  }

  /// fetches current regional intensity data for postcode
  Future<RegionalData> getRegionalDataForPostcode(String postcode) async {
    Response response = await _getResponseForPostcode(postcode);
    List<RegionalData> regions = _parseRegionalData(
      response,
      parseGeneration: true,
    );
    if (regions.isEmpty) {
      throw Exception("No regional data found after parsing!");
    }
    return regions.first;
  }

  /// fetches current regional intensity data for region id
  Future<RegionalData> getRegionalDataForRegionId(int regionId) async {
    Response response = await _getResponseForRegionId(regionId);
    List<RegionalData> regions = _parseRegionalData(
      response,
      parseGeneration: true,
    );
    if (regions.isEmpty) {
      throw Exception("No regional data found after parsing!");
    }
    return regions.first;
  }

  /// fetches regional data for postcode from a particular date
  Future<List<RegionalData>> getRegionalDataForPostcodeFrom(
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
  Future<List<RegionalData>> getRegionalDataForRegionIdFrom(
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

  Future<List<RegionalData>> _getRegionalDataFromHelper(
    String postfix, {
    required DateTime from,
    FromModifier modifier = FromModifier.forward24,
    DateTime? to,
  }) async {
    String modifierString = CarbonIntensityCaller.getModifierString(
      modifier,
      to,
    );
    String fromString = from.toIso8601String();

    final response = await getRaw(
      "$_regional${CarbonIntensityCaller.intensity}/$fromString/$modifierString$postfix",
    );
    return _parseRegionalData(response);
  }

  Future<Response> _getResponseForPostcode(String postcode) async {
    postcode = postcode.trim();
    final response = await getRaw("$_regional$_postcode$postcode");
    return response;
  }

  Future<Response> _getResponseForRegionId(int regionId) async {
    final response = await getRaw("$_regional$_regionid$regionId");
    return response;
  }

  List<RegionalData> _parseRegionalData(
    Response response, {
    bool parseGeneration = false,
  }) {
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

    List<RegionalData> regions = [];

    json.forEach((elemJson) {
      List innerJsons = elemJson["data"];
      final regionalIntensityData = RegionalData.fromJson(elemJson);
      List<PeriodData<IntensityData>> intensityData = [];
      List<PeriodData<GenerationMix>> generationData = [];
      innerJsons.forEach((innerJson) {
        intensityData.add(parseTimePeriod(innerJson, IntensityData.fromJson));
        if (parseGeneration) {
          generationData.add(
            parseTimePeriod(innerJson, GenerationMix.fromJson),
          );
        }
      });
      regionalIntensityData.intensityData = intensityData;
      regionalIntensityData.generationData = generationData;
      regions.add(regionalIntensityData);
    });

    return regions;
  }
}

class RegionalData {
  static const String _regionid = "regionid";
  static const String _shortname = "shortname";

  final String shortname;
  final String dnoregion;
  final int regionId;

  late final List<PeriodData<IntensityData>> intensityData;
  late final List<PeriodData<GenerationMix>> generationData;

  RegionalData(this.shortname, this.dnoregion, this.regionId);

  factory RegionalData.fromJson(Map<String, dynamic> json) {
    return RegionalData(
      json[_shortname],
      json["dnoregion"] ?? json[_shortname],
      json[_regionid],
    );
  }
}
