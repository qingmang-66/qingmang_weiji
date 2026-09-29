import 'dart:convert';

/// JSON 解析安全护栏。
///
/// dart:convert 的解析器是递归下降实现：恶意/损坏的深嵌套 JSON
/// （如 `[[[[...]]]]`，10MB 文件即可构造百万级嵌套）会抛 **不可捕获的
/// StackOverflowError**，直接终止所在 isolate——备份恢复跑在 compute
/// isolate 里时表现为流程静默挂起，导入词库时表现为整个导入进程消失。
///
/// 这里在解析前先做一次线性扫描统计括号嵌套深度（O(n)，字符串内的括号
/// 会被正确跳过），超过上限抛出可读的 FormatException。
class JsonGuard {
  JsonGuard._();

  /// 嵌套深度上限：正常数据（备份/词库/词典）远达不到。
  static const int maxDepth = 64;

  /// 带深度护栏的 [jsonDecode]
  static dynamic decode(String raw, {int maxDepth = JsonGuard.maxDepth}) {
    ensureDepth(raw, maxDepth: maxDepth);
    return jsonDecode(raw);
  }

  /// 扫描 [raw] 的括号嵌套深度，超过 [maxDepth] 抛 [FormatException]
  static void ensureDepth(String raw, {int maxDepth = JsonGuard.maxDepth}) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == 0x5C) {
          // 反斜杠
          escaped = true;
        } else if (c == 0x22) {
          // 双引号
          inString = false;
        }
        continue;
      }
      if (c == 0x22) {
        inString = true;
        continue;
      }
      if (c == 0x5B || c == 0x7B) {
        // [ {
        depth++;
        if (depth > maxDepth) {
          throw const FormatException('JSON 嵌套层级过深，文件可能已损坏或被构造');
        }
      } else if (c == 0x5D || c == 0x7D) {
        // ] }
        depth--;
      }
    }
  }
}
