/// Tool definition pattern: one [ToolDef] per tool, holding inputs, the
/// calculation, outputs, the cited reference and its worked test cases.
library;

import 'package:flutter/widgets.dart' show IconData;

import 'units.dart';

/// Values entered by the user, already converted to base units.
class ToolValues {
  ToolValues(this.numbers, this.choices, [this.lists = const {}]);

  final Map<String, double> numbers;
  final Map<String, String> choices;

  /// Lists of numbers (data sets, stations, loads), in base units.
  final Map<String, List<double>> lists;

  List<double> l(String id) {
    final v = lists[id];
    if (v == null) throw ToolInputError('Missing list: $id');
    return v;
  }

  double n(String id) {
    final v = numbers[id];
    if (v == null) throw ToolInputError('Missing value: $id');
    return v;
  }

  String c(String id) => choices[id] ?? '';
}

sealed class ToolInput {
  const ToolInput(this.id, this.label, {this.help, this.visibleWhen});

  final String id;
  final String label;
  final String? help;

  /// Hides the input (and skips its validation) unless this returns true.
  final bool Function(ToolValues v)? visibleWhen;

  bool isVisible(ToolValues v) => visibleWhen?.call(v) ?? true;
}

class NumberInput extends ToolInput {
  const NumberInput(
    super.id,
    super.label, {
    required this.quantity,
    required this.initial,
    this.min,
    this.max,
    this.minInclusive = true,
    super.help,
    super.visibleWhen,
    this.unitSuffix,
    this.units,
  });

  final Quantity quantity;

  /// (metric, imperial) unit ids shown by default, overriding the
  /// quantity-wide defaults (e.g. mL for a burette reading).
  final (String, String)? units;

  /// Initial value in base units.
  final double initial;

  /// Allowed range in base units (null = unbounded).
  final double? min;
  final double? max;
  final bool minInclusive;

  /// Extra text after the unit, e.g. "abs" or "g".
  final String? unitSuffix;
}

/// A list of numbers typed into one field, separated by spaces, commas,
/// semicolons or new lines (decimal point must be '.').
class ListInput extends ToolInput {
  const ListInput(
    super.id,
    super.label, {
    required this.quantity,
    required this.initial,
    this.minCount = 1,
    this.maxCount,
    this.min,
    this.max,
    super.help,
    super.visibleWhen,
    this.units,
  });

  final Quantity quantity;

  /// Initial values in base units.
  final List<double> initial;
  final int minCount;
  final int? maxCount;

  /// Allowed range for every value, in base units.
  final double? min;
  final double? max;
  final (String, String)? units;
}

class ChoiceOption {
  const ChoiceOption(this.value, this.label);
  final String value;
  final String label;
}

class ChoiceInput extends ToolInput {
  const ChoiceInput(
    super.id,
    super.label, {
    required this.options,
    String? initial,
    super.help,
    super.visibleWhen,
  }) : _initial = initial;

  final List<ChoiceOption> options;
  final String? _initial;
  String get initial => _initial ?? options.first.value;
}

enum OutputLevel { normal, primary, ok, warn, fail }

class ToolOutput {
  const ToolOutput(
    this.id,
    this.label,
    this.value, {
    this.quantity = Quantity.dimensionless,
    this.level = OutputLevel.normal,
    this.fixedUnit,
    this.sig = 5,
    this.text,
    this.units,
  });

  /// Text-only output (status lines, verdicts).
  const ToolOutput.text(
    this.id,
    this.label,
    String this.text, {
    this.level = OutputLevel.normal,
  }) : value = double.nan,
       quantity = Quantity.dimensionless,
       fixedUnit = null,
       sig = 5,
       units = null;

  final String id;
  final String label;

  /// Value in base units.
  final double value;
  final Quantity quantity;
  final OutputLevel level;

  /// Unit id this output is always shown in (no unit picker).
  final String? fixedUnit;
  final int sig;
  final String? text;

  /// (metric, imperial) default display units; see [NumberInput.units].
  final (String, String)? units;
}

class ToolResult {
  const ToolResult(
    this.outputs, {
    this.warnings = const [],
    this.notes = const [],
  });

