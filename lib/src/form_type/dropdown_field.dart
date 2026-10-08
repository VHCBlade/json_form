import 'package:flutter/material.dart';

import '../field_spec.dart';
import 'form_field.dart';
import 'options/form_option.dart';
import 'options/sources/inline.dart';
import 'options/sources/source.dart';

class JsonFormDropdownFieldInput extends JsonFormFieldInput {
  const JsonFormDropdownFieldInput({this.sources = const {}});

  /// Named sources, referenced from the schema via `optionsSource`.
  final Map<String, JsonFormOptionsSource> sources;

  static const _inline = JsonFormInlineOptionsSource();

  @override
  String get type => 'dropdown';

  JsonFormOptionsSource _sourceFor(FieldSpec spec) {
    final name = spec.raw['optionsSource'];
    if (name != null) {
      return sources[name] ??
          (throw FormatException('Unknown options source: $name'));
    }
    if (spec.raw['options'] is! List) {
      throw FormatException(
        'Dropdown "${spec.key}" needs "options" or "optionsSource"',
      );
    }
    return _inline;
  }

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    return _DropdownField(
      spec: spec,
      source: _sourceFor(spec),
      initialValue: initialValue,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}

class _DropdownField extends StatefulWidget {
  const _DropdownField({
    required this.spec,
    required this.source,
    required this.initialValue,
    required this.onChanged,
    required this.onSaved,
  });

  final FieldSpec spec;
  final JsonFormOptionsSource source;
  final Object? initialValue;
  final void Function(dynamic value) onSaved;
  final void Function(dynamic value) onChanged;

  @override
  State<_DropdownField> createState() => _DropdownFieldState();
}

class _DropdownFieldState extends State<_DropdownField> {
  late final Future<List<JsonFormOption>> _options =
      widget.source.load(widget.spec);

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    return FutureBuilder<List<JsonFormOption>>(
      future: _options,
      builder: (context, snapshot) {
        final options = snapshot.data ?? const <JsonFormOption>[];
        final loaded = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        final initial =
            loaded && options.any((o) => o.value == widget.initialValue)
                ? widget.initialValue
                : null;

        return DropdownButtonFormField<Object>(
          // A FormField reads initialValue once, so rebuild it when the
          // options arrive.
          key: ValueKey(loaded),
          initialValue: initial,
          decoration: InputDecoration(
            labelText: spec.label ?? spec.key,
            hintText: loaded ? null : 'Loading...',
            errorText: snapshot.hasError ? 'Failed to load options' : null,
          ),
          items: [
            for (final o in options)
              DropdownMenuItem<Object>(value: o.value, child: Text(o.label)),
          ],
          onChanged: options.isEmpty ? null : widget.onChanged,
          validator: (v) => spec.required && v == null ? 'Required' : null,
          onSaved: widget.onSaved,
        );
      },
    );
  }
}
