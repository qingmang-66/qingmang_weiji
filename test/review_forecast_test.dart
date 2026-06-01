import 'package:qingmang_weiji/models/review_forecast.dart';
import 'package:test/test.dart';

void main() {
  group('复习压力预测模型', () {
    test('计算未来预测总复习数', () {
      final forecast = ReviewForecast(
        days: [
          ReviewForecastDay(date: DateTime(2026, 5, 30), count: 3),
          ReviewForecastDay(date: DateTime(2026, 5, 31), count: 7),
          ReviewForecastDay(date: DateTime(2026, 6, 1), count: 5),
        ],
      );

      expect(forecast.total, 15);
    });

    test('计算未来预测峰值', () {
      final forecast = ReviewForecast(
        days: [
          ReviewForecastDay(date: DateTime(2026, 5, 30), count: 3),
          ReviewForecastDay(date: DateTime(2026, 5, 31), count: 9),
          ReviewForecastDay(date: DateTime(2026, 6, 1), count: 5),
        ],
      );

      expect(forecast.peak, 9);
    });

    test('计算未来预测日均复习数', () {
      final forecast = ReviewForecast(
        days: [
          ReviewForecastDay(date: DateTime(2026, 5, 30), count: 3),
          ReviewForecastDay(date: DateTime(2026, 5, 31), count: 8),
          ReviewForecastDay(date: DateTime(2026, 6, 1), count: 4),
        ],
      );

      expect(forecast.average, 5);
    });

    test('无数据时总量、峰值、均值都为0', () {
      const forecast = ReviewForecast(days: []);

      expect(forecast.total, 0);
      expect(forecast.peak, 0);
      expect(forecast.average, 0);
    });
  });
}
