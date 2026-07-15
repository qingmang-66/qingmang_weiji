import 'package:flutter/foundation.dart';

import '../../models/weak_word_entry.dart';
import '../../models/weakness_level.dart';
import '../../models/weakness_overview.dart';
import '../weak_vocabulary_service.dart';

class WeakVocabularyRepository {
  final WeakVocabularyService _service;

  WeakVocabularyRepository(this._service);

  Future<WeaknessOverview> loadOverview({bool forceRefresh = false}) async {
    try {
      return await _service.getOverview(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('WeakVocabularyRepository.loadOverview error: $e');
      return WeaknessOverview.empty();
    }
  }

  Future<List<WeakWordEntry>> loadWeakWords({
    WeaknessLevel minLevel = WeaknessLevel.shaky,
    int? limit,
    bool forceRefresh = false,
  }) async {
    try {
      return await _service.getWeakWords(
        minLevel: minLevel,
        limit: limit,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('WeakVocabularyRepository.loadWeakWords error: $e');
      return const [];
    }
  }

  Future<List<WeakWordEntry>> loadCriticalWords({int limit = 10}) async {
    try {
      return await _service.getCriticalWords(limit: limit);
    } catch (e) {
      debugPrint('WeakVocabularyRepository.loadCriticalWords error: $e');
      return const [];
    }
  }
}
