import 'dart:convert';

import 'package:flutter/material.dart';

import '../field_spec.dart';
import '../form_type/checkbox_field.dart';
import '../form_type/dropdown_field.dart';
import '../form_type/form_field.dart';
import '../form_type/integer_field.dart';
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
    JsonFormIntegerFieldInput(),
  ];

  /// Throws a [FormatException] describing the first problem with [schema],
  /// or returns normally if [JsonForm] can build it with [inputs]. It loads
  /// no options and builds no widgets.
  static void validateSchema(
    Map<String, dynamic> schema, {
    List<JsonFormFieldInput> inputs = defaultInputs,
  }) {
    _parseSchema(schema, _indexInputs(inputs));
  }

  final Map<String, dynamic> schema;
  final void Function(Map<String, dynamic> values) onSubmit;
  final List<JsonFormFieldInput> inputs;

  /// A JSON object to prefill from: either a decoded object (for example the
  /// result of a previous [onSubmit]) or a JSON string. It has the shape of
  /// the output, so an object group reads an object and a list group reads a
  /// list of objects. Keys and entries that match nothing are ignored.
  final Object? initialValues;
  final JsonFormController? controller;

  @override
  State<JsonForm> createState() => _JsonFormState();
}

// ---------------------------------------------------------------------------
// Schema checks
// ---------------------------------------------------------------------------

Map<String, JsonFormFieldInput> _indexInputs(List<JsonFormFieldInput> inputs) =>
    {for (final input in inputs) input.type: input};

/// Every node of the tree, depth first, a group before its children. This is
/// also the order in which conditions are evaluated.
Iterable<FieldSpec> _walk(List<FieldSpec> specs) sync* {
  for (final spec in specs) {
    yield spec;
    yield* _walk(spec.children);
  }
}

List<FieldSpec> _parseSchema(
  Map<String, dynamic> schema,
  Map<String, JsonFormFieldInput> inputsByType,
) {
  final fields = schema['fields'];
  if (fields is! List) {
    throw const FormatException('Schema needs a "fields" list');
  }
  final specs = [
    for (final f in fields)
      if (f is Map<String, dynamic>)
        FieldSpec.fromJson(f)
      else
        throw FormatException('Each field must be a JSON object: $f'),
  ];
  _checkScope(specs, inputsByType, const <String>{});
  return specs;
}

/// Checks the fields that share one output object. Flat groups belong to the
/// scope around them; object and list groups start a new one.
///
/// Keys must be unique within a scope. A condition may read any field
/// declared earlier in its own scope or in an enclosing one, never one inside
/// a nested object or list.
void _checkScope(
  List<FieldSpec> specs,
  Map<String, JsonFormFieldInput> inputsByType,
  Set<String> readable,
) {
  final keys = <String>{};
  final visible = Set<String>.of(readable);

  void walk(List<FieldSpec> nodes) {
    for (final spec in nodes) {
      if (spec.isGroup) {
        if (spec.children.isEmpty) {
          throw FormatException('Group "${spec.key}" has no "fields"');
        }
      } else {
        final input = inputsByType[spec.type];
        if (input == null) {
          throw FormatException('No input registered for type: ${spec.type}');
        }
        input.validate(spec);
      }
      final missing =
          spec.visibleWhen?.fields.difference(visible) ?? const <String>{};
      if (missing.isNotEmpty) {
        throw FormatException(
          '"${spec.key}" is conditional on ${missing.join(', ')}, '
          'which must be declared earlier',
        );
      }
      if (!keys.add(spec.key)) {
        throw FormatException('Duplicate key: "${spec.key}"');
      }
      visible.add(spec.key);

      if (!spec.isGroup) continue;
      if (spec.output == GroupOutput.flat) {
        walk(spec.children);
      } else {
        _checkScope(spec.children, inputsByType, visible);
      }
    }
  }

  walk(specs);
}

// ---------------------------------------------------------------------------
// Runtime state: what has been entered, kept apart from what is visible
// ---------------------------------------------------------------------------

/// The values of the fields that share one output object. Flat groups write
/// into the scope around them. Everything here outlives visibility, so a
/// hidden group keeps what was entered in it.
class _Scope {
  final Map<String, dynamic> live = {};
  final Map<String, _Scope> objects = {};
  final Map<String, _ListState> lists = {};
}

class _Item {
  _Item(this.id, this.scope);

  /// Stable identity, so removing an entry does not hand its state to the
  /// entry that takes its place.
  final int id;
  final _Scope scope;
}

class _ListState {
  _ListState(this.spec);

  final FieldSpec spec;
  final List<_Item> items = [];
  int _nextId = 0;

  void add(_Scope scope) => items.add(_Item(_nextId++, scope));
}

