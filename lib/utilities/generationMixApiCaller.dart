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
      throw Exception("Could not get current generation mix.\nError code: ${response.statusCode}\n${response.body}");
    }
    final json = jsonDecode(response.body);
    return _parseOne(json);
  }

  Future<List<PeriodData<GenerationMix>>> getGenerationMixFrom(DateTime from, {FromModifier modifier = FromModifier.past24, DateTime? to}) async {
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
      default: throw Exception("Invalid argument modifier: expected one of {FromModifier.past24, FromModifier.to}");
    }

    final response = await getRaw("$_generation${from.toIso8601String()}/$modifierStr");
    if (!isValidResponse(response)) {
      throw Exception("Could not get generation mix.\nError code: ${response.statusCode}\n${response.body}");
    }
    final json = jsonDecode(response.body);
    return _parseList(json);
  }

  List<PeriodData<GenerationMix>> _parseList(Map<String, dynamic> json) {
    List data = json["data"];
    return data.map((jsonElem) => parseTimePeriod(jsonElem, GenerationMix.fromJson)).toList();
  }

  PeriodData<GenerationMix> _parseOne(Map<String, dynamic> json) {
    Map<String, dynamic> data = json["data"];
    return parseTimePeriod(data, GenerationMix.fromJson);
  }

}

/// to store each generation factor within the generation mix
class GenerationFactor {
  /// The fuel type contributing to the generation
  final String fuel;

  /// The percentage of generation mix denoted by this fuel type
  final double perc;

  GenerationFactor(this.fuel, this.perc);

  factory GenerationFactor.fromJson(Map<String, dynamic> json) {
    double perc = 0;
    final percJson = json["perc"];
    if (percJson is int) {
      perc = percJson + 0.0;
    } else {
      perc = percJson;
    }
    return GenerationFactor(json["fuel"], perc);
  }

  @override
  bool operator ==(Object other) {
    return other is GenerationFactor &&
        this.fuel == other.fuel &&
        this.perc == other.perc;
  }

  @override
  int get hashCode => fuel.hashCode + (perc * 31).round();
}

/// to store the temporal generation mix
class GenerationMix implements Comparable<GenerationMix> {
  final List<GenerationFactor> factors;

  GenerationMix({
    required this.factors,
  });

  factory GenerationMix.fromJson(
    Map<String, dynamic> json) {
    List<dynamic> factors = json["generationmix"];
    List<GenerationFactor> genFactors = factors.map((factorJson) => GenerationFactor.fromJson(factorJson)).toList();
    GenerationMix genMix = GenerationMix(factors: genFactors);
    return genMix;
  }

  @override
  int compareTo(GenerationMix other) {
    return this.factors.length - other.factors.length;
  }
}
