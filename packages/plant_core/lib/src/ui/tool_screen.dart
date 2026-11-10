import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings.dart';
import '../tool.dart';
import '../units.dart';

class ToolScreen extends StatefulWidget {
  const ToolScreen({super.key, required this.tool});
  final ToolDef tool;

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  final _controllers = <String, TextEditingController>{};
  final _inputUnits = <String, String>{};
  final _outputUnits = <String, String>{};
  final _choices = <String, String>{};
  UnitSystem? _system;
  final _scroll = ScrollController();

  ToolDef get tool => widget.tool;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final system = SettingsScope.of(context).unitSystem;
    if (_system == system) return;
    final first = _system == null;
    _system = system;
    _outputUnits.clear();
    final current = first ? tool.initialValues() : _values();
    for (final i in tool.inputs) {
      switch (i) {
        case NumberInput():
          final u = Units.preferred(i.quantity, system, i.units);
          _inputUnits[i.id] = u.id;
          final base = current.numbers[i.id] ?? i.initial;
          final text = base.isNaN ? '' : formatNumber(u.fromBase(base), sig: 6);
          (_controllers[i.id] ??= TextEditingController()).text = text;
        case ChoiceInput():
          _choices[i.id] = current.choices[i.id] ?? i.initial;
        case ListInput():
          final u = Units.preferred(i.quantity, system, i.units);
          _inputUnits[i.id] = u.id;
          final base = current.lists[i.id] ?? i.initial;
          (_controllers[i.id] ??= TextEditingController()).text = _listText(
            base,
            u,
          );
      }
    }
  }

  String _listText(List<double> base, Unit u) => base.any((x) => x.isNaN)
      ? ''
      : base.map((x) => formatNumber(u.fromBase(x), sig: 6)).join(', ');

  /// Splits on spaces, commas, semicolons and new lines; '.' is the decimal
  /// point. An unparsable item yields NaN so validation flags the field.
  List<double> _parseList(String s) => [
    for (final t in s.split(RegExp(r'[\s,;]+')))
      if (t.isNotEmpty) double.tryParse(t) ?? double.nan,
  ];

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  double _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.')) ?? double.nan;

  ToolValues _values() {
    final numbers = <String, double>{};
    for (final i in tool.inputs.whereType<NumberInput>()) {
      final raw = _parse(_controllers[i.id]?.text ?? '');
      numbers[i.id] = raw.isNaN
          ? double.nan
          : Units.byId(i.quantity, _inputUnits[i.id]!).toBase(raw);
    }
    final lists = <String, List<double>>{};
    for (final i in tool.inputs.whereType<ListInput>()) {
      final u = Units.byId(i.quantity, _inputUnits[i.id]!);
      lists[i.id] = [
        for (final x in _parseList(_controllers[i.id]?.text ?? '')) u.toBase(x),
      ];
    }
    return ToolValues(numbers, Map.of(_choices), lists);
  }

  void _loadCase(ToolCase c) {
    setState(() {
      final base = tool.initialValues();
      _choices
        ..clear()
        ..addAll(base.choices)
        ..addAll(c.choices);
      for (final i in tool.inputs.whereType<NumberInput>()) {
        final given = c.numbers[i.id];
        if (given != null) {
          _inputUnits[i.id] = Units.byId(i.quantity, given.$2).id;
          _controllers[i.id]!.text = formatNumber(given.$1, sig: 8);
        } else {
          final u = Units.byId(i.quantity, _inputUnits[i.id]!);
          _controllers[i.id]!.text = formatNumber(
            u.fromBase(i.initial),
            sig: 6,
          );
        }
      }
      for (final i in tool.inputs.whereType<ListInput>()) {
        final given = c.lists[i.id];
        if (given != null) {
          _inputUnits[i.id] = Units.byId(i.quantity, given.$2).id;
          _controllers[i.id]!.text = given.$1
              .map((x) => formatNumber(x, sig: 8))
              .join(', ');
        } else {
          _controllers[i.id]!.text = _listText(
            i.initial,
            Units.byId(i.quantity, _inputUnits[i.id]!),
          );
        }
      }
      c.expect.forEach((k, v) => _outputUnits[k] = v.$2);
    });
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded: ${c.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _outputUnitId(ToolOutput o) =>
      o.fixedUnit ??
      _outputUnits[o.id] ??
      Units.preferred(o.quantity, _system!, o.units).id;

  String _formatOutput(ToolOutput o) {
    if (o.text != null) return o.text!;
    final u = Units.byId(o.quantity, _outputUnitId(o));
    return formatNumber(u.fromBase(o.value), sig: o.sig);
  }

  String _resultText(ToolValues v, ToolResult r) {
    final b = StringBuffer('${tool.title}\n');
    for (final i in tool.inputs) {
      if (!i.isVisible(v)) continue;
      switch (i) {
        case NumberInput():
          final u = Units.byId(i.quantity, _inputUnits[i.id]!);
          b.writeln(
            '${i.label}: ${_controllers[i.id]!.text} ${u.symbol}${i.unitSuffix != null ? ' ${i.unitSuffix}' : ''}',
          );
        case ChoiceInput():
          final o = i.options.firstWhere(
            (o) => o.value == _choices[i.id],
            orElse: () => i.options.first,
          );
          b.writeln('${i.label}: ${o.label}');
        case ListInput():
          final u = Units.byId(i.quantity, _inputUnits[i.id]!);
          b.writeln('${i.label}: ${_controllers[i.id]!.text} ${u.symbol}');
      }
    }
    b.writeln('—');
    for (final o in r.outputs) {
      final unit = o.text != null
          ? ''
          : ' ${Units.byId(o.quantity, _outputUnitId(o)).symbol}';
      b.writeln('${o.label}: ${_formatOutput(o)}$unit');
    }
    for (final w in r.warnings) {
      b.writeln('! $w');
    }
    b.writeln('Ref: ${tool.references.join('; ')}');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final values = _values();
    final errors = tool.validate(values);
    ToolResult? result;
    String? error;
    if (errors.isEmpty) {
      try {
        result = tool.compute(values);
      } on ToolInputError catch (e) {
        error = e.message;
      } catch (e) {
        error = 'Cannot calculate with these inputs.';
      }
    } else {
      error = 'Check the highlighted inputs.';
    }

    return Scaffold(
      bottomNavigationBar: result == null ? null : _keyResultBar(result),
      appBar: AppBar(
        // Long tool names wrap to two lines instead of being cut off at
        // large font sizes.
        toolbarHeight: kToolbarHeight + 12,
        title: Text(
          tool.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          if (result != null)
            IconButton(
              tooltip: 'Copy inputs and results',
              icon: const Icon(Icons.copy_all),
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: _resultText(values, result!)),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  tool.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final i in tool.inputs)
                  if (i.isVisible(values))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: switch (i) {
                        NumberInput() => _numberField(i, errors[i.id]),
                        ChoiceInput() => _choiceField(i),
                        ListInput() => _listField(i, errors[i.id]),
                      },
                    ),
                const SizedBox(height: 8),
                _resultsCard(result, error),
                const SizedBox(height: 8),
                _formulaSheet(),
                _examples(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pinned summary of the headline outputs, so long forms give live
  /// feedback without scrolling.
  Widget? _keyResultBar(ToolResult r) {
    final key = r.outputs
        .where((o) => o.level != OutputLevel.normal)
        .take(2)
        .toList();
    if (key.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              for (final o in key)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        o.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        o.text ??
                            '${_formatOutput(o)} ${Units.byId(o.quantity, _outputUnitId(o)).symbol}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              if (r.warnings.isNotEmpty)
                Tooltip(
                  message: '${r.warnings.length} warning(s) — see Results',
                  child: Icon(
                    Icons.warning_amber,
                    color: Colors.orange.shade800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(NumberInput i, String? error) {
    final units = Units.of(i.quantity);
    final unit = Units.byId(i.quantity, _inputUnits[i.id]!);
    final suffix = [unit.symbol, ?i.unitSuffix].join(' ').trim();
    return TextField(
      key: ValueKey('in-${i.id}'),
      controller: _controllers[i.id],
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9eE.,+\-]')),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: i.label,
        helperText: i.help,
        helperMaxLines: 3,
        errorText: error,
        suffixIcon: units.length > 1
            ? Padding(
                padding: const EdgeInsets.only(right: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: unit.id,
                    items: [
                      for (final u in units)
                        DropdownMenuItem(
                          value: u.id,
                          child: Text([u.symbol, ?i.unitSuffix].join(' ')),
                        ),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      setState(() {
                        final v = _parse(_controllers[i.id]!.text);
                        if (!v.isNaN) {
                          _controllers[i.id]!.text = formatNumber(
                            Units.byId(i.quantity, id).fromBase(unit.toBase(v)),
                            sig: 6,
                          );
                        }
                        _inputUnits[i.id] = id;
                      });
                    },
                  ),
                ),
              )
            : (suffix.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(widthFactor: 1, child: Text(suffix)),
                    )),
      ),
    );
  }

  Widget _listField(ListInput i, String? error) {
    final units = Units.of(i.quantity);
    final unit = Units.byId(i.quantity, _inputUnits[i.id]!);
    final count = _parseList(_controllers[i.id]!.text).length;
    return TextField(
      key: ValueKey('in-${i.id}'),
      controller: _controllers[i.id],
      keyboardType: TextInputType.multiline,
      minLines: 2,
      maxLines: 6,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: i.label,
        helperText: [
          '$count value${count == 1 ? '' : 's'} · separate with spaces, commas or new lines',
          ?i.help,
        ].join('\n'),
        helperMaxLines: 4,
        errorText: error,
        suffixIcon: units.length > 1
            ? Padding(
                padding: const EdgeInsets.only(right: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: unit.id,
                    items: [
                      for (final u in units)
                        DropdownMenuItem(value: u.id, child: Text(u.symbol)),
                    ],
                    onChanged: (id) {
                      if (id == null) return;
                      setState(() {
                        final xs = _parseList(_controllers[i.id]!.text);
                        _controllers[i.id]!.text = _listText([
                          for (final x in xs) unit.toBase(x),
                        ], Units.byId(i.quantity, id));
                        _inputUnits[i.id] = id;
                      });
                    },
                  ),
                ),
              )
            : (unit.symbol.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Center(widthFactor: 1, child: Text(unit.symbol)),
                    )),
      ),
    );
  }

  Widget _choiceField(ChoiceInput i) {
    final short =
        i.options.length <= 4 && i.options.every((o) => o.label.length <= 22);
    if (short) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          // Chips wrap to a new line instead of breaking words when the
          // phone uses a large font.
          Wrap(
            key: ValueKey('in-${i.id}'),
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final o in i.options)
                ChoiceChip(
                  label: Text(o.label),
                  selected: _choices[i.id] == o.value,
                  onSelected: (_) => setState(() => _choices[i.id] = o.value),
                ),
            ],
          ),
          if (i.help != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                i.help!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('in-${i.id}-${_choices[i.id]}'),
      initialValue: _choices[i.id],
      isExpanded: true,
      decoration: InputDecoration(
        labelText: i.label,
        helperText: i.help,
        helperMaxLines: 3,
      ),
      items: [
        for (final o in i.options)
          DropdownMenuItem(value: o.value, child: Text(o.label)),
      ],
      onChanged: (v) => setState(() => _choices[i.id] = v ?? i.initial),
    );
  }

  Widget _resultsCard(ToolResult? r, String? error) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (r == null) {
      return Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            error ?? '',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
        ),
      );
    }
    Color? colorFor(OutputLevel l) => switch (l) {
      OutputLevel.ok => Colors.green.shade700,
      OutputLevel.warn => Colors.orange.shade800,
      OutputLevel.fail => scheme.error,
      _ => null,
    };
    return Card(
      color: scheme.secondaryContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Results', style: text.titleMedium),
            const SizedBox(height: 4),
            for (final w in r.warnings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 18,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(w, style: text.bodySmall)),
                  ],
                ),
              ),
            LayoutBuilder(
              builder: (context, c) {
                // Stack label over value when the row is narrow for the
                // user's text size (large phone fonts).
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final compact = c.maxWidth / scale < 400;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final o in r.outputs)
                      _outputRow(o, compact, colorFor(o.level)),
                  ],
                );
              },
            ),
            for (final n in r.notes)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(n, style: text.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  Widget _outputRow(ToolOutput o, bool compact, Color? color) {
    final text = Theme.of(context).textTheme;
    final primary = o.level == OutputLevel.primary;
    final label = Text(
      o.label,
      style: compact
          ? text.bodySmall
          : (primary
                ? text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
                : text.bodyMedium),
    );
    final value = SelectableText(
      _formatOutput(o),
      key: ValueKey('out-${o.id}'),
      textAlign: compact ? TextAlign.left : TextAlign.right,
      style: (primary ? text.titleLarge : text.bodyLarge)?.copyWith(
        color: color,
        fontWeight: o.level == OutputLevel.normal ? null : FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            Row(
              children: [
                Flexible(child: value),
                _outputUnit(o),
              ],
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: label),
          Flexible(child: value),
          _outputUnit(o),
        ],
      ),
    );
  }

  Widget _outputUnit(ToolOutput o) {
    if (o.text != null) return const SizedBox(width: 8);
    final units = Units.of(o.quantity);
    final u = Units.byId(o.quantity, _outputUnitId(o));
    if (o.fixedUnit != null || units.length == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, maxWidth: 150),
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(u.symbol),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 150),
      child: PopupMenuButton<String>(
        tooltip: 'Change unit',
        initialValue: u.id,
        onSelected: (id) => setState(() => _outputUnits[o.id] = id),
        itemBuilder: (_) => [
          for (final x in units)
            PopupMenuItem(value: x.id, child: Text(x.symbol)),
        ],
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(u.symbol, overflow: TextOverflow.ellipsis)),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formulaSheet() {
    final text = Theme.of(context).textTheme;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.functions),
        title: const Text('Formula & reference'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            tool.formula,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text('References', style: text.titleSmall),
          for (final r in tool.references) Text('• $r', style: text.bodySmall),
          if (tool.assumptions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Assumptions & limits', style: text.titleSmall),
            for (final a in tool.assumptions)
              Text('• $a', style: text.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _examples() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('Worked examples'),
        subtitle: const Text('Verified cases — tap to load'),
        children: [
          for (final c in tool.cases)
            ListTile(
              dense: true,
              title: Text(c.name),
              subtitle: Text(c.source),
              trailing: const Icon(Icons.upload_file),
              onTap: () => _loadCase(c),
            ),
        ],
      ),
    );
  }
}
