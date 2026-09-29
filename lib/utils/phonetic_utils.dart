/// 音标文本工具
///
/// 内置词库来自 ECDICT，同一个单词常带多个读音变体，
/// 以 `;` 分隔（例如 `absorb` 的 `æbˈsɔrb; æbˈzɔrb; əbˈsɔrb`），
/// 部分条目还带用途注释（如 `(for n.)`、`(occas.)`）。
/// 界面上只需展示主读音，多次拼接会显得"音标重复了好几遍"，
/// 因此统一在此处取第一个有效读音并剥离注释。
class PhoneticUtils {
  PhoneticUtils._();

  /// 括号注释：半角 `(for v.)` 与全角 `（…）`
  static final RegExp _annotation = RegExp(r'\([^)]*\)|（[^）]*）');
  static final RegExp _extraSpaces = RegExp(r'\s+');

  /// 取主读音：按 `;` 切分后返回第一个有效片段，并去掉括号注释
  static String primary(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return '';
    //快速路径：不含分隔符与括号注释的音标（绝大多数单读音）直接返回，
    //避免批量导入/整册加载时每行都跑 split+两次正则替换
    if (!text.contains(';') && !text.contains('(') && !text.contains('（')) {
      return text;
    }
    for (final segment in text.split(';')) {
      final cleaned = segment
          .replaceAll(_annotation, ' ')
          .replaceAll(_extraSpaces, ' ')
          .trim();
      if (cleaned.isNotEmpty) return cleaned;
    }
    //所有片段都只剩注释（如 '(for n.)'）：按契约"第一个有效读音"返回空，
    //不能把原始注释串当音标显示
    return '';
  }
}
