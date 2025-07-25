import 'package:electricity_prices_and_carbon_intensity/utilities/carbonIntensityApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/regionalCarbonIntensityGenerationMixApiCaller.dart';
import 'package:logger/logger.dart';
import 'package:test/test.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

void main() {
  final client = CarbonIntensityCaller();
  group('Testing CarbonIntensityCaller', () {
    test('get current intensity', () async {
      PeriodData<IntensityData> period = await client.getCurrentIntensity();
      DateTime now = DateTime.now().toUtc();

      expect(period.value.forecast?.isFinite, true);
      expect(period.from.isBefore(now), true);
      expect(period.to.isBefore(now), true);
    });

    test('get current intensity for date in the past', () async {
      final date = DateTime(2023, 3, 9);
      var periodData = await client.getIntensityForDate(date);
      expect(periodData.length, 48);
      var resultDate = periodData.first.from;
      expect(resultDate.day, date.day);
      expect(resultDate.month, date.month);
      expect(resultDate.year, date.year);
    });

    test('get intensity from single', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(from: datetime);
      var resultDate = periodsData.first.from;
      expect(periodsData.length, 1);
      expect(resultDate.day, datetime.day);
      expect(resultDate.month, datetime.month);
      expect(resultDate.year, datetime.year);
      expect(resultDate.hour, datetime.hour);
      expect(resultDate.minute, 0);
    });

    test('get intensity forward 24h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(
        from: datetime,
        modifier: FromModifier.forward24,
      );
      expect(periodsData.length, 48);
      var startDate = periodsData.first.to;
      var endDate = periodsData.last.to;
      expect(
        startDate.isBefore(endDate),
        true,
        reason: "$startDate before $endDate",
      );
      expect(
        datetime.isBefore(startDate),
        true,
        reason: "$datetime before $startDate",
      );
      expect(
        endDate.subtract(Duration(hours: 23, minutes: 30)),
        startDate,
        reason: "$startDate is about one day before $endDate",
      );
    });

    test('get intensity forward 48h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(
        from: datetime,
        modifier: FromModifier.forward48,
      );
      expect(periodsData.length, 96);
      var startDate = periodsData.first.to;
      var endDate = periodsData.last.to;
      expect(
        startDate.isBefore(endDate),
        true,
        reason: "$startDate before $endDate",
      );
      expect(
        datetime.isBefore(startDate),
        true,
        reason: "$datetime before $startDate",
      );
      expect(
        endDate.subtract(Duration(hours: 47, minutes: 30)),
        startDate,
        reason: "$startDate is about one day before $endDate",
      );
    });

    test('get intensity past 24h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(
        from: datetime,
        modifier: FromModifier.past24,
      );
      expect(periodsData.length, 48);
      var startDate = periodsData.first.from;
      var endDate = periodsData.last.from;
      expect(
        startDate.isBefore(endDate),
        true,
        reason: "$startDate before $endDate",
      );
      expect(
        startDate.isBefore(datetime),
        true,
        reason: "$startDate before $datetime",
      );
      expect(
        endDate.subtract(Duration(hours: 23, minutes: 30)),
        startDate,
        reason: "$startDate is about one day before $endDate",
      );
    });

    test('get intensity from date to date', () async {
      final from = DateTime(2023, 3, 9, 16, 20);
      final to = DateTime(2023, 3, 9, 19, 20);
      var periodsData = await client.getIntensityFrom(
        from: from,
        modifier: FromModifier.to,
        to: to,
      );
      expect(periodsData.length, 6);
    });

    test('forecast minimum', () async {
      List<PeriodData<IntensityData>> forecast = await client.forecast();
      PeriodData<IntensityData> min = await client.forecastMinimum();

      for (PeriodData<IntensityData> moment in forecast) {
        expect(moment >= min, true);
      }
    });
  });

  RegionalCarbonIntensityGenerationMixCaller regionalClient =
      RegionalCarbonIntensityGenerationMixCaller();

  group('Testing RegionalCarbonIntensityCaller', () {
    test('get current intensity for london using postcode', () async {
      PeriodData<IntensityData> period = await regionalClient
          .getCurrentIntensityForPostcode("N5");
      DateTime now = DateTime.now().toUtc();

      expect(period.value.forecast?.isFinite, true);
      expect(period.from.isBefore(now), true);
      expect(period.to.isBefore(now), true);

      RegionalData regionalIntensityData = await regionalClient
          .getRegionalDataForPostcode("N5");

      expect(regionalIntensityData.dnoregion, "UKPN London");
      expect(regionalIntensityData.shortname, "London");
      expect(regionalIntensityData.regionId, 13);
    });

    test('get current intensity for london using regionId', () async {
      PeriodData<IntensityData> period = await regionalClient
          .getCurrentIntensityForRegionId(13);
      DateTime now = DateTime.now().toUtc();

      expect(period.value.forecast?.isFinite, true);
      expect(period.from.isBefore(now), true);
      expect(period.to.isBefore(now), true);

      RegionalData regionalIntensityData = await regionalClient
          .getRegionalDataForRegionId(13);

      expect(regionalIntensityData.dnoregion, "UKPN London");
      expect(regionalIntensityData.shortname, "London");
      expect(regionalIntensityData.regionId, 13);
    });

    test('get regional intensity forward 24h for london', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      final regionId = 13;
      final postcode = "N5";

      final regionalData = await regionalClient.getRegionalDataForPostcodeFrom(
        postcode,
        from: datetime,
        modifier: FromModifier.forward24,
      );
      expect(regionalData.length, 1);
      expect(regionalData[0].dnoregion, "UKPN London");
      expect(regionalData[0].shortname, "London");
      expect(regionalData[0].regionId, 13);
      final regionalData2 = await regionalClient.getRegionalDataForRegionIdFrom(
        regionId,
        from: datetime,
        modifier: FromModifier.forward24,
      );
      expect(regionalData2.length, 1);
      expect(regionalData2[0].dnoregion, "UKPN London");
      expect(regionalData2[0].shortname, "London");
      expect(regionalData2[0].regionId, 13);

      final periodsData = regionalData[0].intensityData;
      expect(periodsData.length, 48);
      var startDate = periodsData.first.to;
      var endDate = periodsData.last.to;
      expect(
        startDate.isBefore(endDate),
        true,
        reason: "$startDate before $endDate",
      );
      expect(
        datetime.isBefore(startDate),
        true,
        reason: "$datetime before $startDate",
      );
      expect(
        endDate.subtract(Duration(hours: 23, minutes: 30)),
        startDate,
        reason: "$startDate is about one day before $endDate",
      );
    });

    test('get regional intensity forward 48h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      final regionId = 13;
      final postcode = "N5";

      final regionalData = await regionalClient.getRegionalDataForPostcodeFrom(
        postcode,
        from: datetime,
        modifier: FromModifier.forward48,
      );
      expect(regionalData.length, 1);
      expect(regionalData[0].dnoregion, "UKPN London");
      expect(regionalData[0].shortname, "London");
      expect(regionalData[0].regionId, 13);
      final regionalData2 = await regionalClient.getRegionalDataForRegionIdFrom(
        regionId,
        from: datetime,
        modifier: FromModifier.forward48,
      );
      expect(regionalData2.length, 1);
      expect(regionalData2[0].dnoregion, "UKPN London");
      expect(regionalData2[0].shortname, "London");
      expect(regionalData2[0].regionId, 13);

      final periodsData = regionalData[0].intensityData;
      expect(periodsData.length, 96);
      var startDate = periodsData.first.to;
      var endDate = periodsData.last.to;
      expect(
        startDate.isBefore(endDate),
        true,
        reason: "$startDate before $endDate",
      );
      expect(
        datetime.isBefore(startDate),
        true,
        reason: "$datetime before $startDate",
      );
      expect(
        endDate.subtract(Duration(hours: 47, minutes: 30)),
        startDate,
        reason: "$startDate is about one day before $endDate",
      );
    });

    test('get regional intensity past 24h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      final regionId = 13;
      final postcode = "N5";

      final regionalData = await regionalClient.getRegionalDataForPostcodeFrom(
        postcode,
        from: datetime,
        modifier: FromModifier.past24,
      );
      expect(regionalData.length, 1);
      expect(regionalData[0].dnoregion, "UKPN London");
      expect(regionalData[0].shortname, "London");
      expect(regionalData[0].regionId, 13);
      final regionalData2 = await regionalClient.getRegionalDataForRegionIdFrom(
        regionId,
        from: datetime,
        modifier: FromModifier.past24,
      );
      expect(regionalData2.length, 1);
      expect(regionalData2[0].dnoregion, "UKPN London");
      expect(regionalData2[0].shortname, "London");
      expect(regionalData2[0].regionId, 13);

      final periodsData = regionalData[0].intensityData;
      expect(periodsData.length, 48);
      var startDate = periodsData.first.from;
      var endDate = periodsData.last.from;
      expect(
        startDate.isBefore(endDate),
        true,
        reason: "$startDate before $endDate",
      );
      expect(
        startDate.isBefore(datetime),
        true,
        reason: "$startDate before $datetime",
      );
      expect(
        endDate.subtract(Duration(hours: 23, minutes: 30)),
        startDate,
        reason: "$startDate is about one day before $endDate",
      );
    });

    test('get regional intensity from date to date', () async {
      final from = DateTime(2023, 3, 9, 16, 20);
      final to = DateTime(2023, 3, 9, 19, 20);
      final regionId = 13;
      final postcode = "N5";

      final regionalData = await regionalClient.getRegionalDataForPostcodeFrom(
        postcode,
        from: from,
        modifier: FromModifier.to,
        to: to,
      );
      expect(regionalData.length, 1);
      expect(regionalData[0].dnoregion, "London");
      expect(regionalData[0].shortname, "London");
      expect(regionalData[0].regionId, 13);
      final regionalData2 = await regionalClient.getRegionalDataForRegionIdFrom(
        regionId,
        from: from,
        modifier: FromModifier.to,
        to: to,
      );
      expect(regionalData2.length, 1);
      expect(regionalData2[0].dnoregion, "UKPN London");
      expect(regionalData2[0].shortname, "London");
      expect(regionalData2[0].regionId, 13);

      final periodsData = regionalData[0].intensityData;
      expect(periodsData.length, 6);
    });

    test('forecast regional minimum', () async {
      regionalClient.postcode = "N5";
      List<PeriodData<IntensityData>> forecast = await regionalClient
          .forecast();
      PeriodData<IntensityData> min = await regionalClient.forecastMinimum();

      for (PeriodData<IntensityData> moment in forecast) {
        expect(moment >= min, true);
      }
    });
  });
}
