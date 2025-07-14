import 'package:test/test.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';

void main() {
  final client = CarbonIntensityCaller();
  group('Testing httpclient\'s CarbonIntensityCaller', () {
    test('get current intensity', () async {
      var period = await client.getCurrentIntensity();
      expect(period.value.forecast?.isFinite, true);
    });

    test('get current intensity for date in the past', () async {
      final date = DateTime(2023, 3, 9);
      var periodData = await client.getIntensityForDate(date);
      expect(periodData.length, 48);
      var resultDate = DateTime.parse(periodData.first.from);
      expect(resultDate.day, date.day);
      expect(resultDate.month, date.month);
      expect(resultDate.year, date.year);
    });

    test('get intensity from single', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(from: datetime);
      var resultDate = DateTime.parse(periodsData.first.from);
      expect(periodsData.length, 1);
      expect(resultDate.day, datetime.day);
      expect(resultDate.month, datetime.month);
      expect(resultDate.year, datetime.year);
      expect(resultDate.hour, datetime.hour);
      expect(resultDate.minute, 0);
    });

    test('get intensity forward 24h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(from: datetime, modifier: FromModifier.forward24);
      expect(periodsData.length, 48);
      var startDate = DateTime.parse(periodsData.first.to);
      var endDate = DateTime.parse(periodsData.last.to);
      expect(startDate.isBefore(endDate), true, reason: "$startDate before $endDate");
      expect(datetime.isBefore(startDate), true, reason: "$datetime before $startDate");
      expect(endDate.subtract(Duration(hours: 23, minutes: 30)), startDate, reason: "$startDate is about one day before $endDate");
    });

    test('get intensity forward 48h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(from: datetime, modifier: FromModifier.forward48);
      expect(periodsData.length, 96);
      var startDate = DateTime.parse(periodsData.first.to);
      var endDate = DateTime.parse(periodsData.last.to);
      expect(startDate.isBefore(endDate), true, reason: "$startDate before $endDate");
      expect(datetime.isBefore(startDate), true, reason: "$datetime before $startDate");
      expect(endDate.subtract(Duration(hours: 47, minutes: 30)), startDate, reason: "$startDate is about one day before $endDate");
    });

    test('get intensity past 24h', () async {
      final datetime = DateTime(2023, 3, 9, 16, 20);
      var periodsData = await client.getIntensityFrom(from: datetime, modifier: FromModifier.past24);
      expect(periodsData.length, 48);
      var startDate = DateTime.parse(periodsData.first.from);
      var endDate = DateTime.parse(periodsData.last.from);
      expect(startDate.isBefore(endDate), true, reason: "$startDate before $endDate");
      expect(startDate.isBefore(datetime), true, reason: "$startDate before $datetime");
      expect(endDate.subtract(Duration(hours: 23, minutes: 30)), startDate, reason: "$startDate is about one day before $endDate");
    });

    test('get intensity from date to date', () async {
      final from = DateTime(2023, 3, 9, 16, 20);
      final to = DateTime(2023, 3, 9, 19, 20);
      var periodsData = await client.getIntensityFrom(from: from, modifier: FromModifier.to, to: to);
      expect(periodsData.length, 6);
    });
  });
}