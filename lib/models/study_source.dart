enum StudySource {
  normal,
  review,
  wrongWords,
  favorites,
  customWordSet,
  searchResults,
  studyPlan,
}

extension StudySourceKey on StudySource {
  String get key {
    return switch (this) {
      StudySource.normal => 'normal',
      StudySource.review => 'review',
      StudySource.wrongWords => 'wrongWords',
      StudySource.favorites => 'favorites',
      StudySource.customWordSet => 'customWordSet',
      StudySource.searchResults => 'searchResults',
      StudySource.studyPlan => 'studyPlan',
    };
  }
}