  final List<ToolOutput> outputs;

  /// Validity-range or physics warnings — shown prominently.
  final List<String> warnings;
  final List<String> notes;

  ToolOutput? operator [](String id) {
    for (final o in outputs) {
      if (o.id == id) return o;
    }
    return null;
  }
}

/// Thrown by a tool for input combinations it cannot compute.
class ToolInputError implements Exception {
  ToolInputError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A worked example the tool must reproduce. Inputs are given as
/// `{id: (value, unitId)}` for numbers and `{id: value}` for choices;
/// expected outputs as `{outputId: (value, unitId)}`.
class ToolCase {
  const ToolCase(
    this.name, {
    required this.source,
    this.numbers = const {},
    this.choices = const {},
    this.lists = const {},
    this.expect = const {},
    this.expectText = const {},
    this.relTol = 1e-3,
    this.absTol = 0,
    this.expectWarning,
  });

  final String name;

  /// Where the expected numbers come from (standard table, worked example,
  /// independent implementation).
  final String source;
  final Map<String, (double, String)> numbers;
  final Map<String, String> choices;

  /// List inputs as `{id: ([values], unitId)}`.
  final Map<String, (List<double>, String)> lists;
  final Map<String, (double, String)> expect;
  final Map<String, String> expectText;
  final double relTol;
  final double absTol;

  /// Substring that must appear in one of the warnings.
  final String? expectWarning;
}

class ToolDef {
  const ToolDef({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.inputs,
    required this.compute,
    required this.formula,
    required this.references,
    required this.cases,
    this.assumptions = const [],
    this.keywords = const [],
  });

  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final List<ToolInput> inputs;
  final ToolResult Function(ToolValues v) compute;

  /// Plain-text formula sheet (monospace).
  final String formula;
  final List<String> references;
  final List<String> assumptions;
  final List<ToolCase> cases;
  final List<String> keywords;

  ToolValues initialValues() => ToolValues(
    {for (final i in inputs.whereType<NumberInput>()) i.id: i.initial},
    {for (final i in inputs.whereType<ChoiceInput>()) i.id: i.initial},
    {for (final i in inputs.whereType<ListInput>()) i.id: i.initial},
  );

