import 'package:json_form/src/field_spec.dart';
import 'package:json_form/src/form_type/options/form_option.dart';
import 'package:json_form/src/form_type/options/sources/source.dart';

class JsonFormInlineOptionsSource extends JsonFormOptionsSource {
  const JsonFormInlineOptionsSource();

  @override
  Future<List<JsonFormOption>> load(FieldSpec spec) async {
    final options = spec.raw['options'] as List;
    return options.map((o) => JsonFormOption.fromJson(o as Object)).toList();
  }
}
