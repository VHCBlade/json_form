import 'condition.dart';

class JsonFormEqualsCondition extends JsonFormCondition {
  const JsonFormEqualsCondition({required this.field, required this.expected});

  final String field;
  final Object? expected;

  @override
  Set<String> get fields => {field};

  @override
  bool isMet(Map<String, dynamic> values) => values[field] == expected;
}
