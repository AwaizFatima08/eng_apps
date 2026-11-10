import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Quantities offered, in the order shown in the picker.
const List<(Quantity, String, String)> _quantities = [
  (Quantity.pressure, 'pressure', 'Pressure'),
  (Quantity.temperature, 'temperature', 'Temperature'),
  (Quantity.tempDiff, 'tempdiff', 'Temperature difference'),
  (Quantity.volumeFlow, 'volflow', 'Volume flow'),
  (Quantity.massFlow, 'massflow', 'Mass flow'),
  (Quantity.stdGasFlow, 'stdflow', 'Standard gas flow'),
  (Quantity.density, 'density', 'Density'),
  (Quantity.viscosity, 'viscosity', 'Viscosity (dynamic)'),
  (Quantity.length, 'length', 'Length'),
  (Quantity.area, 'area', 'Area'),
  (Quantity.volume, 'volume', 'Volume'),
  (Quantity.mass, 'mass', 'Mass'),
  (Quantity.velocity, 'velocity', 'Velocity'),
  (Quantity.power, 'power', 'Power / duty'),
  (Quantity.energy, 'energy', 'Energy'),
  (Quantity.specEnergy, 'enthalpy', 'Specific enthalpy'),
  (Quantity.specEntropy, 'entropy', 'Specific entropy / cp'),
  (Quantity.heatTransfer, 'htc', 'Heat transfer coeff. U'),
  (Quantity.force, 'force', 'Force'),
];

final unitConverterTool = ToolDef(
  id: 'unit_converter',
  title: 'Plant unit converter',
  summary:
      'Convert pressure, temperature, flow, density, viscosity, power, energy, '
      'enthalpy and other plant quantities between metric and US units.',
  icon: Icons.swap_horiz,
  keywords: [
    'unit',
    'convert',
    'conversion',
    'bar',
    'psi',
    'gpm',
    'btu',
    'kcal',
    'scfh',
    'nm3/h',
    'fahrenheit',
    'centipoise',
    'hp',
  ],
  inputs: [
    ChoiceInput(
      'q',
      'Quantity',
      options: [
        for (final (_, id, label) in _quantities) ChoiceOption(id, label),
      ],
    ),
    for (final (q, id, label) in _quantities)
      NumberInput(
        'v_$id',
        label,
        quantity: q,
        initial: q == Quantity.temperature ? 100 : Units.of(q).first.toBase(1),
        visibleWhen: (v) => v.c('q') == id,
      ),
  ],
  compute: (v) {
    final id = v.c('q');
    final (q, _, label) = _quantities.firstWhere((e) => e.$2 == id);
    final x = v.n('v_$id');
    final w = <String>[];
    if (q == Quantity.temperature && x < -273.15) {
      throw ToolInputError('Below absolute zero (−273.15 °C).');
    }
    if (q == Quantity.stdGasFlow) {
      w.add(
        'Nm³ is at 0 °C, 1.01325 bar; scf at 60 °F, 14.696 psia (ideal gas). '
        'Check which standard your plant uses (some use 15 °C or 20 °C).',
      );
    }
    return ToolResult(
      [
        ToolOutput(
          'c_$id',
          '$label in',
          x,
          quantity: q,
          sig: 7,
          level: OutputLevel.primary,
        ),
        for (final u in Units.of(q))
          ToolOutput(
            '${id}_${u.id}',
            u.symbol,
            x,
            quantity: q,
            fixedUnit: u.id,
            sig: 7,
          ),
      ],
      warnings: w,
      notes: [
        'Pick the output unit on the first result line; all units are listed below it.',
      ],
    );
  },
  formula: '''Every unit is stored as a factor (and offset) to SI:
  value_SI = value × factor + offset
  result   = (value_SI − offset_out) / factor_out

Selected exact factors:
  1 psi = 6 894.757 Pa       1 kgf/cm² = 98 066.5 Pa
  1 in = 25.4 mm             1 lb = 0.453 592 37 kg
  1 US gal = 3.785 411 784 L 1 BTU(IT) = 1 055.056 J
  1 kcal(IT) = 4 186.8 J     1 hp = 745.700 W
  1 TR = 3 516.853 W         °F = °C × 9/5 + 32
  1 scf (60 °F) = 0.026 839 4 Nm³ (0 °C)''',
  references: [
    'NIST Special Publication 811 (2008), Guide for the Use of the SI, Appendix B (conversion factors)',
    'BIPM, The International System of Units (SI Brochure), 9th ed. (2019)',
    'ISO 80000-1 / ISO 13443 (standard reference conditions for natural gas)',
  ],
  assumptions: [
    'Pressure units convert values only; gauge ⇄ absolute is not applied here.',
    'Water-column units use 1000 kg/m³ and g = 9.80665 m/s² (conventional), except inH₂O (68 °F) = 248.64 Pa.',
  ],
  cases: [
    const ToolCase(
      '1 bar → psi, kgf/cm², atm',
      source:
          'NIST SP 811 App. B: 1 psi = 6.894 757 kPa, 1 kgf/cm² = 98.0665 kPa, 1 atm = 101.325 kPa',
      numbers: {'v_pressure': (1, 'bar')},
      expect: {
        'c_pressure': (14.503774, 'psi'),
        'pressure_kgf/cm2': (1.0197162, 'kgf/cm2'),
        'pressure_atm': (0.98692327, 'atm'),
      },
      relTol: 1e-7,
    ),
    const ToolCase(
      '100 °C → °F and K',
      source: 'Definitions: °F = °C·9/5 + 32 → 212 °F; K = °C + 273.15',
      choices: {'q': 'temperature'},
      numbers: {'v_temperature': (100, 'C')},
      expect: {'temperature_F': (212, 'F'), 'temperature_K': (373.15, 'K')},
      relTol: 1e-12,
    ),
    const ToolCase(
      '100 m³/h → US gpm',
      source: 'NIST SP 811: 1 US gal = 3.785 412 L → 100 m³/h = 440.2868 gpm',
      choices: {'q': 'volflow'},
      numbers: {'v_volflow': (100, 'm3/h')},
      expect: {'c_volflow': (440.28675, 'gpm')},
      relTol: 1e-7,
    ),
    const ToolCase(
      '1 BTU/lb → kJ/kg',
      source:
          'IT calorie definition: 1 BTU/lb = 2.326 kJ/kg exactly (NIST SP 811)',
      choices: {'q': 'enthalpy'},
      numbers: {'v_enthalpy': (1, 'BTU/lb')},
      expect: {'c_enthalpy': (2.326, 'kJ/kg')},
      relTol: 1e-12,
    ),
    const ToolCase(
      '1 ton of refrigeration → kW and hp',
      source:
          'NIST SP 811: 1 TR = 3.516 853 kW; 1 hp (550 ft·lbf/s) = 0.745 699 9 kW',
      choices: {'q': 'power'},
      numbers: {'v_power': (1, 'TR')},
      expect: {'power_kW': (3.516853, 'kW'), 'power_hp': (4.716177, 'hp')},
      relTol: 1e-6,
    ),
    const ToolCase(
      '1 BTU/(h·ft²·°F) → W/(m²·K)',
      source: 'NIST SP 811: 1 BTU_IT/(h·ft²·°F) = 5.678 263 W/(m²·K)',
      choices: {'q': 'htc'},
      numbers: {'v_htc': (1, 'BTU/hft2F')},
      expect: {'c_htc': (5.678263, 'W/m2K')},
      relTol: 1e-6,
    ),
  ],
);
