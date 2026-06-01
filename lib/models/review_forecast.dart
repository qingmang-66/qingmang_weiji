class ReviewForecastDay {
  final DateTime date;
  final int count;

  const ReviewForecastDay({required this.date, required this.count});
}

class ReviewForecast {
  final List<ReviewForecastDay> days;

  const ReviewForecast({required this.days});

  int get total => days.fold(0, (sum, day) => sum + day.count);

  int get peak {
    if (days.isEmpty) return 0;
    return days.map((day) => day.count).reduce((a, b) => a > b ? a : b);
  }

  int get average {
    if (days.isEmpty) return 0;
    return (total / days.length).round();
  }
}
