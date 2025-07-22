
import 'package:electricity_prices_and_carbon_intensity/utilities/carbonIntensityApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/generationMixApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:test/test.dart';
import 'package:logger/logger.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

void main() {
  GenerationMixApiCaller caller = GenerationMixApiCaller();
  group("testing national generation mix", () {
    test("testing current generation mix", () async {
      PeriodData<GenerationMix> period = await caller.getCurrentGenerationMix();
      DateTime now = DateTime.now().toUtc();

      expect(period.value.factors.isNotEmpty, true);
      expect(period.from.isBefore(now), true);
      expect(period.to.isBefore(now), true);
    });

    test("testing generation mix from and to date", () async {
      DateTime from = DateTime(2023, 3, 9, 16, 20);
      DateTime to = DateTime(2023, 3, 9, 19, 20);
      List<PeriodData<GenerationMix>> data = await caller.getGenerationMixFrom(from, modifier: FromModifier.to, to: to);

      expect(data.length, 6);
    });

    test("testing generation mix from and past 24h", () async {
      DateTime from = DateTime(2023, 3, 9, 16, 20);
      List<PeriodData<GenerationMix>> data = await caller.getGenerationMixFrom(from, modifier: FromModifier.past24);

      expect(data.length, 48);
    });
  });
}