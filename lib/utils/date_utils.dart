/// 日期工具
library;

/// 两个本地时间相差的"日历天数"（按年月日计，与钟点无关）。
///
/// 不能用 `a.difference(b).inDays` 计算两个本地零点之间的天数：
/// 跨夏令时切换日时实际绝对时长是 N 天 ∓1 小时，`Duration.inDays`
/// 截断后会少算 1 天。按年月日构造 UTC 日期再相减，与时区规则无关。
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
