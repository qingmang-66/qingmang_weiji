enum StudySource {
  normal,
  review,
  wrongWords,
  searchResults,
  studyPlan,
  favorites,
}

extension StudySourceKey on StudySource {
  String get key {
    return switch (this) {
      StudySource.normal => 'normal',
      StudySource.review => 'review',
      StudySource.wrongWords => 'wrongWords',
      StudySource.searchResults => 'searchResults',
      StudySource.studyPlan => 'studyPlan',
      StudySource.favorites => 'favorites',
    };
  }
}
