/// 可选值包装器，用于 copyWith 方法区分"不修改"和"设为 null"
///
/// 使用方式：
/// ```dart
/// Word copyWith({
///   Optional<String>? example,  // 不再是 String?
/// }) => Word(
///   example: example != null ? example.value : this.example,
/// );
/// ```
///
/// 调用时：
/// - `copyWith()` → 不修改 example
/// - `copyWith(example: Optional(null))` → 将 example 设为 null
/// - `copyWith(example: Optional('新值'))` → 将 example 设为 '新值'
class Optional<T> {
  final T value;
  const Optional(this.value);
}