// ---------------------------------------------------------------------------
// The visible tree, rebuilt on every build
// ---------------------------------------------------------------------------

sealed class _Node {
  _Node(this.spec);

  final FieldSpec spec;
}

class _LeafNode extends _Node {
  _LeafNode(super.spec, this.scope);

  final _Scope scope;

  /// Filled in by the field's onSaved.
  bool saved = false;
  dynamic value;
}

class _FlatNode extends _Node {
  _FlatNode(super.spec, this.children);

  final List<_Node> children;
}

class _ObjectNode extends _Node {
  _ObjectNode(super.spec, this.children);

  final List<_Node> children;
}

class _EntryNode {
  _EntryNode(this.item, this.children);

  final _Item item;
  final List<_Node> children;
}

class _ListNode extends _Node {
  _ListNode(super.spec, this.state, this.entries);

  final _ListState state;
  final List<_EntryNode> entries;
}

class _JsonFormState extends State<JsonForm> {
  final _formKey = GlobalKey<FormState>();

  late final Map<String, JsonFormFieldInput> _inputsByType =
      _indexInputs(widget.inputs);

  late final List<FieldSpec> _fields =
      _parseSchema(widget.schema, _inputsByType);

  late final Map<String, dynamic> _initialValues =
      _parseInitialValues(widget.initialValues);

  late final _Scope _root = _createScope(_fields, _initialValues);

  /// Keys that some condition reads. Only changes to these rebuild the form.
  late final Set<String> _watched = {
    for (final spec in _walk(_fields)) ...?spec.visibleWhen?.fields,
  };

  /// The visible tree from the latest build. Saving walks this, so it always
  /// matches the fields that are actually mounted.
  List<_Node> _planned = const [];

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void dispose() {
    // A rebuilt form's new state attaches before the old one disposes, so
    // only detach if the controller still points at this state.
    final controller = widget.controller;
    if (controller != null && identical(controller._state, this)) {
      controller._state = null;
    }
    super.dispose();
  }

  static Map<String, dynamic> _parseInitialValues(Object? source) {
    if (source == null) return const {};
    final decoded = source is String ? jsonDecode(source) : source;
    if (decoded is! Map) {
      throw const FormatException('initialValues must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// A nested value of the wrong shape counts as absent, like any other
  /// prefill that does not fit.
  static Map<String, dynamic> _asMap(Object? value) => value is Map
      ? {for (final e in value.entries) e.key.toString(): e.value}
      : const {};

  JsonFormFieldInput _inputFor(FieldSpec spec) =>
      _inputsByType[spec.type] ??
      (throw FormatException('No input registered for type: ${spec.type}'));

  // -- state -----------------------------------------------------------------

  _Scope _createScope(List<FieldSpec> specs, Map<String, dynamic> initial) {
    final scope = _Scope();
    _populate(scope, specs, initial);
    return scope;
  }

  void _populate(
    _Scope scope,
    List<FieldSpec> specs,
    Map<String, dynamic> initial,
  ) {
    for (final spec in specs) {
      if (!spec.isGroup) {
        scope.live[spec.key] =
            _inputFor(spec).normalizeInitialValue(initial[spec.key]);
        continue;
      }
      switch (spec.output) {
        case GroupOutput.flat:
          _populate(scope, spec.children, initial);
        case GroupOutput.object:
          scope.objects[spec.key] =
              _createScope(spec.children, _asMap(initial[spec.key]));
        case GroupOutput.list:
          final state = _ListState(spec);
          final entries = initial[spec.key];
          if (entries is List) {
            for (final entry in entries) {
              state.add(_createScope(spec.children, _asMap(entry)));
            }
          }
          while (state.items.length < spec.minItems) {
            state.add(_createScope(spec.children, const {}));
          }
          scope.lists[spec.key] = state;
      }
    }
  }

  void _changed(_Scope scope, String key, dynamic value) {
    scope.live[key] = value;
    if (_watched.contains(key)) setState(() {});
  }

  void _addItem(_ListState state) {
    setState(() => state.add(_createScope(state.spec.children, const {})));
  }

  void _removeItem(_ListState state, _Item item) {
    setState(() => state.items.remove(item));
  }

  // -- visibility ------------------------------------------------------------

  /// The visible nodes of [specs]. [effective] holds the values of visible
  /// fields only, so a hidden field or group counts as absent to every
  /// condition evaluated after it. Object groups and list entries get a copy,
  /// so what they declare stays inside them while they can still read what
  /// was declared before them.
  List<_Node> _plan(
    List<FieldSpec> specs,
    _Scope scope,
    Map<String, dynamic> effective,
  ) {
    final nodes = <_Node>[];
    for (final spec in specs) {
      if (!(spec.visibleWhen?.isMet(effective) ?? true)) continue;
      if (!spec.isGroup) {
        effective[spec.key] = scope.live[spec.key];
        nodes.add(_LeafNode(spec, scope));
        continue;
      }
      switch (spec.output) {
        case GroupOutput.flat:
          nodes.add(_FlatNode(spec, _plan(spec.children, scope, effective)));
        case GroupOutput.object:
          nodes.add(
            _ObjectNode(
              spec,
              _plan(
                spec.children,
                scope.objects[spec.key]!,
                Map<String, dynamic>.of(effective),
              ),
            ),
          );
        case GroupOutput.list:
          final state = scope.lists[spec.key]!;
          nodes.add(
            _ListNode(spec, state, [
              for (final item in state.items)
                _EntryNode(
                  item,
                  _plan(
                    spec.children,
                    item.scope,
                    Map<String, dynamic>.of(effective),
                  ),
                ),
            ]),
          );
      }
    }
    return nodes;
  }

  // -- output ----------------------------------------------------------------

  /// Hidden fields are not mounted, so they are skipped here and absent from
  /// the result. A visible object group gives an object and a visible list
  /// group gives a list, even if either is empty.
  Map<String, dynamic> collectValues() {
    _formKey.currentState!.save();
    return _assemble(_planned);
  }

  Map<String, dynamic> _assemble(List<_Node> nodes) {
    final out = <String, dynamic>{};
    _assembleInto(nodes, out);
    return out;
  }

  void _assembleInto(List<_Node> nodes, Map<String, dynamic> out) {
    for (final node in nodes) {
      switch (node) {
        case _LeafNode leaf:
          if (leaf.saved) out[leaf.spec.key] = leaf.value;
        case _FlatNode flat:
          _assembleInto(flat.children, out);
        case _ObjectNode object:
          out[object.spec.key] = _assemble(object.children);
        case _ListNode list:
          out[list.spec.key] = [
            for (final entry in list.entries) _assemble(entry.children),
          ];
      }
    }
  }

  static Object? _freeze(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.unmodifiable({
        for (final e in value.entries) e.key as String: _freeze(e.value),
      });
    }
    if (value is List) {
      return List<Object?>.unmodifiable(value.map(_freeze));
    }
    return value;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_freeze(collectValues()) as Map<String, dynamic>);
    }
  }

