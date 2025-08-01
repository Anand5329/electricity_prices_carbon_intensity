import 'package:electricity_prices_and_carbon_intensity/utilities/httpclient.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/minimumForecaster.dart';
import 'package:electricity_prices_and_carbon_intensity/utilities/octopusApiCaller.dart';
import 'package:logger/logger.dart';

var logger = Logger(filter: null, printer: PrettyPrinter(), output: null);

final class GasApiCaller extends OctopusApiCaller with MinimumForecaster<Rate> {
  GasApiCaller(super.productCode, super.tariffCode);

  /// fetches fullProducts that have valid tariffs
  ///
  /// availableAt should be in the UTC timezone
  @override
  Future<List<Product>> getProducts({DateTime? availableAt}) {
    return getProductsOf(TariffType.gas, availableAt: availableAt);
  }

  /// fetches the current price for the given product and tariff code
  ///
  /// If either code is null, will use as replacement instance fields productCode and tariffCode
  @override
  Future<PeriodData<Rate>> getCurrentPrice({
    String? productCode,
    String? tariffCode,
  }) async {
    productCode = productCode ?? this.productCode;
    tariffCode = tariffCode ?? this.tariffCode;
    List<PeriodData<Rate>> prices = await getTariffsFrom(
      productCode: productCode,
      tariffCode: tariffCode,
      DateTime.now().toUtc(),
    );
    return prices.first;
  }

  /// fetches tariffs given product and tariff code inclusive from given date time from
  ///
  /// If either code is null, will use as replacement instance fields productCode and tariffCode
  /// Can optionally pass a to date time that will return tariffs until that time (exclusive)
  /// Can optionally pass a RateType to rateType for type of rates fetched
  /// All date times must be in the UTC timezone
  Future<List<PeriodData<Rate>>> getTariffsFrom(
    DateTime from, {
    String? productCode,
    String? tariffCode,
    DateTime? to,
    RateType rateType = RateType.standardUnitRate,
  }) async {
    return super.getGenericTariffsFrom(
      from,
      productCode: productCode,
      tariffType: TariffType.gas,
      tariffCode: tariffCode,
      to: to,
      rateType: rateType,
    );
  }

  /// forecasts tariffs in the future
  ///
  /// instance members productCode and tariffCode will be used to fetch data
  @override
  Future<List<PeriodData<Rate>>> forecast() async {
    DateTime now = DateTime.now().toUtc();
    return await getTariffsFrom(now);
  }

  /// returns the least amount in the future
  ///
  /// instance members productCode and tariffCode will be used to fetch data
  /// fetches the forecast data and then calls predictMinimumWith
  @override
  Future<PeriodData<Rate>> forecastMinimum() async {
    List<PeriodData<Rate>> forecastData = await forecast();
    return forecastMinimumWith(forecastData);
  }
}
