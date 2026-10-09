import 'dart:convert';

import 'package:json_form/json_form.dart';

class JsonSchemaParser {
  /// Parses [text] representing a JSONObject Schema and checks that [JsonForm] can build it.
  /// Throws a [FormatException] with a readable message otherwise.
  static Map<String, dynamic> parseSchema(
      String text, List<JsonFormFieldInput> inputs) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('Not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The top level must be a JSON object');
    }
    try {
      JsonForm.validateSchema(decoded, inputs: inputs);
    } on TypeError catch (e) {
      throw FormatException('A value in the schema has the wrong type: $e');
    }
    return decoded;
  }
}
