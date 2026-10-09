import 'condition/condition.dart';
import 'condition/condition_parser.dart';

/// How a group's fields appear in the form's output.
enum GroupOutput {
  /// Alongside the group's siblings, as if the group were not there.
  flat,

  /// In an object stored under the group's key.
  object,

  /// In a list stored under the group's key: one object per entry, with
  /// entries added and removed by the user.
  list,
}

class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.type,
    this.label,
    this.required = false,
    this.raw = const {},
    this.visibleWhen,
    this.children = const [],
    this.output = GroupOutput.flat,
    this.minItems = 0,
    this.maxItems,
    this.addLabel,
  });

  static const groupType = 'group';

  final String key;
  final String type;
  final String? label;
  final bool required;
  final Map<String, dynamic> raw; // full JSON, for type-specific options
  final JsonFormCondition? visibleWhen;

  /// The fields of a group. Empty for anything else.
  final List<FieldSpec> children;

  /// Groups only: where the group's fields land in the output.
  final GroupOutput output;

  /// List groups only: the fewest entries allowed, and the most, if any.
  final int minItems;
  final int? maxItems;

  /// List groups only: the text of the button that adds an entry.
  final String? addLabel;

  bool get isGroup => type == groupType;

  factory FieldSpec.fromJson(Map<String, dynamic> json) {
    String requireString(String name) {
      final value = json[name];
      if (value is! String) {
        throw FormatException('Field needs a string "$name": $json');
      }
      return value;
    }

    final key = requireString('key');
    final type = requireString('type');
    final isGroup = type == groupType;

    final label = json['label'];
    if (label != null && label is! String) {
      throw FormatException('"label" of "$key" must be a string: $label');
    }
    final required = json['required'];
    if (required != null && required is! bool) {
      throw FormatException('"required" of "$key" must be true or false: '
          '$required');
    }

    final output = isGroup ? _parseOutput(json, key) : GroupOutput.flat;
    final isList = output == GroupOutput.list;
    final minItems =
        isList ? (_count(json, key, 'minItems', atLeast: 0) ?? 0) : 0;
    final maxItems = isList ? _count(json, key, 'maxItems', atLeast: 1) : null;
    if (maxItems != null && minItems > maxItems) {
      throw FormatException(
        'Group "$key" has minItems $minItems greater than maxItems $maxItems',
      );
    }
    final addLabel = json['addLabel'];
    if (isList && addLabel != null && addLabel is! String) {
      throw FormatException(
        '"addLabel" of group "$key" must be a string: $addLabel',
      );
    }

    return FieldSpec(
      key: key,
      type: type,
      label: label as String?,
      required: required as bool? ?? false,
      raw: json,
      visibleWhen: json['visibleWhen'] == null
          ? null
          : parseCondition(json['visibleWhen'] as Map<String, dynamic>),
      children: isGroup ? _parseChildren(json) : const [],
      output: output,
      minItems: minItems,
      maxItems: maxItems,
      addLabel: isList ? addLabel as String? : null,
    );
  }

  static List<FieldSpec> _parseChildren(Map<String, dynamic> json) {
    final fields = json['fields'];
    if (fields == null) return const [];
    if (fields is! List) {
      throw FormatException('"fields" must be a list: $fields');
    }
    return [
      for (final f in fields)
        if (f is Map<String, dynamic>)
          FieldSpec.fromJson(f)
        else
          throw FormatException('Each field must be a JSON object: $f'),
    ];
  }

  static GroupOutput _parseOutput(Map<String, dynamic> json, String key) {
    final raw = json['output'];
    if (raw == null) return GroupOutput.flat;
    for (final value in GroupOutput.values) {
      if (value.name == raw) return value;
    }
    throw FormatException(
      '"output" of group "$key" must be "flat", "object" or "list": $raw',
    );
  }

  static int? _count(
    Map<String, dynamic> json,
    String key,
    String name, {
    required int atLeast,
  }) {
    final raw = json[name];
    if (raw == null) return null;
    final int? value;
    if (raw is int) {
      value = raw;
    } else if (raw is double && raw.isFinite && raw == raw.truncateToDouble()) {
      value = raw.toInt();
    } else {
      value = null;
    }
    if (value == null || value < atLeast) {
      throw FormatException(
        '"$name" of group "$key" must be a whole number of at least '
        '$atLeast: $raw',
      );
    }
    return value;
  }
}
