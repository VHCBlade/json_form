import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:json_form/json_form.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSON form example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: const ExamplePage(),
    );
  }
}

class Preset {
  const Preset(this.name, this.schema, [this.sampleJson]);

  final String name;
  final Map<String, dynamic> schema;

  /// Raw JSON text, used by "Load sample" to show string input. Null for
  /// presets the user adds, which have no sample.
  final String? sampleJson;
}

final List<Preset> presets = [
  const Preset(
    'Text fields',
    {
      'fields': [
        {'key': 'name', 'type': 'text', 'label': 'Name', 'required': true},
        {'key': 'email', 'type': 'text', 'label': 'Email'},
        {'key': 'notes', 'type': 'text', 'label': 'Notes'},
      ],
    },
    '{"name": "Ada Lovelace", "email": "ada@example.com", '
        '"notes": "Prefilled from a JSON string."}',
  ),
  const Preset(
    'Dropdowns with inline options',
    {
      'fields': [
        {
          'key': 'size',
          'type': 'dropdown',
          'label': 'Size',
          'required': true,
          'options': ['Small', 'Medium', 'Large'],
        },
        {
          'key': 'role',
          'type': 'dropdown',
          'label': 'Role',
          'options': [
            {'value': 'adm', 'label': 'Administrator'},
            {'value': 'usr', 'label': 'User'},
            {'value': 'gst', 'label': 'Guest'},
          ],
        },
      ],
    },
    '{"size": "Medium", "role": "usr"}',
  ),
  const Preset(
    'Dropdown with a remote source',
    {
      'fields': [
        {
          'key': 'country',
          'type': 'dropdown',
          'label': 'Country',
          'required': true,
          'optionsSource': 'countries',
        },
      ],
    },
    '{"country": "JP"}',
  ),
  const Preset(
    'Checkboxes',
    {
      'fields': [
        {
          'key': 'terms',
          'type': 'checkbox',
          'label': 'I accept the terms',
          'required': true,
        },
        {
          'key': 'updates',
          'type': 'checkbox',
          'label': 'Send me product updates',
        },
      ],
    },
    '{"terms": true, "updates": false}',
  ),
  const Preset(
    'Conditional fields',
    {
      'fields': [
        {'key': 'hasPet', 'type': 'checkbox', 'label': 'I have a pet'},
        {
          'key': 'petName',
          'type': 'text',
          'label': 'Pet name',
          'required': true,
          'visibleWhen': {'field': 'hasPet', 'equals': true},
        },
        {
          'key': 'wantsPet',
          'type': 'text',
          'label': 'Would you like to get one?',
          'visibleWhen': {'field': 'hasPet', 'equals': false},
        },
      ],
    },
    '{"hasPet": true, "petName": "Biscuit"}',
  ),
  const Preset(
    'Groups',
    {
      'fields': [
        {'key': 'hasPet', 'type': 'checkbox', 'label': 'I have a pet'},
        {
          'key': 'petDetails',
          'type': 'group',
          'visibleWhen': {'field': 'hasPet', 'equals': true},
          'fields': [
            {
              'key': 'petName',
              'type': 'text',
              'label': 'Pet name',
              'required': true,
            },
            {
              'key': 'petSpecies',
              'type': 'dropdown',
              'label': 'Species',
              'options': ['Dog', 'Cat', 'Other'],
            },
            {
              'key': 'petInsured',
              'type': 'checkbox',
              'label': 'Insured',
            },
            {
              'key': 'insurer',
              'type': 'text',
              'label': 'Insurer',
              'visibleWhen': {'field': 'petInsured', 'equals': true},
            },
          ],
        },
      ],
    },
    '{"hasPet": true, "petName": "Biscuit", "petSpecies": "Dog", '
        '"petInsured": true, "insurer": "Acme Mutual"}',
  ),
  const Preset(
    'Integers with a range',
    {
      'fields': [
        {
          'key': 'age',
          'type': 'integer',
          'label': 'Age',
          'min': 18,
          'max': 120,
          'required': true,
        },
        {
          'key': 'quantity',
          'type': 'integer',
          'label': 'Quantity',
          'max': 10,
        },
        {'key': 'offset', 'type': 'integer', 'label': 'Offset'},
      ],
    },
    '{"age": 200, "quantity": 3, "offset": -5}',
  ),
  const Preset(
    'Multiline text',
    {
      'fields': [
        {
          'key': 'subject',
          'type': 'text',
          'label': 'Subject',
          'required': true
        },
        {
          'key': 'description',
          'type': 'text',
          'label': 'Description',
          'minLines': 4,
          'maxLines': 8,
          'required': true,
        },
        {
          'key': 'notes',
          'type': 'text',
          'label': 'Notes (optional)',
          'maxLines': 3,
        },
        {
          'key': 'log',
          'type': 'text',
          'label': 'Log (optional)',
          'minLines': 2,
        },
      ],
    },
    '{"subject": "Login fails", '
        '"description": "Line one\\nLine two\\nLine three", "notes": "", '
        '"log": ""}',
  ),
  const Preset(
    'All field types',
    {
      'fields': [
        {'key': 'name', 'type': 'text', 'label': 'Name', 'required': true},
        {
          'key': 'plan',
          'type': 'dropdown',
          'label': 'Plan',
          'options': ['Free', 'Team', 'Enterprise'],
        },
        {
          'key': 'country',
          'type': 'dropdown',
          'label': 'Country',
          'optionsSource': 'countries',
        },
        {
          'key': 'terms',
          'type': 'checkbox',
          'label': 'I accept the terms',
          'required': true,
        },
      ],
    },
    '{"name": "Ada Lovelace", "plan": "Team", "country": "NO", '
        '"terms": true}',
  ),
];

