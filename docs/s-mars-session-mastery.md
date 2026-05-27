# S-MARS 会话掌握算法说明

S-MARS 是清茫微记用于优化五种学习模式联动的会话级掌握度算法，全称为 Session Mastery + Adaptive Review Scheduling。它的目标不是简单减少题目数量，而是让回忆、拼写、听力、测验这几种练习方式共同服务于同一套掌握度判断，并把结果映射回现有的艾宾浩斯 + SM-2 复习调度。

## 设计目标

- 已经证明掌握的单词不再在同一轮学习中被低价值重复。
- 拼写、听力、测验、回忆按照证明力赋予不同权重。
- 查看答案、答错、多次重试会显著降低本轮掌握判断和长期复习质量。
- 会话内掌握分最终转换为 `ReviewScheduler.scheduleNextReview` 所需的 `quality`，继续使用现有艾宾浩斯基础间隔和 SM-2 难度因子。

## 模式权重

| 模式 | 权重 | 解释 |
|---|---:|---|
| 拼写 | 1.00 | 看到释义主动写出英文，主动输出证明力最高 |
| 听力 | 0.92 | 听音写词，检验音形绑定，证明力接近拼写 |
| 测验 | 0.72 | 选择识别存在猜测成分，证明力中等 |
| 回忆 | 0.55 | 自评主观性强，证明力最低 |

## 行为基础分

| 行为 | 基础分 |
|---|---:|
| 首次直接答对 | 100 |
| 重试后答对 | 78 |
| 回忆选择熟悉/简单 | 88 |
| 回忆选择记得/良好 | 72 |
| 回忆选择模糊 | 38 |
| 回忆选择忘记 | 15 |
| 答错 | 28 |
| 查看答案 | 12 |

## 保持率权重

S-MARS 使用 `ReviewScheduler.estimateRetention(record)` 获取当前单词的估算保持率，再转换为会话评分权重。

| 保持率 | 权重 | 说明 |
|---|---:|---|
| >= 85% | 0.92 | 刚复习不久，答对证明力略低 |
| 70% ~ 85% | 1.00 | 正常巩固区 |
| 45% ~ 70% | 1.10 | 遗忘临界区，答对证明力最高 |
| < 45% | 1.05 | 已明显遗忘，答对有价值但需防止偶然性 |

## 单次尝试得分公式

```text
attemptScore =
  actionBase
  × modeWeight
  × retentionWeight
  + streakBonus
  - wrongPenalty
  - revealPenalty
  - retryPenalty
  - repetitionPenalty
```

其中：

```text
streakBonus      = 连续答对 2 次 +6，连续答对 3 次及以上 +10
wrongPenalty     = wrongCount × 12
revealPenalty    = revealCount × 18
retryPenalty     = retryCount × 8
repetitionPenalty = 同一会话第 3 次出现起，每多一次 -5
```

## 会话掌握分更新公式

首次出现时：

```text
sessionScore = attemptScore
```

已有分数时：

```text
sessionScore = oldSessionScore × 0.65 + attemptScore × 0.35
```

最终分数限制在 `0~100`。

## 状态判断

| 条件 | 状态 |
|---|---|
| sessionScore >= 76 且 wrongCount == 0 且 revealCount == 0 | 本轮掌握 |
| sessionScore >= 82 且 bestModeWeight >= 0.92 | 强掌握 |
| sessionScore < 55 或 wrongCount >= 2 或 revealCount > 0 | 薄弱 |

## 长期复习质量映射

S-MARS 不替代艾宾浩斯曲线，而是在保存复习记录前计算更合理的 `reviewQuality`。

```text
reviewReadiness =
  sessionScore
  + bestModeWeight × 10
  - revealCount × 15
  - wrongCount × 10
```

| reviewReadiness | quality |
|---:|---:|
| >= 92 | 5 |
| 78 ~ 91 | 4 |
| 60 ~ 77 | 3 |
| 40 ~ 59 | 2 |
| < 40 | 1 |

强制降级规则：

| 条件 | 限制 |
|---|---|
| revealCount > 0 | quality <= 2 |
| wrongCount >= 2 | quality <= 2 |
| wrongCount == 1 | quality <= 3 |
| 只经过回忆验证 | quality <= 4 |
| 只经过测验验证 | quality <= 4 |

## 当前落地范围

第一版已经实现：

- `SessionMasteryEngine` 会话评分引擎。
- 拼写、听力、测验、回忆四类模式权重。
- 查看答案、答错、重试、连续答对、重复出现的惩罚和加成。
- 基于 `ReviewScheduler.estimateRetention` 的保持率权重。
- 会话分到长期 `quality` 的映射。
- 在学习页面中接入回忆评分、拼写/听力答题、测验答题和查看答案行为。

第一版暂未实现：

- 低频抽查池。
- 跨天持久化会话分。
- 答题耗时惩罚。
- 根据掌握状态自动切换到另一种学习模式。

## 后续优化方向

- 为每个单词记录更细的模式历史，例如是否同时通过拼写和听力。
- 引入微批次学习，把 8~12 个词作为一个学习闭环。
- 增加低频抽查池，避免已掌握词完全消失造成过度自信。
- 增加耗时惩罚，让“很慢才答对”和“秒答”区分开。
- 在学习总结页展示 S-MARS 分数分布和薄弱原因。
