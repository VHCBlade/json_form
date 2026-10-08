import 'package:json_form/src/field_spec.dart';
import 'package:json_form/src/form_type/options/form_option.dart';

abstract class JsonFormOptionsSource {
  const JsonFormOptionsSource();

  Future<List<JsonFormOption>> load(FieldSpec spec);
}
