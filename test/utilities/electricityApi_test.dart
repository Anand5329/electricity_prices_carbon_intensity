import 'package:test/test.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/electricityApiCaller.dart';

void main() {
  final client = ElectricityApiCaller();

  group('Testing electricity api caller', () {
    test('get current products', () async {
      List<Product> products = await client.getProducts();
      DateTime now = DateTime.now();
      for (var product in products) {
        expect(product.availableFrom.isBefore(now), true);
      }
    });

    final String productCode = "AGILE-24-10-01";
    final String tariffBand = "E-1R-AGILE-24-10-01-C";

    test('get specific produce with code', () async {
      Product product = await client.getProductWithCode(productCode);
      expect(product.tariffCodes.isNotEmpty, true);
    });

    test('get tariff rate from', () async {
      DateTime from = DateTime(2025, 3, 9, 11, 30);
      DateTime to = DateTime(2025, 3, 9, 19, 30);
      List<Rate> rates = await client.getTariffsFrom(
        productCode,
        tariffBand,
        from,
        to: to,
      );
      expect(rates.length, 16);
    });
  });
}