/// Stand-in for a real remote source: returns a fixed list after a delay.
class CountriesSource extends JsonFormOptionsSource {
  const CountriesSource();

  @override
  Future<List<JsonFormOption>> load(FieldSpec spec) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return const [
      JsonFormOption(value: 'BR', label: 'Brazil'),
      JsonFormOption(value: 'CA', label: 'Canada'),
      JsonFormOption(value: 'JP', label: 'Japan'),
      JsonFormOption(value: 'KE', label: 'Kenya'),
      JsonFormOption(value: 'NO', label: 'Norway'),
    ];
  }
}

String pretty(Object? json) => const JsonEncoder.withIndent('  ').convert(json);

const _mono = TextStyle(fontFamily: 'monospace', fontSize: 13);

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final List<JsonFormFieldInput> _inputs = [
    ...JsonForm.defaultInputs,
    const JsonFormDropdownFieldInput(sources: {'countries': CountriesSource()}),
  ];

  final JsonFormController _controller = JsonFormController();

  /// Data saved in memory, per preset. Lost when the app restarts.
  final Map<String, Map<String, dynamic>> _saved = {};

  int _index = 0;
  int _generation = 0;
  Object? _initial;
  Map<String, dynamic>? _submitted;

  /// The built-in presets plus any the user adds this session.
  late final List<Preset> _presets = [...presets];
  int _customCount = 0;

  Preset get _preset => _presets[_index];
  Map<String, dynamic>? get _savedForPreset => _saved[_preset.name];

  /// JsonForm reads its schema and initial values once, so a new key is how
  /// the form is rebuilt, either empty or prefilled.
  void _reload([Object? initial]) {
    setState(() {
      _initial = initial;
      _generation++;
    });
  }

  void _selectPreset(int? index) {
    if (index == null || index == _index) return;
    setState(() {
      _index = index;
      _initial = null;
      _generation++;
      _submitted = null;
    });
  }

  /// Asks for a schema and, once it checks out, adds it for this session and
  /// switches to it.
  Future<void> _addCustomPreset() async {
    final preset = await showDialog<Preset>(
      context: context,
      builder: (_) => _CustomPresetDialog(
        inputs: _inputs,
        initialJson: pretty(_preset.schema),
        existingNames: {for (final p in _presets) p.name},
        suggestedName: 'Custom ${_customCount + 1}',
      ),
    );
    if (preset == null || !mounted) return;
    setState(() {
      _presets.add(preset);
      _customCount++;
      _index = _presets.length - 1;
      _initial = null;
      _generation++;
      _submitted = null;
    });
  }

  /// Saves whatever is currently entered, valid or not.
  void _save() {
    final values = _controller.collectValues();
    setState(() => _saved[_preset.name] = values);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Saved')));
  }

  @override
  Widget build(BuildContext context) {
    final saved = _savedForPreset;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: DropdownMenu<int>(
                        // initialSelection is read once, so rebuild the menu
                        // when a preset is added.
                        key: ValueKey(_presets.length),
                        expandedInsets: EdgeInsets.zero,
                        label: const Text('Preset'),
                        initialSelection: _index,
                        requestFocusOnTap: false,
                        onSelected: _selectPreset,
                        dropdownMenuEntries: [
                          for (var i = 0; i < _presets.length; i++)
                            DropdownMenuEntry<int>(
                              value: i,
                              label: _presets[i].name,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _addCustomPreset,
                    icon: const Icon(Icons.add),
                    label: const Text('Custom JSON'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                  Tooltip(
                    message: 'Fills the form from the saved data, '
                        'passed as a decoded object',
                    child: OutlinedButton.icon(
                      onPressed: saved == null ? null : () => _reload(saved),
                      icon: const Icon(Icons.restore),
                      label: const Text('Load saved'),
                    ),
                  ),
                  Tooltip(
                    message: 'Fills the form from the preset sample, '
                        'passed as a JSON string',
                    child: OutlinedButton.icon(
                      onPressed: _preset.sampleJson == null
                          ? null
                          : () => _reload(_preset.sampleJson),
                      icon: const Icon(Icons.data_object),
                      label: const Text('Load sample'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;
                    return Flex(
                      direction: wide ? Axis.horizontal : Axis.vertical,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Panel(
                            title: 'Form',
                            child: JsonForm(
                              key: ValueKey(_generation),
                              schema: _preset.schema,
                              inputs: _inputs,
                              controller: _controller,
                              initialValues: _initial,
                              onSubmit: (values) =>
                                  setState(() => _submitted = values),
                            ),
                          ),
                        ),
                        SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
                        Expanded(
                          child: _DataTabs(
                            schema: pretty(_preset.schema),
                            submitted: _submitted == null
                                ? 'Submit the form to see its output. '
                                    'Submitting validates the fields first.'
                                : pretty(_submitted),
                            saved: saved == null
                                ? 'Nothing saved for this preset yet. '
                                    'Saving does not validate.'
                                : pretty(saved),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataTabs extends StatelessWidget {
  const _DataTabs({
    required this.schema,
    required this.submitted,
    required this.saved,
  });

  final String schema;
  final String submitted;
  final String saved;

  Widget _tab(String text) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: SelectableText(text, style: _mono),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Card.outlined(
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Input JSON'),
                Tab(text: 'Submitted'),
                Tab(text: 'Saved'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_tab(schema), _tab(submitted), _tab(saved)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parses [text] and checks that [JsonForm] can build it. Throws a
/// [FormatException] with a readable message otherwise.
Map<String, dynamic> parseSchema(String text, List<JsonFormFieldInput> inputs) {
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

/// Collects a name and a schema, and only returns a [Preset] once the schema
/// has been checked.
class _CustomPresetDialog extends StatefulWidget {
  const _CustomPresetDialog({
    required this.inputs,
    required this.initialJson,
    required this.existingNames,
    required this.suggestedName,
  });

  final List<JsonFormFieldInput> inputs;
  final String initialJson;
  final Set<String> existingNames;
  final String suggestedName;

  @override
  State<_CustomPresetDialog> createState() => _CustomPresetDialogState();
}

class _CustomPresetDialogState extends State<_CustomPresetDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.suggestedName);
  late final TextEditingController _json =
      TextEditingController(text: widget.initialJson);

  String? _nameError;
  String? _jsonError;

  @override
  void dispose() {
    _name.dispose();
    _json.dispose();
    super.dispose();
  }

  void _add() {
    final name = _name.text.trim();
    String? nameError;
    if (name.isEmpty) {
      nameError = 'Give the preset a name';
    } else if (widget.existingNames.contains(name)) {
      nameError = 'A preset with this name already exists';
    }

    String? jsonError;
    Map<String, dynamic>? schema;
    try {
      schema = parseSchema(_json.text, widget.inputs);
    } on FormatException catch (e) {
      jsonError = e.message;
    }

    setState(() {
      _nameError = nameError;
      _jsonError = jsonError;
    });
    if (nameError == null && schema != null) {
      Navigator.pop(context, Preset(name, schema));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a preset from JSON'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Preset name',
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _json,
                minLines: 14,
                maxLines: 14,
                style: _mono,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Schema JSON',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                  errorText: _jsonError,
                  errorMaxLines: 6,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _add, child: const Text('Add preset')),
      ],
    );
  }
}
