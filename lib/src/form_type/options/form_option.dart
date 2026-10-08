class JsonFormOption {
  const JsonFormOption({required this.value, required this.label});

  final Object value;
  final String label;

  factory JsonFormOption.fromJson(Object json) {
    if (json is Map<String, dynamic>) {
      if (json['value'] == null) {
        throw FormatException('Value must be specified for form option.');
      }
      final value = json['value'] as Object;
      return JsonFormOption(
        value: value,
        label: json['label'] as String? ?? value.toString(),
      );
    }
    return JsonFormOption(value: json, label: json.toString());
  }
}
