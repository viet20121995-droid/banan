/// Non-web stub — browser storage only exists in the web build. Callers
/// treat persistence as best-effort, so no-ops are the correct behavior.
library;

void writeSurveySessionValue(String key, String value) {}

String? readSurveySessionValue(String key) => null;

void removeSurveySessionValue(String key) {}

void writeSurveyLocalValue(String key, String value) {}

String? readSurveyLocalValue(String key) => null;