  /// Range checks for visible inputs; returns error text per input id.
  Map<String, String> validate(ToolValues v) {
    final errors = <String, String>{};
    for (final i in inputs.whereType<NumberInput>()) {
      if (!i.isVisible(v)) continue;
      final x = v.numbers[i.id];
      if (x == null || x.isNaN) {
        errors[i.id] = 'Required';
        continue;
      }
      if (i.min != null && (i.minInclusive ? x < i.min! : x <= i.min!)) {
        errors[i.id] = i.minInclusive ? 'Must be ≥ min' : 'Must be > min';
      } else if (i.max != null && x > i.max!) {
        errors[i.id] = 'Too large';
      }
    }
    for (final i in inputs.whereType<ListInput>()) {
      if (!i.isVisible(v)) continue;
      final xs = v.lists[i.id];
      if (xs == null || xs.any((x) => x.isNaN)) {
        errors[i.id] = 'Numbers only, separated by spaces or commas';
      } else if (xs.length < i.minCount) {
        errors[i.id] = 'Enter at least ${i.minCount} values';
      } else if (i.maxCount != null && xs.length > i.maxCount!) {
        errors[i.id] = 'At most ${i.maxCount} values';
      } else if (i.min != null && xs.any((x) => x < i.min!)) {
        errors[i.id] = 'A value is below the minimum';
      } else if (i.max != null && xs.any((x) => x > i.max!)) {
        errors[i.id] = 'A value is too large';
      }
    }
    return errors;
  }
}

/// Result of running one [ToolCase].
class CaseOutcome {
  CaseOutcome(this.tool, this.testCase, this.failures);
  final ToolDef tool;
  final ToolCase testCase;
  final List<String> failures;
  bool get passed => failures.isEmpty;
}

/// Runs every worked case of [tool]. Used by each app's test suite so a
/// failing case fails the build.
List<CaseOutcome> verifyTool(ToolDef tool) {
  final out = <CaseOutcome>[];
  for (final tc in tool.cases) {
    final f = <String>[];
    // Units.byId falls back to the first unit; a typo in a case must fail.
    void checkUnit(Quantity q, String id, String where) {
      if (!Units.of(q).any((u) => u.id == id)) {
        f.add('$where: unknown unit "$id" for ${q.name}');
      }
    }

    for (final i in tool.inputs) {
      switch (i) {
        case NumberInput():
          final given = tc.numbers[i.id];
          if (given != null) checkUnit(i.quantity, given.$2, i.id);
          if (i.units != null) {
            checkUnit(i.quantity, i.units!.$1, '${i.id} default');
            checkUnit(i.quantity, i.units!.$2, '${i.id} default');
          }
        case ListInput():
          final given = tc.lists[i.id];
          if (given != null) checkUnit(i.quantity, given.$2, i.id);
          if (i.units != null) {
            checkUnit(i.quantity, i.units!.$1, '${i.id} default');
            checkUnit(i.quantity, i.units!.$2, '${i.id} default');
          }
        case ChoiceInput():
          final given = tc.choices[i.id];
          if (given != null && !i.options.any((o) => o.value == given)) {
            f.add('${i.id}: unknown option "$given"');
          }
      }
    }
    final base = tool.initialValues();
    final numbers = Map<String, double>.of(base.numbers);
    final choices = Map<String, String>.of(base.choices);
    tc.choices.forEach((k, v) {
      final input = tool.inputs.whereType<ChoiceInput>().where(
        (i) => i.id == k,
      );
      if (input.isEmpty) f.add('unknown choice input $k');
      choices[k] = v;
    });
    tc.numbers.forEach((k, v) {
      final input = tool.inputs.whereType<NumberInput>().where(
        (i) => i.id == k,
      );
      if (input.isEmpty) {
        f.add('unknown number input $k');
        return;
      }
      numbers[k] = Units.byId(input.first.quantity, v.$2).toBase(v.$1);
    });
    final lists = Map<String, List<double>>.of(base.lists);
    tc.lists.forEach((k, v) {
      final input = tool.inputs.whereType<ListInput>().where((i) => i.id == k);
      if (input.isEmpty) {
        f.add('unknown list input $k');
        return;
      }
      final u = Units.byId(input.first.quantity, v.$2);
      lists[k] = [for (final x in v.$1) u.toBase(x)];
    });
    final values = ToolValues(numbers, choices, lists);
    try {
      final errors = tool.validate(values);
      if (errors.isNotEmpty) f.add('validation: $errors');
      final r = tool.compute(values);
      tc.expect.forEach((k, e) {
        final o = r[k];
        if (o == null) {
          f.add('missing output $k');
          return;
        }
        checkUnit(o.quantity, e.$2, 'expect $k');
        if (o.units != null) {
          checkUnit(o.quantity, o.units!.$1, '$k default');
          checkUnit(o.quantity, o.units!.$2, '$k default');
        }
        if (o.fixedUnit != null) {
          checkUnit(o.quantity, o.fixedUnit!, '$k fixed');
        }
        final got = Units.byId(o.quantity, e.$2).fromBase(o.value);
        final tol = tc.absTol > 0 ? tc.absTol : (e.$1.abs() * tc.relTol);
        if (!((got - e.$1).abs() <= tol)) {
          f.add('$k: expected ${e.$1} ${e.$2}, got $got');
        }
      });
      tc.expectText.forEach((k, e) {
        final o = r[k];
        if (o?.text == null || !o!.text!.contains(e)) {
          f.add('$k: expected text containing "$e", got "${o?.text}"');
        }
      });
      if (tc.expectWarning != null &&
          !r.warnings.any((w) => w.contains(tc.expectWarning!))) {
        f.add('expected warning "${tc.expectWarning}", got ${r.warnings}');
      }
    } on ToolInputError catch (e) {
      f.add('input error: $e');
    }
    out.add(CaseOutcome(tool, tc, f));
  }
  return out;
}
