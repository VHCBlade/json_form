import 'dart:convert';

import 'package:flutter/material.dart';

import '../field_spec.dart';
import '../form_type/checkbox_field.dart';
import '../form_type/dropdown_field.dart';
import '../form_type/form_field.dart';
import '../form_type/text_field.dart';

class JsonFormController {
  _JsonFormState? _state;

  /// Current values of every visible field, collected without validating.
  Map<String, dynamic> collectValues() {
    final state = _state;
    if (state == null) {
      throw StateError('JsonFormController is not attached to a JsonForm');
    }
    return state.collectValues();
  }
}

class JsonForm extends StatefulWidget {
  const JsonForm({
    super.key,
    required this.schema,
    required this.onSubmit,
    this.inputs = defaultInputs,
    this.initialValues,
    this.controller,
  });

  static const List<JsonFormFieldInput> defaultInputs = [
    JsonFormTextFieldInput(),
    JsonFormDropdownFieldInput(),
    JsonFormCheckboxFieldInput(),
  ];

  final Map<String, dynamic> schema;
  final void Function(Map<String, dynamic> values) onSubmit;
  final List<JsonFormFieldInput> inputs;
  final Object? initialValues;
  final JsonFormController? controller;

  @override
  State<JsonForm> createState() => _JsonFormState();
}

class _JsonFormState extends State<JsonForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};

  late final Map<String, JsonFormFieldInput> _inputsByType = {
    for (final input in widget.inputs) input.type: input,
  };

  late final List<FieldSpec> _fields = _parseFields();

  late final Map<String, dynamic> _initialValues =
      _parseInitialValues(widget.initialValues);

  /// Current value of every field, hidden ones included, so a field that is
  /// hidden and then shown again keeps what was entered.
  late final Map<String, dynamic> _live = {
    for (final spec in _walk(_fields).where((s) => !s.isGroup))
      spec.key: _inputFor(spec).normalizeInitialValue(_initialValues[spec.key]),
  };

  /// Keys that some condition reads. Only changes to these rebuild the form.
  late final Set<String> _watched = {
    for (final spec in _walk(_fields)) ...?spec.visibleWhen?.fields,
  };

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    final controller = widget.controller;
    if (controller != null && identical(controller._state, this)) {
      controller._state = null;
    }
    super.dispose();
  }

  /// Every node of the tree, depth first, a group before its children. This
  /// is also the order in which conditions are evaluated.
  static Iterable<FieldSpec> _walk(List<FieldSpec> specs) sync* {
    for (final spec in specs) {
      yield spec;
      yield* _walk(spec.children);
    }
  }

  List<FieldSpec> _parseFields() {
    final specs = (widget.schema['fields'] as List)
        .map((f) => FieldSpec.fromJson(f as Map<String, dynamic>))
        .toList();
    final declared = <String>{};
    for (final spec in _walk(specs)) {
      if (spec.isGroup && spec.children.isEmpty) {
        throw FormatException('Group "${spec.key}" has no "fields"');
      }
      final missing =
          spec.visibleWhen?.fields.difference(declared) ?? const <String>{};
      if (missing.isNotEmpty) {
        throw FormatException(
          '"${spec.key}" is conditional on ${missing.join(', ')}, '
          'which must be declared earlier',
        );
      }
      if (!declared.add(spec.key)) {
        throw FormatException('Duplicate key: "${spec.key}"');
      }
    }
    return specs;
  }

  static Map<String, dynamic> _parseInitialValues(Object? source) {
    if (source == null) return const {};
    final decoded = source is String ? jsonDecode(source) : source;
    if (decoded is! Map) {
      throw const FormatException('initialValues must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  JsonFormFieldInput _inputFor(FieldSpec spec) =>
      _inputsByType[spec.type] ??
      (throw FormatException('No input registered for type: ${spec.type}'));

  void _changed(String key, dynamic value) {
    _live[key] = value;
    if (_watched.contains(key)) setState(() {});
  }

  Map<String, dynamic> collectValues() {
    _values.clear();
    _formKey.currentState!.save();
    return Map<String, dynamic>.of(_values);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(Map.unmodifiable(collectValues()));
    }
  }

  /// Builds the visible nodes. [effective] holds the values of visible
  /// fields only, so a hidden field or group counts as absent to every
  /// condition evaluated after it.
  List<Widget> _buildNodes(
    BuildContext context,
    List<FieldSpec> specs,
    Map<String, dynamic> effective,
  ) {
    final widgets = <Widget>[];
    for (final spec in specs) {
      if (!(spec.visibleWhen?.isMet(effective) ?? true)) continue;
      if (spec.isGroup) {
        widgets.add(
          _buildGroup(spec, _buildNodes(context, spec.children, effective)),
        );
      } else {
        effective[spec.key] = _live[spec.key];
        // Without stable keys, removing a field would hand its state to
        // whichever field takes its place.
        widgets.add(
          KeyedSubtree(
            key: ValueKey(spec.key),
            child: _inputFor(spec).build(
              context,
              spec,
              initialValue: _live[spec.key],
              onChanged: (value) => _changed(spec.key, value),
              onSaved: (value) => _values[spec.key] = value,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  /// A group is purely logical for now: it adds no visuals and no nesting
  /// to the output. This is the single place a decorator would hook in.
  Widget _buildGroup(FieldSpec spec, List<Widget> children) {
    return KeyedSubtree(
      key: ValueKey(spec.key),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          ..._buildNodes(context, _fields, <String, dynamic>{}),
          ElevatedButton(onPressed: _submit, child: const Text('Submit')),
        ],
      ),
    );
  }
}
