abstract class JsonFormCondition {
  const JsonFormCondition();

  /// Keys of the fields this condition reads.
  Set<String> get fields;

  bool isMet(Map<String, dynamic> values);
}
