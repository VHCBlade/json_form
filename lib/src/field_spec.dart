import 'package:json_form/json_form.dart';

typedef FormValues = Map<String, dynamic>;

class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.type,
    this.label,
    this.required = false,
    this.raw = const {},
    this.visibleWhen,
    this.children = const [],
  });

  static const groupType = 'group';

  final List<FieldSpec> children;

  bool get isGroup => type == groupType;

  final String key;
  final String type;
  final String? label;
  final bool required;
  final Map<String, dynamic> raw;
  final JsonFormCondition? visibleWhen;

  factory FieldSpec.fromJson(Map<String, dynamic> json) {
    if (json['key'] == null) {
      throw FormatException("Key must be specified for all inputs!");
    }
    if (json['key'] is! String) {
      throw FormatException("Key must be a string!");
    }
    if (json['type'] == null) {
      throw FormatException("Type must be specified for all inputs!");
    }
    if (json['type'] is! String) {
      throw FormatException("Type must be a string!");
    }

    return FieldSpec(
      key: json['key'] as String,
      type: json['type'] as String,
      label: json['label'] as String?,
      required: json['required'] as bool? ?? false,
      raw: json,
      visibleWhen: json['visibleWhen'] == null
          ? null
          : parseCondition(json['visibleWhen'] as Map<String, dynamic>),
      children: [
        for (final f in json['fields'] as List? ?? const [])
          FieldSpec.fromJson(f as Map<String, dynamic>),
      ],
    );
  }
}
