/// 词库/文本导入的编码处理工具。
///
/// 中文词库最常见的两种坑：
/// 1. Windows 记事本另存的 UTF-8 **带 BOM**：`jsonDecode` 不会跳过 `U+FEFF`，
///    直接抛 "Unexpected character"；TXT 路径则会把 BOM 当成单词的第一个字符
///    入库（一个永远查不到、也复习不对的乱码词）。
/// 2. GBK/GB18030 编码：`utf8.decode` 抛 `FormatException`，报错信息与"编码"
///    毫无关系，用户完全没有修复方向。这里把错误换成可操作的提示。
library;

import 'dart:convert';

/// 去掉文本开头的 UTF-8 BOM（`U+FEFF`）
String stripBom(String text) {
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    return text.substring(1);
  }
  return text;
}

/// 按 UTF-8 解码导入文件字节，剥掉 BOM；不是 UTF-8 时给出可操作的错误。
String decodeImportTextBytes(List<int> bytes) {
  var data = bytes;
  // EF BB BF
  if (data.length >= 3 &&
      data[0] == 0xEF &&
      data[1] == 0xBB &&
      data[2] == 0xBF) {
    data = data.sublist(3);
  }
  try {
    return stripBom(utf8.decode(data));
  } on FormatException {
    throw const FormatException(
      '文件编码不是 UTF-8（常见于 GBK/GB18030 词库），请用记事本/编辑器另存为 UTF-8 后重试',
    );
  }
}
