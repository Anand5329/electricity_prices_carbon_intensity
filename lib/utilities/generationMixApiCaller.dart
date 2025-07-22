import 'dart:convert';

import 'package:electricity_prices_and_carbon_intensity/utilities/carbonIntensityApiCaller.dart';
import 'package:logger/logger.dart';

import 'httpclient.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

class GenerationMixApiCaller extends ApiCaller {
  static const String BASE_URL = "https://api.carbonintensity.org.uk/";
  static const String _generation = "generation/";
  static const String _regional = "regional/";

  GenerationMixApiCaller() : super(BASE_URL);

  Future<PeriodData<GenerationMix>> getCurrentGenerationMix() async {
    final response = await getRaw(_generation);
    if (!isValidResponse(response)) {
      throw Exception(
        "Could not get current generation mix.\nError code: ${response.statusCode}\n${response.body}",
      );
    }
    final json = jsonDecode(response.body);
    return _parseOne(json);
  }

  Future<List<PeriodData<GenerationMix>>> getGenerationMixFrom(
    DateTime from, {
    FromModifier modifier = FromModifier.past24,
    DateTime? to,
  }) async {
    String modifierStr = "";
    switch (modifier) {
      case FromModifier.past24:
        modifierStr = "${FromModifier.past24}/";
        break;
      case FromModifier.to:
        if (to == null) {
          throw Exception("Illegal argument to: expected non-null date time");
        }
        modifierStr = "${to.toIso8601String()}/";
        break;
      default:
        throw Exception(
          "Invalid argument modifier: expected one of {FromModifier.past24, FromModifier.to}",
        );
    }

    final response = await getRaw(
      "$_generation${from.toIso8601String()}/$modifierStr",
    );
    if (!isValidResponse(response)) {
      throw Exception(
        "Could not get generation mix.\nError code: ${response.statusCode}\n${response.body}",
      );
    }
    final json = jsonDecode(response.body);
    return _parseList(json);
  }

  List<PeriodData<GenerationMix>> _parseList(Map<String, dynamic> json) {
    List data = json["data"];
    return data
        .map((jsonElem) => parseTimePeriod(jsonElem, GenerationMix.fromJson))
        .toList();
  }

  PeriodData<GenerationMix> _parseOne(Map<String, dynamic> json) {
    Map<String, dynamic> data = json["data"];
    return parseTimePeriod(data, GenerationMix.fromJson);
  }
}

enum EnergySource {
  biomass("biomass"),
  imports("imports"),
  gas("gas"),
  nuclear("nuclear"),
  other("other"),
  hydro("hydro"),
  solar("solar"),
  wind("wind"),
  coal("coal");

  final String _type;
  const EnergySource(this._type);

  bool equals(other) {
    return other is EnergySource && other._type == _type;
  }

  static EnergySource fromString(String source) {
    return EnergySource.values.reduce((src1, src2) {
      if (src1._type == source) {
        return src1;
      }
      if (src2._type == source) {
        return src2;
      }
      // should never happen
      return EnergySource.other;
    });
  }
}

/// to store each generation factor within the generation mix
class GenerationFactor {
  /// The fuel type contributing to the generation
  final EnergySource energySource;

  /// The percentage of generation mix denoted by this fuel type
  final double perc;

  GenerationFactor(this.energySource, this.perc);

  factory GenerationFactor.fromJson(Map<String, dynamic> json) {
    double perc = 0;
    final percJson = json["perc"];
    if (percJson is int) {
      perc = percJson + 0.0;
    } else {
      perc = percJson;
    }
    return GenerationFactor(EnergySource.fromString(json["fuel"]), perc);
  }

  @override
  bool operator ==(Object other) {
    return other is GenerationFactor &&
        this.energySource == other.energySource &&
        this.perc == other.perc;
  }

  @override
  int get hashCode => energySource.hashCode + (perc * 31).round();
}

/// to store the temporal generation mix
class GenerationMix implements Comparable<GenerationMix> {
  final List<GenerationFactor> factors;

  GenerationMix({required this.factors});

  factory GenerationMix.fromJson(Map<String, dynamic> json) {
    List<dynamic> factors = json["generationmix"];
    List<GenerationFactor> genFactors = factors
        .map((factorJson) => GenerationFactor.fromJson(factorJson))
        .toList();
    GenerationMix genMix = GenerationMix(factors: genFactors);
    return genMix;
  }

  @override
  int compareTo(GenerationMix other) {
    return this.factors.length - other.factors.length;
  }
}