  // -- widgets ---------------------------------------------------------------

  List<Widget> _widgets(BuildContext context, List<_Node> nodes) =>
      [for (final node in nodes) _widgetFor(context, node)];

  Widget _widgetFor(BuildContext context, _Node node) {
    switch (node) {
      case _LeafNode leaf:
        // Without stable keys, removing a field would hand its state to
        // whichever field takes its place.
        return KeyedSubtree(
          key: ValueKey(leaf.spec.key),
          child: _inputFor(leaf.spec).build(
            context,
            leaf.spec,
            initialValue: leaf.scope.live[leaf.spec.key],
            onChanged: (value) => _changed(leaf.scope, leaf.spec.key, value),
            onSaved: (value) {
              leaf.saved = true;
              leaf.value = value;
            },
          ),
        );
      case _FlatNode flat:
        return _buildGroup(flat.spec, _widgets(context, flat.children));
      case _ObjectNode object:
        return _buildGroup(object.spec, _widgets(context, object.children));
      case _ListNode list:
        return _buildList(context, list);
    }
  }

  /// Flat and object groups add no visuals. This is where a decorator would
  /// hook in.
  Widget _buildGroup(FieldSpec spec, List<Widget> children) {
    return KeyedSubtree(
      key: ValueKey(spec.key),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _buildList(BuildContext context, _ListNode node) {
    final spec = node.spec;
    final state = node.state;
    final canAdd = spec.maxItems == null || state.items.length < spec.maxItems!;
    final canRemove = state.items.length > spec.minItems;

    return KeyedSubtree(
      key: ValueKey(spec.key),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (spec.label != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                spec.label!,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          for (final entry in node.entries)
            KeyedSubtree(
              key: ValueKey('${spec.key}#${entry.item.id}'),
              child: Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ..._widgets(context, entry.children),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: canRemove
                              ? () => _removeItem(state, entry.item)
                              : null,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: canAdd ? () => _addItem(state) : null,
              icon: const Icon(Icons.add),
              label: Text(spec.addLabel ?? 'Add'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _planned = _plan(_fields, _root, <String, dynamic>{});
    return Form(
      key: _formKey,
      child: Column(
        children: [
          ..._widgets(context, _planned),
          ElevatedButton(onPressed: _submit, child: const Text('Submit')),
        ],
      ),
    );
  }
}
