import 'condition.dart';
import 'equals_condition.dart';

JsonFormCondition parseCondition(Map<String, dynamic> json) {
  if (json.containsKey('field') && json.containsKey('equals')) {
    if (json['field'] is! String) {
      throw FormatException('Field must be a string for equals condition!');
    }

    return JsonFormEqualsCondition(
      field: json['field'] as String,
      expected: json['equals'],
    );
  }
  throw FormatException('Unsupported condition: $json');
}
