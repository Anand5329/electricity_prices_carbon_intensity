import 'httpclient.dart';

abstract mixin class MinimumForecaster<T extends Comparable<T>> {
  Future<List<PeriodData<T>>> forecast();

  /// returns the least amount in the future
  Future<PeriodData<T>> forecastMinimum() async {
    List<PeriodData<T>> forecastData = await forecast();
    return forecastMinimumWith(forecastData);
  }

  /// returns the least amount in the future with given forecast
  PeriodData<T> forecastMinimumWith(List<PeriodData<T>> forecast) {
    return forecast.reduce(
      (minSoFar, elem) => minSoFar.compareTo(elem) > 0 ? elem : minSoFar,
    );
  }
}
