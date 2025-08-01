import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/octopusApiCaller.dart';
import 'package:electricity_prices_and_carbon_intensity/widgets/electricity.dart';
import 'package:test/test.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/electricityApiCaller.dart';

void main() {
  final client = ElectricityApiCaller(
    ElectricityPricesPage.defaultProductCode,
    ElectricityPricesPage.defaultTariffCode,
  );

  group('Testing electricity api caller', () {
    test('get current products', () async {
      List<Product> products = await client.getProducts();
      DateTime now = DateTime.now();
      for (var product in products) {
        expect(product.availableFrom.isBefore(now), true);
      }
    });

    final String productCode = "AGILE-24-10-01";
    final String tariffCode = "E-1R-AGILE-24-10-01-C";

    test('get specific product with code', () async {
      Product product = await client.getProductWithCode(code: productCode);
      expect(product.tariffCodes.isNotEmpty, true);

      Product product2 = await client.getProductWithCode();
      expect(product.code, product2.code);
      expect(product.tariffCodes, product2.tariffCodes);
    });

    test('get tariff rate from', () async {
      DateTime from = DateTime(2025, 3, 9, 11, 30);
      DateTime to = DateTime(2025, 3, 9, 19, 30);
      List<PeriodData<Rate>> rates = await client.getTariffsFrom(
        productCode: productCode,
        tariffCode: tariffCode,
        from,
        to: to,
      );
      expect(rates.length, 16);

      List<PeriodData<Rate>> rates2 = await client.getTariffsFrom(from, to: to);
      expect(rates, rates2);
    });

    test('get current tariff', () async {
      PeriodData<Rate> rate = await client.getCurrentPrice(
        productCode: productCode,
        tariffCode: tariffCode,
      );
      DateTime now = DateTime.now().toUtc();
      expect(rate.from.isBefore(now), true);
      expect(rate.to.isAfter(now), true);
    });

    test('forecast minimum', () async {
      List<PeriodData<Rate>> forecast = await client.forecast();
      PeriodData<Rate> min = await client.forecastMinimum();

      for (PeriodData<Rate> moment in forecast) {
        expect(moment >= min, true);
      }
    });
  });
}
