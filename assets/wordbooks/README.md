# 词库更新说明

## 更新时间
2026年5月16日

## 数据来源
`D:\edge\English\merged` - ECDICT 整理词库（txt格式）

## 词库列表

| 词书ID | 名称 | 词汇量 | 文件 |
|--------|------|--------|------|
| chuzhong | 初中英语词汇 | 1,990 | chuzhong.json |
| gaozhong | 高中英语词汇 | 3,750 | gaozhong.json |
| cet4 | 大学英语四级 | 4,544 | cet4.json |
| cet6 | 大学英语六级 | 3,991 | cet6.json |
| kaoyan | 考研英语词汇 | 5,052 | kaoyan.json |
| toefl | 托福词汇 | 10,287 | toefl.json |
| sat | SAT词汇 | 4,451 | sat.json |

**总计: 35,065 词**

## 单词数据结构

```json
{
  "word": "单词",
  "phonetic": "音标",
  "definition": "释义",
  "phrases": "短语（用 | 分隔）",
  "example": "例句",
  "exampleTranslation": "例句翻译"
}
```

## 原词库处理
原词库文件已移动到回收站，如需恢复可从回收站还原。

## 注意事项
1. 新词库使用 ECDICT 数据源，包含完整的音标、释义、短语和例句
2. 词书版本已更新为 2.0.0
3. 内置词书配置已更新到 `lib/services/builtin_wordbooks.dart`
