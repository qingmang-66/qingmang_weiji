import '../models/models.dart';

/// 按单词去重（忽略大小写），保留排序更靠前的那条，最多 [limit] 条。
///
/// 跨词库搜索必然会搜到同一个单词的多份副本：CET4 与考研词库同时收录
/// 「abandon」是很常见的，实测 3.4 万词条下某些关键字前 40 条里只有 13 个
/// 不同的单词。结果列表里重复出现同一条既干扰阅读，也白白占掉结果名额。
///
/// 去重只遍历一次、最多几十条，相对一次 SQL 查询可以忽略。
List<Word> dedupeWordsByWord(Iterable<Word> words, {required int limit}) {
  final seen = <String>{};
  final result = <Word>[];
  for (final word in words) {
    if (!seen.add(word.word.toLowerCase())) continue;
    result.add(word);
    if (result.length >= limit) break;
  }
  return result;
}
